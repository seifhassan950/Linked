from __future__ import annotations

from pathlib import Path
import mimetypes
import time

import httpx

from app.core.config import settings

from app.core.config import settings

MIN_MATCHES = 24
MAX_IMAGE_SIDE = 1400


def reconstruct_from_images(image_dir: Path, out_glb: Path) -> None:
    if settings.openscancloud_base_url and settings.openscancloud_token:
        _reconstruct_with_openscancloud(image_dir, out_glb)
        return

    _reconstruct_locally(image_dir, out_glb)


def _reconstruct_with_openscancloud(image_dir: Path, out_glb: Path) -> None:
    image_paths = sorted(
        p
        for p in image_dir.iterdir()
        if p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}
    )
    if len(image_paths) < 2:
        raise ValueError("Need at least two images for photogrammetry.")

    base_url = settings.openscancloud_base_url.rstrip("/")
    create_url = f"{base_url}{settings.openscancloud_create_path}"
    status_path = settings.openscancloud_status_path
    download_path = settings.openscancloud_download_path

    headers = {"Authorization": f"Bearer {settings.openscancloud_token}"}
    timeout = settings.openscancloud_timeout_seconds

    files = []
    for path in image_paths:
        content_type, _ = mimetypes.guess_type(path.name)
        files.append(("images", (path.name, path.open("rb"), content_type or "image/jpeg")))

    try:
        with httpx.Client(timeout=timeout) as client:
            response = client.post(create_url, headers=headers, files=files)
            response.raise_for_status()
            data = response.json()
            job_id = data.get("id") or data.get("job_id")
            if not job_id:
                raise ValueError("OpenScanCloud response missing job id.")

            status_url = f"{base_url}{status_path.format(job_id=job_id)}"
            download_url = None
            deadline = time.monotonic() + settings.openscancloud_max_poll_seconds
            while time.monotonic() < deadline:
                status_response = client.get(status_url, headers=headers)
                status_response.raise_for_status()
                status_payload = status_response.json()
                status = (status_payload.get("status") or status_payload.get("state") or "").lower()
                if status in {"succeeded", "success", "completed", "done"}:
                    download_url = (
                        status_payload.get("download_url")
                        or status_payload.get("result_url")
                        or f"{base_url}{download_path.format(job_id=job_id)}"
                    )
                    if download_url.startswith("/"):
                        download_url = f"{base_url}{download_url}"
                    break
                if status in {"failed", "error"}:
                    raise ValueError(status_payload.get("error") or "OpenScanCloud reconstruction failed.")
                time.sleep(settings.openscancloud_poll_interval_seconds)
            else:
                raise ValueError("OpenScanCloud reconstruction timed out.")

            download_response = client.get(download_url, headers=headers)
            download_response.raise_for_status()
            out_glb.write_bytes(download_response.content)
    finally:
        for _, (_, handle, _) in files:
            handle.close()


