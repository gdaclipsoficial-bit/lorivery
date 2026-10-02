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
    1. Aprueba el pago de Nequi y pasa la orden a READY.
    2. Obtiene los datos del restaurante y destino.
    3. Envía SIEMPRE el WebSocket Broadcast a los repartidores para que les llegue a su app inmediatamente.
    """
    # 1. Aprobar la Orden
    query = (
        update(Order)
        .where(Order.id == order_id)
        .values(status='READY')
        .returning(Order)
    )
    result = await db.execute(query)
    updated_order = result.fetchone()
    
    if not updated_order:
        raise HTTPException(status_code=404, detail="Orden no encontrada o no está en estado CREATED")
        
    order = updated_order[0]
    await db.commit()

    # 2. Obtener el nombre del restaurante real
    restaurant_name = "Restaurante Local"
    if order.restaurant_id:
        res_r = await db.execute(text("SELECT name FROM restaurants WHERE id = :rid"), {"rid": order.restaurant_id})
        r_row = res_r.fetchone()
        if r_row:
            restaurant_name = r_row[0]

    # 3. Lanzar SIEMPRE el Broadcast a la sala general "demo_order" (Radar de todos los repartidores)
    fee = order.delivery_fee or 3000

    await manager.broadcast_to_room(
        room_id="demo_order",
        message={
            "type": "NEW_ORDER",
            "order_id": order.id,
            "restaurant": restaurant_name,
            "destination": order.delivery_address or "Cliente Lorica",
            "earnings": f"${fee:,.0f} COP",
            "distance": "Calculada por GPS"
        }
    )

    return {
        "status": "success", 
        "message": "Pago aprobado y orden transmitida a todos los repartidores en tiempo real"
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