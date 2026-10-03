from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from app.core.database import get_db
from app.models.domain import Restaurant, Product
import uuid
import shutil
import os

router = APIRouter(prefix="/api/restaurants", tags=["Restaurants"])

@router.get("/")
async def get_restaurants(db: AsyncSession = Depends(get_db)):
    """Obtiene la lista de restaurantes aprobados y activos."""
    query = select(Restaurant).where(Restaurant.is_active == True, Restaurant.is_approved == True)
    result = await db.execute(query)
    restaurants = result.scalars().all()
    
    return [
        {
            "id": r.id,
            "name": r.name,
            "description": r.description,
            "logo_url": r.logo_url,
        }
        for r in restaurants
    ]

@router.get("/catalog")
async def get_menu_catalog(db: AsyncSession = Depends(get_db)):
    """Obtiene el catálogo completo de platos y restaurantes disponibles en tiempo real."""
    query_rest = select(Restaurant).where(Restaurant.is_active == True, Restaurant.is_approved == True)
    result_rest = await db.execute(query_rest)
    restaurants = result_rest.scalars().all()
    
    rest_ids = [r.id for r in restaurants]
    rest_map = {r.id: r for r in restaurants}
    
    if not rest_ids:
        return {"restaurants": [], "products": []}
        
    query_prod = select(Product).where(Product.restaurant_id.in_(rest_ids), Product.is_available == True)
    result_prod = await db.execute(query_prod)
    products = result_prod.scalars().all()
    
    return {
        "restaurants": [
            {
                "id": r.id,
                "name": r.name,
                "description": r.description,
                "logo_url": r.logo_url
            }
            for r in restaurants
        ],
        "products": [
            {
                "id": p.id,
                "restaurant_id": p.restaurant_id,
                "restaurant_name": rest_map.get(p.restaurant_id).name if rest_map.get(p.restaurant_id) else "Lorivery",
                "name": p.name,
                "description": p.description,
                "price": p.price,
                "image_url": p.image_url,
                "is_available": p.is_available
            }
            for p in products
        ]
    }

@router.get("/pending")
async def get_pending_restaurants(db: AsyncSession = Depends(get_db)):
    """Obtiene la lista de restaurantes pendientes de aprobación por el Administrador."""
    query = select(Restaurant).where(Restaurant.is_approved == False)
    result = await db.execute(query)
    restaurants = result.scalars().all()
    
    return [
        {
            "id": r.id,
            "name": r.name,
            "description": r.description,
            "logo_url": r.logo_url,
        }
        for r in restaurants
    ]

@router.post("/")
async def create_restaurant(
    name: str = Form(...),
    description: str = Form(None),
    pin: str = Form(...),
    logo: UploadFile = File(...),
    db: AsyncSession = Depends(get_db)
):
    """Crea un nuevo restaurante con su PIN de acceso exclusivo y logo obligatorio."""
    if not logo or not logo.filename:
        raise HTTPException(status_code=400, detail="El logo o foto de la fachada es obligatorio.")

    if not pin or len(pin.strip()) < 3:
        raise HTTPException(status_code=400, detail="Debes definir una clave o PIN de al menos 3 dígitos para proteger tu negocio.")

    file_ext = logo.filename.split(".")[-1]
    filename = f"{uuid.uuid4()}.{file_ext}"
    filepath = os.path.join("uploads", filename)
    
    with open(filepath, "wb") as buffer:
        shutil.copyfileobj(logo.file, buffer)
        
    logo_url = f"/uploads/{filename}"

    new_restaurant = Restaurant(
        id=str(uuid.uuid4()),
        name=name,
        description=description,
        logo_url=logo_url,
        access_pin=pin.strip(),
        is_active=True,
        is_approved=False  # Requiere aprobación del administrador antes de ser visible a clientes
    )
    db.add(new_restaurant)
    await db.commit()
    await db.refresh(new_restaurant)
    return {
        "status": "success",
        "message": "Restaurante registrado exitosamente. En espera de aprobación por la administración.",
        "restaurant_id": new_restaurant.id,
        "name": new_restaurant.name,
        "dashboard_url": f"/merchant-web/{new_restaurant.id}/dashboard"
    }

@router.post("/{restaurant_id}/verify-pin")
async def verify_restaurant_pin(
    restaurant_id: str,
    pin: str = Form(...),
    db: AsyncSession = Depends(get_db)
):
    """Verifica si el PIN ingresado coincide con el del restaurante."""
    query = select(Restaurant).where(Restaurant.id == restaurant_id)
    result = await db.execute(query)
    restaurant = result.scalars().first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurante no encontrado")

    if restaurant.access_pin != pin.strip():
        raise HTTPException(status_code=401, detail="PIN o clave incorrecta")

    return {"status": "success", "authenticated": True, "restaurant_id": restaurant.id}