def _reconstruct_locally(image_dir: Path, out_glb: Path) -> None:
    import cv2
    import numpy as np
    import open3d as o3d

    image_paths = sorted(
        p
        for p in image_dir.iterdir()
        if p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}
    )
    if len(image_paths) < 2:
        raise ValueError("Need at least two images for photogrammetry.")

    images = []
    for path in image_paths:
        img = cv2.imread(str(path))
        if img is None:
            continue
        img = _resize_for_reconstruction(img)
        images.append((path.name, img))

    if len(images) < 2:
        raise ValueError("No readable images for reconstruction.")

    h, w = images[0][1].shape[:2]
    fx = fy = 1.2 * max(w, h)
    cx = w / 2
    cy = h / 2
    k = np.array([[fx, 0, cx], [0, fy, cy], [0, 0, 1]], dtype=np.float64)

    orb = cv2.ORB_create(nfeatures=6000)
    bf = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=False)

    points = []
    colors = []

    prev_name, prev_img = images[0]
    prev_kp, prev_des = orb.detectAndCompute(prev_img, None)
    if prev_des is None:
        raise ValueError(f"No features found in {prev_name}")

    r_prev = np.eye(3)
    t_prev = np.zeros((3, 1))

    for name, img in images[1:]:
        kp, des = orb.detectAndCompute(img, None)
        if des is None:
            continue

        matches = bf.knnMatch(prev_des, des, k=2)
        good = []
        for m, n in matches:
            if m.distance < 0.75 * n.distance:
                good.append(m)

        if len(good) < MIN_MATCHES:
            prev_name, prev_img = name, img
            prev_kp, prev_des = kp, des
            continue

        pts_prev = np.float32([prev_kp[m.queryIdx].pt for m in good])
        pts_curr = np.float32([kp[m.trainIdx].pt for m in good])

        e, mask = cv2.findEssentialMat(pts_prev, pts_curr, k, method=cv2.RANSAC, prob=0.999, threshold=1.0)
        if e is None:
            prev_name, prev_img = name, img
            prev_kp, prev_des = kp, des
            continue

        _, r_rel, t_rel, pose_mask = cv2.recoverPose(e, pts_prev, pts_curr, k)
        r_curr = r_rel @ r_prev
        t_curr = r_rel @ t_prev + t_rel

        p_prev = k @ np.hstack([r_prev, t_prev])
        p_curr = k @ np.hstack([r_curr, t_curr])

        pts_prev_inliers = pts_prev[pose_mask.ravel() == 1]
        pts_curr_inliers = pts_curr[pose_mask.ravel() == 1]

        if len(pts_prev_inliers) < MIN_MATCHES:
            prev_name, prev_img = name, img
            prev_kp, prev_des = kp, des
            r_prev, t_prev = r_curr, t_curr
            continue

        pts_4d = cv2.triangulatePoints(
            p_prev,
            p_curr,
            pts_prev_inliers.T,
            pts_curr_inliers.T,
        )
        pts_3d = (pts_4d[:3] / pts_4d[3]).T

        valid_mask = np.isfinite(pts_3d).all(axis=1)
        pts_3d = pts_3d[valid_mask]
        pts_prev_inliers = pts_prev_inliers[valid_mask]

        if pts_3d.size == 0:
            prev_name, prev_img = name, img
            prev_kp, prev_des = kp, des
            r_prev, t_prev = r_curr, t_curr
            continue

        cols = _sample_colors(prev_img, pts_prev_inliers)
        points.append(pts_3d)
        colors.append(cols)

        prev_name, prev_img = name, img
        prev_kp, prev_des = kp, des
        r_prev, t_prev = r_curr, t_curr

    if not points:
        raise ValueError("Not enough feature matches to reconstruct.")

    pts = np.vstack(points)
    cols = np.vstack(colors)

    pcd = o3d.geometry.PointCloud()
    pcd.points = o3d.utility.Vector3dVector(pts)
    pcd.colors = o3d.utility.Vector3dVector(cols)
    pcd = pcd.voxel_down_sample(voxel_size=0.0025)
    pcd.estimate_normals()
    pcd.orient_normals_consistent_tangent_plane(10)

    mesh, densities = o3d.geometry.TriangleMesh.create_from_point_cloud_poisson(
        pcd, depth=8
    )
    densities = np.asarray(densities)
    if densities.size:
        density_cut = np.quantile(densities, 0.12)
        mesh.remove_vertices_by_mask(densities < density_cut)
    mesh.remove_unreferenced_vertices()
    mesh.compute_vertex_normals()

    _export_mesh_glb(mesh, out_glb)


def _resize_for_reconstruction(image: np.ndarray) -> np.ndarray:
    import cv2

    h, w = image.shape[:2]
    scale = MAX_IMAGE_SIDE / max(h, w)
    if scale >= 1:
        return image
    new_w = int(w * scale)
    new_h = int(h * scale)
    return cv2.resize(image, (new_w, new_h), interpolation=cv2.INTER_AREA)


def _sample_colors(image: np.ndarray, points: np.ndarray) -> np.ndarray:
    import numpy as np

    h, w = image.shape[:2]
    xs = np.clip(points[:, 0].astype(int), 0, w - 1)
    ys = np.clip(points[:, 1].astype(int), 0, h - 1)
    bgr = image[ys, xs]
    rgb = bgr[:, ::-1] / 255.0
    return rgb.astype(np.float64)


def _export_mesh_glb(mesh: o3d.geometry.TriangleMesh, out_glb: Path) -> None:
    import numpy as np
    import trimesh

    vertices = np.asarray(mesh.vertices)
    triangles = np.asarray(mesh.triangles)
    if vertices.size == 0 or triangles.size == 0:
        raise ValueError("Reconstruction produced an empty mesh.")

    colors = None
    if mesh.has_vertex_colors():
        colors = np.asarray(mesh.vertex_colors)
    tri_mesh = trimesh.Trimesh(vertices=vertices, faces=triangles, vertex_colors=colors)
    glb_data = tri_mesh.export(file_type="glb")
    out_glb.write_bytes(glb_data)
