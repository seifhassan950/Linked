from __future__ import annotations
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import select, desc, or_
from app.api.deps import get_db, get_current_user
from app.api.schemas.marketplace import AssetOut, AssetCreateIn, AssetUpdateIn, EntitlementOut
from app.core.errors import not_found, forbidden, bad_request
from app.db.models.marketplace import Asset, RecentlyViewed
from app.services.entitlements import is_entitled_to_asset
import datetime as dt

router = APIRouter()

def to_out(a: Asset) -> AssetOut:
    return AssetOut(
        id=str(a.id), title=a.title, description=a.description, tags=a.tags or [], category=a.category, style=a.style,
        creator_id=str(a.creator_id), is_paid=a.is_paid, price=a.price, currency=a.currency,
        visibility=a.visibility, published_at=a.published_at.isoformat() if a.published_at else None,
        thumb_object_key=a.thumb_object_key, model_object_key=a.model_object_key, metadata=a.meta_json or {}
    )

@router.get("/assets", response_model=list[AssetOut])
def list_assets(q: str | None = None, category: str | None = None, style: str | None = None,
               limit: int = 20, offset: int = 0, db: Session = Depends(get_db)):
    stmt = select(Asset).where(Asset.visibility == "published")
    if q:
        like = f"%{q}%"
        stmt = stmt.where(or_(Asset.title.ilike(like), Asset.description.ilike(like)))
    if category:
        stmt = stmt.where(Asset.category == category)
    if style:
        stmt = stmt.where(Asset.style == style)
    stmt = stmt.order_by(desc(Asset.published_at)).limit(limit).offset(offset)
    items = db.execute(stmt).scalars().all()
    return [to_out(a) for a in items]

@router.post("/assets", response_model=AssetOut)
def create_asset(payload: AssetCreateIn, db: Session = Depends(get_db), user = Depends(get_current_user)):
    a = Asset(
        creator_id=user.id,
        title=payload.title,
        description=payload.description,
        tags=payload.tags,
        category=payload.category,
        style=payload.style,
        is_paid=payload.is_paid,
        price=payload.price,
        currency=payload.currency,
        license=payload.license,
        visibility="draft",
        model_object_key=payload.model_object_key,
        thumb_object_key=payload.thumb_object_key,
        preview_object_keys=payload.preview_object_keys,
        meta_json=payload.metadata,
    )
    db.add(a); db.commit(); db.refresh(a)
    return to_out(a)

@router.get("/assets/{asset_id}", response_model=AssetOut)
def get_asset(asset_id: str, db: Session = Depends(get_db), user = Depends(get_current_user)):
    a = db.get(Asset, asset_id)
    if not a: not_found()
    # viewing allowed if published or owner
    if a.visibility != "published" and a.creator_id != user.id:
        forbidden()
    # track recently viewed
    rv = db.execute(select(RecentlyViewed).where(RecentlyViewed.user_id == user.id, RecentlyViewed.asset_id == a.id)).scalar_one_or_none()
    if rv:
        rv.last_viewed_at = dt.datetime.now(dt.timezone.utc)
    else:
        db.add(RecentlyViewed(user_id=user.id, asset_id=a.id))
    db.commit()
    return to_out(a)

@router.patch("/assets/{asset_id}", response_model=AssetOut)
def update_asset(asset_id: str, payload: AssetUpdateIn, db: Session = Depends(get_db), user = Depends(get_current_user)):
    a = db.get(Asset, asset_id)
    if not a: not_found()
    if a.creator_id != user.id: forbidden()
    for field, value in payload.model_dump(exclude_unset=True).items():
        # "metadata" is the API field name; the ORM attribute is "meta_json".
        if field == "metadata":
            setattr(a, "meta_json", value)
        else:
            setattr(a, field, value)
    db.commit(); db.refresh(a)
    return to_out(a)

@router.post("/assets/{asset_id}/publish", response_model=AssetOut)
def publish(asset_id: str, db: Session = Depends(get_db), user = Depends(get_current_user)):
    a = db.get(Asset, asset_id)
    if not a: not_found()
    if a.creator_id != user.id: forbidden()
    if not a.model_object_key:
        bad_request("model_object_key is required")
    a.visibility = "published"
    a.published_at = dt.datetime.now(dt.timezone.utc)
    db.commit(); db.refresh(a)
    return to_out(a)

@router.get("/assets/{asset_id}/entitlement", response_model=EntitlementOut)
def entitlement(asset_id: str, db: Session = Depends(get_db), user = Depends(get_current_user)):
    a = db.get(Asset, asset_id)
    if not a: not_found()
    entitled, reason = is_entitled_to_asset(db, user.id, a)
    return EntitlementOut(asset_id=str(a.id), entitled=entitled, reason=reason)
