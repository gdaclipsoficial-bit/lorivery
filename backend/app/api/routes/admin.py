from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text, update
from app.core.database import get_db
from app.models.domain import Order
from app.websockets.connection_manager import manager

router = APIRouter(prefix="/admin", tags=["Admin"])

@router.patch("/orders/{order_id}/approve")
async def approve_order_payment(order_id: str, db: AsyncSession = Depends(get_db)):
    """
    1. Aprueba el pago de Nequi/Efectivo y pasa la orden a APPROVED_BY_ADMIN.
    2. Notifica al cliente y envía el pedido al panel del restaurante.
    """
    query = (
        update(Order)
        .where(Order.id == order_id)
        .values(status='APPROVED_BY_ADMIN')
        .returning(Order)
    )
    result = await db.execute(query)
    updated_order = result.fetchone()
    
    if not updated_order:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
        
    order = updated_order[0]
    await db.commit()

    # Notificar al cliente vía WebSocket
    await manager.broadcast_to_room(
        room_id=order_id,
        message={
            "type": "STATUS_UPDATE",
            "status": "APPROVED_BY_ADMIN",
            "message": "¡Pago verificado por administración! Tu pedido fue enviado al restaurante."
        }
    )

    return {
        "status": "success", 
        "message": "Pago aprobado. Pedido enviado al restaurante para su preparación."
    }

@router.get("/couriers/pending")
async def get_pending_couriers(db: AsyncSession = Depends(get_db)):
    """
    Obtiene la lista de repartidores que han subido sus documentos pero aún no han sido aprobados.
    """
    from app.models.domain import Courier, User
    from sqlalchemy import select
    
    query = (
        select(Courier, User)
        .join(User, Courier.user_id == User.id)
        .where(Courier.is_approved == False)
    )
    result = await db.execute(query)
    
    pending = []
    for courier, user in result.all():
        pending.append({
            "courier_id": courier.user_id,
            "name": user.name,
            "email": user.email,
            "national_id": courier.national_id,
            "id_front_url": courier.id_front_url,
            "id_back_url": courier.id_back_url,
            "selfie_url": courier.selfie_url,
        })
        
    return {"pending_couriers": pending}

@router.api_route("/couriers/{courier_id}/approve", methods=["GET", "PATCH"])
async def approve_courier(courier_id: str, db: AsyncSession = Depends(get_db)):
    """
    Aprueba a un repartidor para que pueda conectarse y recibir pedidos.
    """
    from app.models.domain import Courier
    query = update(Courier).where(Courier.user_id == courier_id).values(is_approved=True)
    result = await db.execute(query)
    await db.commit()
    
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Repartidor no encontrado")
        
    return {"status": "success", "message": "Repartidor aprobado exitosamente"}