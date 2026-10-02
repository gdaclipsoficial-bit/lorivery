from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.core.security import require_courier
from app.models.domain import Courier, User

router = APIRouter(prefix="/couriers", tags=["Couriers"])

@router.get("/me")
async def get_courier_profile(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(require_courier)
):
    """
    Devuelve el perfil del repartidor autenticado, 
    incluyendo sus datos personales y sus ganancias (balance).
    """
    courier_id = current_user["sub"]
    
    # Unimos la tabla de User y Courier
    query = select(Courier, User).join(User, Courier.user_id == User.id).where(Courier.user_id == courier_id)
    result = await db.execute(query)
    row = result.fetchone()
    
    if not row:
        raise HTTPException(status_code=404, detail="Perfil de repartidor no encontrado")
        
    courier, user = row
    
    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "phone_number": courier.phone_number,
        "national_id": courier.national_id,
        "vehicle_type": courier.vehicle_type,
        "balance": courier.balance,
        "is_available": courier.is_available,
        "is_approved": courier.is_approved,
        "rating": courier.rating
    }

from fastapi import File, UploadFile
import os
import shutil
import uuid

@router.post("/documents")
async def upload_courier_documents(
    id_front: UploadFile = File(...),
    id_back: UploadFile = File(...),
    selfie: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(require_courier)
):
    """
    Sube las 3 fotos necesarias para la verificación de identidad del repartidor.
    """
    from sqlalchemy import update
    
    courier_id = current_user["sub"]
    
    # Aseguramos el directorio de subidas
    os.makedirs("uploads/documents", exist_ok=True)
    
    urls = []
    for file in [id_front, id_back, selfie]:
        extension = file.filename.split(".")[-1]
        unique_name = f"{uuid.uuid4()}.{extension}"
        file_path = f"uploads/documents/{unique_name}"
        
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        urls.append(f"/{file_path}")
        
    # Actualizar la base de datos
    from app.models.domain import Courier
    query = (
        update(Courier)
        .where(Courier.user_id == courier_id)
        .values(
            id_front_url=urls[0],
            id_back_url=urls[1],
            selfie_url=urls[2],
            is_approved=False # Regresa a pendiente al actualizar docs
        )
    )
    await db.execute(query)
    await db.commit()
    
    return {"status": "success", "message": "Documentos subidos con éxito. En espera de aprobación."}

