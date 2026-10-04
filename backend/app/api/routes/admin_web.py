from fastapi import APIRouter, Request, Depends
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.core.database import get_db
from app.models.domain import Order, Courier, User, Restaurant, Product, SupportTicket

router = APIRouter(prefix="/admin-web", tags=["Admin Web"])
templates = Jinja2Templates(directory="templates")

@router.get("/api/stats")
async def get_admin_stats(db: AsyncSession = Depends(get_db)):
    """Retorna métricas y contadores de usuarios y repartidores en tiempo real."""
    # 1. Total usuarios
    u_res = await db.execute(select(func.count(User.id)))
    total_users = u_res.scalar() or 0

    # 2. Total clientes
    c_res = await db.execute(select(func.count(User.id)).where(User.role == 'CLIENT'))
    total_clients = c_res.scalar() or 0

    # 3. Total repartidores
    cour_res = await db.execute(select(func.count(Courier.user_id)))
    total_couriers = cour_res.scalar() or 0

    # 4. Repartidores aprobados y disponibles
    cour_app_res = await db.execute(select(func.count(Courier.user_id)).where(Courier.is_approved == True))
    approved_couriers = cour_app_res.scalar() or 0

    cour_pend_res = await db.execute(select(func.count(Courier.user_id)).where(Courier.is_approved == False))
    pending_couriers_count = cour_pend_res.scalar() or 0

    cour_avail_res = await db.execute(select(func.count(Courier.user_id)).where(Courier.is_available == True))
    active_couriers = cour_avail_res.scalar() or 0

    # 5. Restaurantes
    r_app_res = await db.execute(select(func.count(Restaurant.id)).where(Restaurant.is_approved == True, Restaurant.is_active == True))
    approved_restaurants = r_app_res.scalar() or 0

    r_pend_res = await db.execute(select(func.count(Restaurant.id)).where(Restaurant.is_approved == False))
    pending_restaurants_count = r_pend_res.scalar() or 0

    # 6. Órdenes
    o_pend_res = await db.execute(select(func.count(Order.id)).where(Order.status == 'CREATED'))
    pending_orders_count = o_pend_res.scalar() or 0

    o_act_res = await db.execute(select(func.count(Order.id)).where(Order.status.in_(['APPROVED_BY_ADMIN', 'READY', 'ASSIGNED', 'PICKED_UP'])))
    active_orders_count = o_act_res.scalar() or 0

    return {
        "status": "success",
        "total_users": total_users,
        "total_clients": total_clients,
        "total_couriers": total_couriers,
        "approved_couriers": approved_couriers,
        "pending_couriers_count": pending_couriers_count,
        "active_couriers": active_couriers,
        "approved_restaurants": approved_restaurants,
        "pending_restaurants_count": pending_restaurants_count,
        "pending_orders_count": pending_orders_count,
        "active_orders_count": active_orders_count,
    }

