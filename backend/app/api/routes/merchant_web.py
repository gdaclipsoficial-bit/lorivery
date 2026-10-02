from fastapi import APIRouter, Request, Depends, HTTPException
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.models.domain import Restaurant, Product, Order

router = APIRouter(prefix="/merchant-web", tags=["Merchant Web"])
templates = Jinja2Templates(directory="templates")

@router.get("/dashboard")
async def merchant_portal_select(db: AsyncSession = Depends(get_db)):
    """Si no se pasa restaurant_id, lista los restaurantes registrados."""
    query = select(Restaurant)
    result = await db.execute(query)
    restaurants = result.scalars().all()
    
    return [
        {"id": r.id, "name": r.name, "dashboard_url": f"/merchant-web/{r.id}/dashboard"}
        for r in restaurants
    ]

@router.get("/{restaurant_id}/dashboard")
async def merchant_dashboard(restaurant_id: str, request: Request, db: AsyncSession = Depends(get_db)):
    """Panel de administración exclusivo para un restaurante."""
    # 1. Obtener datos del restaurante
    res_query = select(Restaurant).where(Restaurant.id == restaurant_id)
    res_result = await db.execute(res_query)
    restaurant = res_result.scalars().first()
    
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurante no encontrado")
        
    # 2. Obtener menú/productos del restaurante
    prod_query = select(Product).where(Product.restaurant_id == restaurant_id)
    prod_result = await db.execute(prod_query)
    products = prod_result.scalars().all()
    
    # 3. Obtener pedidos activos para este restaurante (incluyendo pickup_code / delivery_code)
    order_query = select(Order).where(Order.status.in_(["READY", "ASSIGNED", "AT_RESTAURANT", "PICKED_UP", "ON_THE_WAY"]))
    order_result = await db.execute(order_query)
    active_orders = order_result.scalars().all()
    
    return templates.TemplateResponse(
        request=request,
        name="merchant_dashboard.html",
        context={
            "restaurant": restaurant,
            "products": products,
            "orders": active_orders
        }
    )
