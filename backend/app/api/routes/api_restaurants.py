from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.models.domain import Restaurant, Product

router = APIRouter(prefix="/api/restaurants", tags=["Restaurants"])

@router.get("/")
async def get_restaurants(db: AsyncSession = Depends(get_db)):
    """Obtiene la lista de restaurantes activos."""
    query = select(Restaurant).where(Restaurant.is_active == True)
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
    logo: UploadFile = File(None),
    db: AsyncSession = Depends(get_db)
):
    """Crea un nuevo restaurante para la plataforma."""
    logo_url = None
    if logo and logo.filename:
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
        is_active=True
    )
    db.add(new_restaurant)
    await db.commit()
    await db.refresh(new_restaurant)
    return {
        "status": "success",
        "restaurant_id": new_restaurant.id,
        "name": new_restaurant.name,
        "dashboard_url": f"/merchant-web/{new_restaurant.id}/dashboard"
    }

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

from fastapi import UploadFile, File, Form, HTTPException
import uuid
import shutil
import os

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

