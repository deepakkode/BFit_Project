from fastapi import APIRouter, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError

from app.api.deps import CurrentUser, DbSession
from app.core.security import create_access_token, hash_password, verify_password
from app.models.entities import User
from app.schemas.contracts import TokenRead, UserCreate, UserLogin, UserProfileUpdate, UserRead

router = APIRouter()


@router.post("/register", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def register(payload: UserCreate, db: DbSession) -> User:
    if db.scalar(select(User.id).where(func.lower(User.email) == payload.email)):
        raise HTTPException(status_code=409, detail="An account with this email already exists")
    user = User(
        name=payload.name.strip(), email=payload.email, password_hash=hash_password(payload.password),
        age=payload.age, height_cm=payload.height_cm, weight_kg=payload.weight_kg, gender=payload.gender,
    )
    db.add(user)
    try:
        db.commit()
        db.refresh(user)
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="An account with this email already exists") from exc
    return user


@router.post("/login", response_model=TokenRead)
def login(payload: UserLogin, db: DbSession) -> TokenRead:
    user = db.scalar(select(User).where(User.email == payload.email))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Incorrect email or password", headers={"WWW-Authenticate": "Bearer"})
    return TokenRead(access_token=create_access_token(user.id))


@router.get("/profile", response_model=UserRead)
def profile(user: CurrentUser) -> User:
    return user


@router.put("/profile", response_model=UserRead)
def update_profile(payload: UserProfileUpdate, db: DbSession, user: CurrentUser) -> User:
    user.age = payload.age
    user.height_cm = payload.height_cm
    user.weight_kg = payload.weight_kg
    db.commit()
    db.refresh(user)
    return user