@router.get("/dashboard")
async def admin_dashboard(request: Request, db: AsyncSession = Depends(get_db)):
    """Panel Central Unificado: Comercios, Menús, Despachos, Soporte y Seguridad."""
    # 1. Órdenes pendientes de pago (CREATED)
    query = select(Order).where(Order.status == 'CREATED')
    result = await db.execute(query)
    orders = result.scalars().all()
    
    # 2. Órdenes activas en curso (APPROVED_BY_ADMIN, READY, ASSIGNED, PICKED_UP)
    active_query = select(Order).where(Order.status.in_(['APPROVED_BY_ADMIN', 'READY', 'ASSIGNED', 'PICKED_UP']))
    active_result = await db.execute(active_query)
    active_orders = active_result.scalars().all()
    
    # 3. Repartidores pendientes de aprobación (KYC)
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
    
    # 4. Restaurantes pendientes de aprobación
    pending_rest_q = select(Restaurant).where(Restaurant.is_approved == False)
    pending_rest_res = await db.execute(pending_rest_q)
    pending_restaurants = pending_rest_res.scalars().all()

    # 5. Restaurantes aprobados y sus productos
    rest_query = select(Restaurant).where(Restaurant.is_active == True, Restaurant.is_approved == True)
    rest_result = await db.execute(rest_query)
    approved_restaurants = rest_result.scalars().all()
    
    restaurants_data = []
    for r in approved_restaurants:
        prod_q = select(Product).where(Product.restaurant_id == r.id)
        prod_res = await db.execute(prod_q)
        products = prod_res.scalars().all()
        restaurants_data.append({
            "id": r.id,
            "name": r.name,
            "description": r.description,
            "logo_url": r.logo_url,
            "products_count": len(products),
            "products": products
        })

    # 6. Tickets de Soporte con datos del usuario
    ticket_q = (
        select(SupportTicket, User)
        .outerjoin(User, SupportTicket.user_id == User.id)
        .order_by(SupportTicket.id.desc())
    )
    ticket_res = await db.execute(ticket_q)
    support_tickets = []
    for ticket, user in ticket_res.all():
        support_tickets.append({
            "id": ticket.id,
            "order_id": ticket.order_id,
            "subject": ticket.subject,
            "description": ticket.description,
            "status": ticket.status,
            "created_at": ticket.created_at,
            "user_name": user.name if user else "Usuario Lorivery",
            "user_email": user.email if user else "No registrado"
        })

    # 7. Repartidores Aprobados con sus Calificaciones y Reseñas
    app_cour_q = (
        select(Courier, User)
        .join(User, Courier.user_id == User.id)
        .where(Courier.is_approved == True)
    )
    app_cour_res = await db.execute(app_cour_q)
    approved_couriers_list = []
    for c, u in app_cour_res.all():
        # Obtener últimas reseñas para este repartidor
        feedbacks_q = (
            select(Order.courier_rating, Order.courier_feedback, Order.id)
            .where(Order.courier_id == c.user_id, Order.courier_rating.isnot(None))
            .order_by(Order.id.desc())
            .limit(5)
        )
        feed_res = await db.execute(feedbacks_q)
        feedbacks = [
            {"rating": f[0], "comment": f[1] or "Sin comentario", "order_id": f[2]}
            for f in feed_res.all()
        ]

        approved_couriers_list.append({
            "courier_id": c.user_id,
            "name": u.name,
            "email": u.email,
            "phone_number": c.phone_number or "No registrado",
            "vehicle_type": c.vehicle_type,
            "rating": round(float(c.rating or 5.0), 1),
            "balance": c.balance,
            "is_available": c.is_available,
            "feedbacks": feedbacks
        })

    # 8. Estadísticas y Contadores para el panel
    u_res = await db.execute(select(func.count(User.id)))
    total_users = u_res.scalar() or 0

    c_res = await db.execute(select(func.count(User.id)).where(User.role == 'CLIENT'))
    total_clients = c_res.scalar() or 0

    cour_res = await db.execute(select(func.count(Courier.user_id)))
    total_couriers = cour_res.scalar() or 0

    cour_app_res = await db.execute(select(func.count(Courier.user_id)).where(Courier.is_approved == True))
    approved_couriers_count = cour_app_res.scalar() or 0

    cour_avail_res = await db.execute(select(func.count(Courier.user_id)).where(Courier.is_available == True))
    active_couriers_count = cour_avail_res.scalar() or 0
    
    return templates.TemplateResponse(
        request=request,
        name="dashboard.html",
        context={
            "orders": orders,
            "active_orders": active_orders,
            "pending_couriers": pending_couriers,
            "approved_couriers_list": approved_couriers_list,
            "pending_restaurants": pending_restaurants,
            "restaurants": restaurants_data,
            "support_tickets": support_tickets,
            "stats": {
                "total_users": total_users,
                "total_clients": total_clients,
                "total_couriers": total_couriers,
                "approved_couriers": approved_couriers_count,
                "active_couriers": active_couriers_count,
                "approved_restaurants": len(approved_restaurants),
                "pending_restaurants": len(pending_restaurants),
                "pending_orders": len(orders),
                "active_orders": len(active_orders)
            }
        }
    )
