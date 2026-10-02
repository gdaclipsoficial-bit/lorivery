from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel, EmailStr
from app.core.database import get_db
from app.core.security import verify_password, get_password_hash, create_access_token
from app.models.domain import User, Courier
import uuid

router = APIRouter(prefix="/auth", tags=["Authentication"])

from typing import Optional

class RegisterRequest(BaseModel):
    name: str
    email: str
    password: str
    role: str = "CLIENT"  # CLIENT o COURIER
    # Campos adicionales para Repartidores
    phone_number: Optional[str] = None
    national_id: Optional[str] = None
    vehicle_type: Optional[str] = None
    is_adult: Optional[bool] = None

@router.post("/register", status_code=201)
async def register(data: RegisterRequest, db: AsyncSession = Depends(get_db)):
    """Registra un nuevo usuario (cliente o repartidor)."""
    # Verificar si el email ya existe
    result = await db.execute(select(User).where(User.email == data.email))
    existing = result.scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=400, detail="Este correo ya está registrado.")

    if data.role not in ("CLIENT", "COURIER", "ADMIN"):
        raise HTTPException(status_code=400, detail="Rol inválido.")

    if data.role == "COURIER":
        if not data.is_adult:
            raise HTTPException(status_code=400, detail="Debes ser mayor de edad para ser repartidor.")
        if not data.national_id or not data.phone_number:
            raise HTTPException(status_code=400, detail="La Cédula y el Teléfono son requeridos.")

    new_user = User(
        id=str(uuid.uuid4()),
        name=data.name,
        email=data.email,
        password_hash=get_password_hash(data.password),
        role=data.role,
    )
    db.add(new_user)
    await db.flush()  # Envía el INSERT del usuario a la BD sin hacer commit aún

    # Si se registra como repartidor, crear entrada en la tabla couriers con los nuevos datos
    if data.role == "COURIER":
        new_courier = Courier(
            user_id=new_user.id, 
            is_available=False,
            vehicle_type=data.vehicle_type or "MOTORCYCLE",
            phone_number=data.phone_number,
            national_id=data.national_id
        )
        db.add(new_courier)

    await db.commit()
    await db.refresh(new_user)

    token = create_access_token({"sub": new_user.id, "role": new_user.role, "name": new_user.name})
    return {
        "access_token": token,
        "token_type": "bearer",
        "role": new_user.role,
        "name": new_user.name,
        "user_id": new_user.id,
    }

@router.post("/login")
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db),
):
    """Verifica credenciales y devuelve el JWT."""
    result = await db.execute(select(User).where(User.email == form_data.username))
    user = result.scalar_one_or_none()

    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Correo o contraseña incorrectos",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = create_access_token({"sub": user.id, "role": user.role, "name": user.name})
    return {
        "access_token": token,
        "token_type": "bearer",
        "role": user.role,
        "name": user.name,
        "user_id": user.id,
    }

