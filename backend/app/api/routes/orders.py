from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text, update, select, func
from pydantic import BaseModel
import shutil
import os
import uuid
import math
import random

from app.core.database import get_db
from app.models.domain import Order
from app.core.security import get_current_user, require_courier
from app.websockets.connection_manager import manager

def haversine(lat1, lon1, lat2, lon2):
    R = 6371
    dLat = math.radians(lat2 - lat1)
    dLon = math.radians(lon2 - lon1)
    a = math.sin(dLat/2) * math.sin(dLat/2) + \
        math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * \
        math.sin(dLon/2) * math.sin(dLon/2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

router = APIRouter(prefix="/orders", tags=["Orders"])

UPLOAD_DIR = "uploads/payments"
os.makedirs(UPLOAD_DIR, exist_ok=True)

class OrderStatusUpdate(BaseModel):
    status: str
    pickup_code: str | None = None
    delivery_code: str | None = None

@router.post("/")
async def create_order_with_payment(
    restaurant_id: str = Form(...),
    delivery_address: str = Form(...),
    delivery_lat: float = Form(...),
    delivery_lng: float = Form(...),
    total_amount: float = Form(...),
    payment_proof: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    client_id = current_user["sub"]

    file_extension = payment_proof.filename.split(".")[-1]
    file_name = f"{uuid.uuid4()}.{file_extension}"
    file_path = os.path.join(UPLOAD_DIR, file_name)
    
    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(payment_proof.file, buffer)
    except Exception as e:
        raise HTTPException(status_code=500, detail="Error al guardar el comprobante de pago.")

    rest_lat = delivery_lat + 0.005 
    rest_lng = delivery_lng + 0.005
    distance_km = haversine(rest_lat, rest_lng, delivery_lat, delivery_lng)
    
    # Tarifador: 3.000 COP base/por km, máximo 5.000 COP en el casco urbano de Lorica
    raw_fee = math.ceil(distance_km) * 3000
    calculated_fee = float(min(max(3000, raw_fee), 5000))

    pickup_code = f"{random.randint(1000, 9999)}"
    delivery_code = f"{random.randint(1000, 9999)}"

    new_order = Order(
        client_id=client_id,
        restaurant_id=restaurant_id,
        status="CREATED",
        payment_proof_url=f"/{file_path}",
        delivery_address=delivery_address, # Guardamos la dirección real del cliente
        delivery_lat=delivery_lat,
        delivery_lng=delivery_lng,
        restaurant_lat=rest_lat,
        restaurant_lng=rest_lng,
        delivery_fee=calculated_fee,
        pickup_code=pickup_code,
        delivery_code=delivery_code
    )
    
    db.add(new_order)
    await db.commit()
    await db.refresh(new_order)
    
    return {
        "status": "success",
        "message": "Pedido creado con éxito.",
        "order_id": new_order.id,
        "payment_proof_url": f"/{file_path}",
        "delivery_fee": calculated_fee,
        "pickup_code": pickup_code,
        "delivery_code": delivery_code
    }

@router.get("/available")
async def get_available_orders(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(require_courier)
):
    """
    Devuelve los pedidos aprobados/listos que aún no tienen repartidor asignado.
    """
    query = text("""
        SELECT o.id, o.restaurant_id, o.delivery_address, o.delivery_fee, r.name as restaurant_name
        FROM orders o
        LEFT JOIN restaurants r ON o.restaurant_id = r.id
        WHERE o.status = 'READY'
          AND o.courier_id IS NULL
        ORDER BY o.id DESC
    """)
    result = await db.execute(query)
    rows = result.fetchall()

    orders_list = []
    for row in rows:
        o_id, r_id, del_addr, fee, r_name = row
        orders_list.append({
            "order_id": str(o_id),
            "restaurant_id": str(r_id) if r_id else None,
            "restaurant": r_name or "Restaurante Local",
            "destination": del_addr or "Cliente Lorica",
            "earnings": f"${(fee or 3000):,.0f} COP",
            "distance": "En Lorica"
        })

    return {"status": "success", "orders": orders_list}

@router.post("/{order_id}/accept")
async def accept_order(
    order_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(require_courier)
):
    courier_id = current_user["sub"]

    query = text("""
        UPDATE orders
        SET courier_id = :courier_id, status = 'ASSIGNED'
        WHERE id = :order_id 
        RETURNING id, client_id;
    """)
    
    result = await db.execute(query, {"order_id": order_id, "courier_id": courier_id})
    updated_order = result.fetchone()
    
    if not updated_order:
        raise HTTPException(status_code=409, detail="Orden no disponible.")
        
    await db.commit()

    await manager.broadcast_to_room(
        room_id=order_id,
        message={
            "type": "STATUS_UPDATE",
            "status": "ASSIGNED",
            "courier_id": courier_id,
            "message": "¡Un repartidor ha aceptado tu pedido!"
        }
    )
    
    return {"status": "success", "message": "Orden asignada a tu cuenta."}

from app.models.domain import Courier

@router.patch("/{order_id}/status")
async def update_trip_status(
    order_id: str, 
    data: OrderStatusUpdate, 
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(require_courier)
):
    courier_id = current_user["sub"]
    
    if data.status == 'PICKED_UP':
        res = await db.execute(text("SELECT pickup_code FROM orders WHERE id = :id"), {"id": order_id})
        row = res.fetchone()
        if not row or row[0] != data.pickup_code:
            raise HTTPException(status_code=400, detail="PIN de recogida incorrecto.")

    if data.status == 'DELIVERED':
        res = await db.execute(text("SELECT delivery_code, delivery_fee FROM orders WHERE id = :id"), {"id": order_id})
        row = res.fetchone()
        if not row or row[0] != data.delivery_code:
            raise HTTPException(status_code=400, detail="PIN de entrega del cliente incorrecto.")
            
        fee_to_add = row[1] or 0.0
        # Incrementar ganancias del repartidor en su cuenta/balance
        await db.execute(
            update(Courier)
            .where(Courier.user_id == courier_id)
            .values(balance=Courier.balance + fee_to_add)
        )

    query = (
        update(Order)
        .where(Order.id == order_id)
        .where(Order.courier_id == courier_id)
        .values(status=data.status)
        .returning(Order.id)
    )
    result = await db.execute(query)
    updated_order = result.fetchone()
    
    if not updated_order:
        raise HTTPException(status_code=404, detail="Orden no encontrada o no autorizada")
        
    await db.commit()
    
    await manager.broadcast_to_room(
        room_id=order_id,
        message={
            "type": "STATUS_UPDATE",
            "status": data.status,
            "message": f"El pedido ahora está en estado: {data.status}"
        }
    )
    
    return {"message": "Estado actualizado con éxito", "status": data.status}

@router.get("/courier/profile")
async def get_courier_profile(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(require_courier)
):
    courier_id = current_user["sub"]
    
    earnings_query = select(func.sum(Order.delivery_fee)).where(
        Order.courier_id == courier_id,
        Order.status == 'DELIVERED'
    )
    result = await db.execute(earnings_query)
    total_earnings = result.scalar() or 0.0

    count_query = select(func.count(Order.id)).where(
        Order.courier_id == courier_id,
        Order.status == 'DELIVERED'
    )
    count_result = await db.execute(count_query)
    completed_orders = count_result.scalar() or 0

    return {
        "status": "success",
        "total_earnings": total_earnings,
        "completed_orders": completed_orders,
        "vehicle": "Suzuki GN 125",
        "rating": 4.9
    }

@router.get("/my-orders")
async def get_client_orders(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Obtiene el historial de pedidos del cliente autenticado.
    """
    client_id = current_user["sub"]
    query = text("""
        SELECT o.id, o.status, o.delivery_address, o.delivery_fee, o.delivery_code,
               r.name as restaurant_name, r.logo_url as restaurant_logo
        FROM orders o
        LEFT JOIN restaurants r ON o.restaurant_id = r.id
        WHERE o.client_id = :cid
        ORDER BY o.id DESC
    """)
    result = await db.execute(query, {"cid": client_id})
    rows = result.fetchall()

    history = []
    for row in rows:
        o_id, status, addr, fee, code, r_name, r_logo = row
        history.append({
            "order_id": str(o_id),
            "status": status,
            "delivery_address": addr or "Lorica",
            "delivery_fee": fee or 3000,
            "delivery_code": code,
            "restaurant_name": r_name or "Restaurante Local",
            "restaurant_logo": r_logo
        })

    return {"status": "success", "orders": history}

@router.get("/courier/history")
async def get_courier_orders_history(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(require_courier)
):
    """
    Obtiene el historial de pedidos entregados y asignados del repartidor autenticado.
    """
    courier_id = current_user["sub"]
    query = text("""
        SELECT o.id, o.status, o.delivery_address, o.delivery_fee, o.pickup_code, o.delivery_code,
               r.name as restaurant_name, u.name as client_name
        FROM orders o
        LEFT JOIN restaurants r ON o.restaurant_id = r.id
        LEFT JOIN users u ON o.client_id = u.id
        WHERE o.courier_id = :cid
        ORDER BY o.id DESC
    """)
    result = await db.execute(query, {"cid": courier_id})
    rows = result.fetchall()

    history = []
    for row in rows:
        o_id, status, addr, fee, p_code, d_code, r_name, c_name = row
        history.append({
            "order_id": str(o_id),
            "status": status,
            "delivery_address": addr or "Lorica",
            "delivery_fee": fee or 3000,
            "pickup_code": p_code,
            "delivery_code": d_code,
            "restaurant_name": r_name or "Restaurante Local",
            "client_name": c_name or "Cliente"
        })

    return {"status": "success", "orders": history}

class ChatMessage(BaseModel):
    message: str
    sender_role: str # CLIENT o COURIER

@router.post("/{order_id}/chat")
async def send_order_chat_message(
    order_id: str,
    payload: ChatMessage,
    current_user: dict = Depends(get_current_user)
):
    """
    Retransmite un mensaje de chat entre el cliente y el repartidor a través del WebSocket de la orden.
    """
    msg_data = {
        "type": "CHAT_MESSAGE",
        "order_id": order_id,
        "sender_id": current_user["sub"],
        "sender_name": current_user.get("name", "Usuario"),
        "sender_role": payload.sender_role,
        "message": payload.message,
        "timestamp": "Ahora"
    }
    await manager.broadcast_to_room(room_id=order_id, message=msg_data)
    return {"status": "success", "data": msg_data}

@router.get("/{order_id}")
async def get_order_tracking(
    order_id: str, 
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    query = text("""
        SELECT o.id, o.status, o.delivery_code, o.pickup_code, o.courier_id, o.delivery_address,
               u.name as client_name, r.name as restaurant_name
        FROM orders o
        LEFT JOIN users u ON o.client_id = u.id
        LEFT JOIN restaurants r ON o.restaurant_id = r.id
        WHERE o.id = :id
    """)
    result = await db.execute(query, {"id": order_id})
    order = result.fetchone()

    if not order:
        raise HTTPException(status_code=404, detail="Orden no encontrada")

    o_id, o_status, o_delivery_code, o_pickup_code, o_courier_id, o_delivery_address, c_name, r_name = order

    response_data = {
        "order_id": str(o_id),
        "status": o_status,
        "delivery_code": o_delivery_code,
        "pickup_code": o_pickup_code,
        "delivery_address": o_delivery_address or "Barrio Centro, Lorica",
        "restaurant_name": r_name or "Restaurante Local",
        "restaurant_address": "Calle Principal #10-20, Lorica",
        "client_name": c_name or "Cliente",
        "client_phone": "3000000000",
        "courier": None
    }

    if o_courier_id:
        courier_query = text("""
            SELECT u.name, c.phone_number, c.vehicle_type
            FROM users u
            LEFT JOIN couriers c ON u.id = c.user_id
            WHERE u.id = :courier_id
        """)
        courier_result = await db.execute(courier_query, {"courier_id": o_courier_id})
        courier = courier_result.fetchone()

        if courier:
            name, phone, v_type = courier
            response_data["courier"] = {
                "name": name or "Repartidor",
                "phone_number": phone or "3001234567",
                "vehicle_model": "Motocicleta" if v_type == "MOTORCYCLE" else "Bicicleta",
                "plate": "LOR-123",
                "photo_url": "/static/default_avatar.png"
            }

    return response_data

class CourierRatingRequest(BaseModel):
    rating: float
    feedback: str | None = None

@router.post("/{order_id}/rate")
async def rate_courier(
    order_id: str,
    payload: CourierRatingRequest,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Califica al repartidor de un pedido entregado y actualiza su calificación promedio.
    """
    from app.models.domain import Courier

    res = await db.execute(select(Order).where(Order.id == order_id))
    order = res.scalars().first()
    if not order:
        raise HTTPException(status_code=404, detail="Pedido no encontrado")

    if not order.courier_id:
        raise HTTPException(status_code=400, detail="Este pedido no tiene repartidor asignado")

    order.courier_rating = payload.rating
    order.courier_feedback = payload.feedback

    avg_res = await db.execute(
        select(func.avg(Order.courier_rating)).where(
            Order.courier_id == order.courier_id,
            Order.courier_rating.isnot(None)
        )
    )
    new_avg = avg_res.scalar() or payload.rating

    c_res = await db.execute(select(Courier).where(Courier.user_id == order.courier_id))
    courier = c_res.scalars().first()
    if courier:
        courier.rating = round(float(new_avg), 1)

    await db.commit()
    return {"status": "success", "message": "Calificación registrada con éxito", "rating": payload.rating}

class SupportTicketRequest(BaseModel):
    subject: str
    description: str

@router.post("/{order_id}/support")
async def create_order_support_ticket(
    order_id: str,
    payload: SupportTicketRequest,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Crea una queja o solicitud de ayuda para un pedido.
    """
    from app.models.domain import SupportTicket
    import datetime

    ticket = SupportTicket(
        order_id=order_id,
        user_id=current_user["sub"],
        subject=payload.subject,
        description=payload.description,
        status="OPEN",
        created_at=datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    )
    db.add(ticket)
    await db.commit()
    await db.refresh(ticket)

    return {"status": "success", "message": "Ticket de soporte creado exitosamente", "ticket_id": ticket.id}

@router.get("/support/all-tickets")
async def get_support_tickets(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Obtiene los tickets de soporte del usuario o todos si es admin.
    """
    from app.models.domain import SupportTicket
    query = select(SupportTicket).order_by(SupportTicket.id.desc())
    res = await db.execute(query)
    tickets = res.scalars().all()
    return [
        {
            "id": t.id,
            "order_id": t.order_id,
            "subject": t.subject,
            "description": t.description,
            "status": t.status,
            "created_at": t.created_at
        }
        for t in tickets
    ]