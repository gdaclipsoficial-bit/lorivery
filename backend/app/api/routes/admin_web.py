from fastapi import APIRouter, Request, Depends
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.models.domain import Order, Courier, User

router = APIRouter(prefix="/admin-web", tags=["Admin Web"])

# Uvicorn corre desde la carpeta backend/, así que "templates" resuelve a backend/templates/
templates = Jinja2Templates(directory="templates")

@router.get("/dashboard")
async def admin_dashboard(request: Request, db: AsyncSession = Depends(get_db)):
    # Traer todas las órdenes pendientes (CREATED)
    query = select(Order).where(Order.status == 'CREATED')
    result = await db.execute(query)
    orders = result.scalars().all()
    
    # Traer repartidores pendientes de aprobación
    courier_query = (
        select(Courier, User)
        .join(User, Courier.user_id == User.id)
        .where(Courier.is_approved == False)
    )
    courier_result = await db.execute(courier_query)
    pending_couriers = []
    for courier, user in courier_result.all():
        pending_couriers.append({
            "courier_id": courier.user_id,
            "name": user.name,
            "email": user.email,
            "national_id": courier.national_id,
            "phone_number": courier.phone_number,
            "vehicle_type": courier.vehicle_type,
            "id_front_url": courier.id_front_url,
            "id_back_url": courier.id_back_url,
            "selfie_url": courier.selfie_url,
        })
    
    return templates.TemplateResponse(
        request=request,
        name="dashboard.html",
        context={"orders": orders, "pending_couriers": pending_couriers}
    )

