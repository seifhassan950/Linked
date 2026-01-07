from __future__ import annotations
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.api.deps import get_db, get_current_user
from app.api.schemas.jobs import DownloadOut
from app.core.errors import not_found, forbidden
from app.db.models.marketplace import Asset, Download
from app.services.entitlements import is_entitled_to_asset
from app.services.s3 import s3
from app.core.config import settings

router = APIRouter()

@router.get("/assets/{asset_id}/download", response_model=DownloadOut)
def download_asset(asset_id: str, db: Session = Depends(get_db), user = Depends(get_current_user)):
    a = db.get(Asset, asset_id)
    if not a: not_found()
    entitled, _ = is_entitled_to_asset(db, user.id, a)
    if not entitled:
        forbidden("Not entitled to download")
    url = s3.presign_get(settings.s3_bucket_marketplace_models, a.model_object_key, expires=900)
    db.add(Download(user_id=user.id, asset_id=a.id))
    db.commit()
    return DownloadOut(url=url, expires_in=900)