@router.patch("/{restaurant_id}/approve")
async def approve_restaurant(restaurant_id: str, db: AsyncSession = Depends(get_db)):
    """Aprueba un restaurante para que sus productos sean visibles para todos los clientes."""
    from sqlalchemy import update
    query = update(Restaurant).where(Restaurant.id == restaurant_id).values(is_approved=True, is_active=True)
    result = await db.execute(query)
    await db.commit()
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Restaurante no encontrado")
    return {"status": "success", "message": "Restaurante aprobado exitosamente."}

@router.delete("/{restaurant_id}")
async def delete_restaurant(restaurant_id: str, db: AsyncSession = Depends(get_db)):
    """Elimina un restaurante y sus productos."""
    from sqlalchemy import delete
    # Eliminar primero los productos asociados
    await db.execute(delete(Product).where(Product.restaurant_id == restaurant_id))
    # Eliminar el restaurante
    query = select(Restaurant).where(Restaurant.id == restaurant_id)
    result = await db.execute(query)
    restaurant = result.scalars().first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurante no encontrado")
    await db.delete(restaurant)
    await db.commit()
    return {"status": "success", "message": "Restaurante eliminado"}

@router.get("/{restaurant_id}/products")
async def get_restaurant_products(restaurant_id: str, db: AsyncSession = Depends(get_db)):
    """Obtiene los productos de un restaurante específico."""
    query = select(Product).where(Product.restaurant_id == restaurant_id, Product.is_available == True)
    result = await db.execute(query)
    products = result.scalars().all()
    
    return [
        {
            "id": p.id,
            "name": p.name,
            "description": p.description,
            "price": p.price,
            "image_url": p.image_url,
            "is_available": p.is_available,
        }
        for p in products
    ]

@router.post("/{restaurant_id}/products")
async def create_product(
    restaurant_id: str,
    name: str = Form(...),
    description: str = Form(None),
    price: float = Form(...),
    image: UploadFile = File(None),
    db: AsyncSession = Depends(get_db)
):
    """Permite al restaurante publicar un nuevo producto en su menú."""
    image_url = None
    if image and image.filename:
        file_ext = image.filename.split(".")[-1]
        filename = f"{uuid.uuid4()}.{file_ext}"
        filepath = os.path.join("uploads", filename)
        
        with open(filepath, "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)
            
        image_url = f"/uploads/{filename}"
        
    product = Product(
        restaurant_id=restaurant_id,
        name=name,
        description=description,
        price=price,
        image_url=image_url,
        is_available=True
    )
    db.add(product)
    await db.commit()
    await db.refresh(product)
    return {"status": "success", "product_id": product.id, "name": product.name}

@router.patch("/products/{product_id}/toggle")
async def toggle_product_availability(product_id: str, db: AsyncSession = Depends(get_db)):
    """Activa o desactiva la disponibilidad de un producto en el menú."""
    query = select(Product).where(Product.id == product_id)
    result = await db.execute(query)
    product = result.scalars().first()
    
    if not product:
        raise HTTPException(status_code=404, detail="Producto no encontrado")
        
    product.is_available = not product.is_available
    await db.commit()
    return {"status": "success", "is_available": product.is_available}

@router.delete("/products/{product_id}")
async def delete_product(product_id: str, db: AsyncSession = Depends(get_db)):
    """Elimina un producto del menú."""
    query = select(Product).where(Product.id == product_id)
    result = await db.execute(query)
    product = result.scalars().first()
    
    if not product:
        raise HTTPException(status_code=404, detail="Producto no encontrado")
        
    await db.delete(product)
    await db.commit()
    return {"status": "success", "message": "Producto eliminado"}

@router.patch("/orders/{order_id}/ready")
async def mark_order_ready(order_id: str, db: AsyncSession = Depends(get_db)):
    """
    El restaurante confirma que la comida ya está preparada.
    1. Cambia el estado del pedido a READY.
    2. Transmite el pedido al radar de repartidores (demo_order).
    3. Notifica al cliente por WebSocket.
    """
    from sqlalchemy import update, text
    from app.models.domain import Order
    from app.websockets.connection_manager import manager

    query = (
        update(Order)
        .where(Order.id == order_id)
        .values(status='READY')
        .returning(Order)
    )
    result = await db.execute(query)
    updated_order = result.fetchone()

    if not updated_order:
        raise HTTPException(status_code=404, detail="Orden no encontrada")

    order = updated_order[0]
    await db.commit()

    # Obtener nombre del restaurante
    restaurant_name = "Restaurante Local"
    if order.restaurant_id:
        res_r = await db.execute(text("SELECT name FROM restaurants WHERE id = :rid"), {"rid": order.restaurant_id})
        r_row = res_r.fetchone()
        if r_row:
            restaurant_name = r_row[0]

    fee = order.delivery_fee or 3000

    # 1. Notificar al cliente
    await manager.broadcast_to_room(
        room_id=order_id,
        message={
            "type": "STATUS_UPDATE",
            "status": "READY",
            "message": "¡Tu pedido está preparado! Buscando repartidor en Lorica..."
        }
    )

    # 2. Transmitir al RADAR DE REPARTIDORES recién ahora que el restaurante lo marcó listo
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

    return {"status": "success", "message": "Pedido marcado como preparado y transmitido a repartidores"}


