from __future__ import annotations
import datetime as dt
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import select
from app.api.deps import get_db
from app.api.schemas.auth import SignupIn, LoginIn, TokenOut, RefreshIn
from app.core.errors import conflict, unauthorized, bad_request
from app.core.security import (
    hash_password, verify_password, create_access_token, create_refresh_token,
    hash_refresh_token, refresh_expiry_utc
)
from app.db.models.user import User, UserProfile, RefreshToken

router = APIRouter()

@router.post("/signup", response_model=TokenOut)
def signup(payload: SignupIn, db: Session = Depends(get_db)):
    exists = db.execute(select(User).where(User.email == payload.email)).scalar_one_or_none()
    if exists:
        conflict("Email already registered")
    user = User(email=payload.email, password_hash=hash_password(payload.password), role="user", is_active=True)
    user.profile = UserProfile(username=payload.username, bio=None, avatar_url=None, links=None)
    db.add(user); db.flush()
    rt = create_refresh_token()
    db.add(RefreshToken(user_id=user.id, token_hash=hash_refresh_token(rt), expires_at=refresh_expiry_utc()))
    db.commit()
    return TokenOut(access_token=create_access_token(str(user.id), user.role), refresh_token=rt)

@router.post("/login", response_model=TokenOut)
def login(payload: LoginIn, db: Session = Depends(get_db)):
    user = db.execute(select(User).where(User.email == payload.email)).scalar_one_or_none()
    if not user or not verify_password(payload.password, user.password_hash):
        unauthorized("Invalid email or password")
    if not user.is_active:
        unauthorized("User inactive")
    rt = create_refresh_token()
    db.add(RefreshToken(user_id=user.id, token_hash=hash_refresh_token(rt), expires_at=refresh_expiry_utc()))
    db.commit()
    return TokenOut(access_token=create_access_token(str(user.id), user.role), refresh_token=rt)

@router.post("/refresh", response_model=TokenOut)
def refresh(payload: RefreshIn, db: Session = Depends(get_db)):
    token_hash = hash_refresh_token(payload.refresh_token)
    rt = db.execute(select(RefreshToken).where(RefreshToken.token_hash == token_hash)).scalar_one_or_none()
    if not rt or rt.revoked_at is not None:
        unauthorized("Invalid refresh token")
    if rt.expires_at <= dt.datetime.now(dt.timezone.utc):
        unauthorized("Refresh token expired")
    user = db.get(User, rt.user_id)
    if not user or not user.is_active:
        unauthorized("User inactive")
    # rotate token
    rt.revoked_at = dt.datetime.now(dt.timezone.utc)
    new_rt = create_refresh_token()
    db.add(RefreshToken(user_id=user.id, token_hash=hash_refresh_token(new_rt), expires_at=refresh_expiry_utc()))
    db.commit()
    return TokenOut(access_token=create_access_token(str(user.id), user.role), refresh_token=new_rt)

@router.post("/logout")
def logout(payload: RefreshIn, db: Session = Depends(get_db)):
    token_hash = hash_refresh_token(payload.refresh_token)
    rt = db.execute(select(RefreshToken).where(RefreshToken.token_hash == token_hash)).scalar_one_or_none()
    if not rt:
        bad_request("Unknown refresh token")
    rt.revoked_at = dt.datetime.now(dt.timezone.utc)
    db.commit()
    return {"detail": "ok"}
