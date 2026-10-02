from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from app.websockets.connection_manager import manager

async def accept_order_atomic(db: AsyncSession, order_id: str, courier_id: str):
    """
    Asigna la orden de forma atómica usando bloqueo a nivel de fila de PostgreSQL.
    """
    query = text("""
        UPDATE orders
        SET courier_id = :courier_id, status = 'ASSIGNED'
        WHERE id = :order_id 
          AND status = 'READY' 
          AND courier_id IS NULL
        RETURNING id, client_id;
    """)
    
    result = await db.execute(query, {"order_id": order_id, "courier_id": courier_id})
    updated_order = result.fetchone()
    
    if not updated_order:
        raise ValueError("Lo sentimos, esta orden ya fue tomada por otro repartidor.")
        
    await db.commit()

    # Notificar a través del WebSocket que la orden ha sido asignada
    await manager.broadcast_to_room(
        room_id=order_id,
        message={
            "type": "STATUS_UPDATE",
            "status": "ASSIGNED",
            "courier_id": courier_id
        }
    )
    
    return {"status": "success", "message": "Orden asignada correctamente"}

