from __future__ import annotations
import boto3
from botocore.client import Config
from app.core.config import settings

class S3Client:
    def __init__(self) -> None:
        self.client = boto3.client(
            "s3",
            endpoint_url=settings.s3_endpoint_url,
            aws_access_key_id=settings.s3_access_key,
            aws_secret_access_key=settings.s3_secret_key,
            region_name=settings.s3_region,
            config=Config(signature_version="s3v4"),
        )

    def presign_put(
        self,
        bucket: str,
        key: str,
        expires: int = 3600,
        content_type: str | None = None,
    ) -> str:
        params = {"Bucket": bucket, "Key": key}
        if content_type:
            params["ContentType"] = content_type
        return self.client.generate_presigned_url("put_object", Params=params, ExpiresIn=expires)

    def presign_get(self, bucket: str, key: str, expires: int = 3600) -> str:
        return self.client.generate_presigned_url("get_object", Params={"Bucket": bucket, "Key": key}, ExpiresIn=expires)

    def upload_file(self, local_path: str, bucket: str, key: str, content_type: str | None = None) -> None:
        extra = {"ContentType": content_type} if content_type else {}
        self.client.upload_file(local_path, bucket, key, ExtraArgs=extra)

s3 = S3Client()
