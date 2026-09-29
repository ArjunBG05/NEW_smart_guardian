from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from models import User, UserRole
from database import get_db
from pass_secure import hash_password, verify_password
from jwt_service import JWTservice


router = APIRouter()

jwt_service = JWTservice()


class RegisterRequest(BaseModel):
    email: str
    password: str
    user_role: Literal["patient", "guardian"]


class LoginRequest(BaseModel):
    email: str
    password: str


@router.post("/register", status_code=status.HTTP_201_CREATED)
def register(
    data: RegisterRequest,
    db: Session = Depends(get_db)
):

    email = data.email.strip().lower()

    existing_user = (
        db.query(User)
        .filter(User.email == email)
        .first()
    )

    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered"
        )

    
    hashed_password = hash_password(data.password)

    
    new_user = User(
        email=email,
        password_hash=hashed_password,
        user_role=UserRole(data.user_role),
        is_active=1
    )

    try:
        db.add(new_user)
        db.commit()
        db.refresh(new_user)

    except IntegrityError:
        db.rollback()

        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered"
        )

    return {
        "message": "Registration successful",
        "user_id": new_user.user_id,
        "email": new_user.email,
        "user_role": new_user.user_role.value
    }


@router.post("/login")
def login(
    data: LoginRequest,
    db: Session = Depends(get_db)
):

    email = data.email.strip().lower()

    
    user = (
        db.query(User)
        .filter(User.email == email)
        .first()
    )

    
    if not user:

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )

    
    if not user.is_active:

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Account is inactive"
        )
    password_correct = verify_password(
        data.password,
        user.password_hash
    )

    if not password_correct:

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )

    
    access_token = jwt_service.encode(
        str(user.user_id)
    )

    return {
        "message": "Login successful",
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": user.user_id,
        "user_role": user.user_role.value
    }