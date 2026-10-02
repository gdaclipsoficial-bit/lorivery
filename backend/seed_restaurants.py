"""
Seed script: Inserta 3 restaurantes ficticios con sus productos en la BD.
Ejecutar: python seed_restaurants.py
"""
import asyncio
import uuid
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import text

DATABASE_URL = "postgresql+asyncpg://postgres@localhost:5432/lorica_delivery"

# 3 Negocios ficticios de comida de Lorica
RESTAURANTS = [
    {
        "id": str(uuid.uuid4()),
        "name": "El Sinuano Burger",
        "description": "Las mejores hamburguesas del Sinú 🍔",
        "logo_url": None,
        "is_active": True,
        "products": [
            {"name": "Hamburguesa Clásica", "description": "Carne 150g, lechuga, tomate, queso", "price": 12000},
            {"name": "Hamburguesa Doble", "description": "Doble carne, doble queso, salsa especial", "price": 18000},
            {"name": "Combo Sinuano", "description": "Hamburguesa + Papas + Gaseosa", "price": 22000},
            {"name": "Perro Caliente", "description": "Salchicha premium, salsas, papitas", "price": 8000},
            {"name": "Malteada Oreo", "description": "Helado de vainilla con galleta Oreo", "price": 9000},
        ]
    },
    {
        "id": str(uuid.uuid4()),
        "name": "Doña Luz - Comida Criolla",
        "description": "Sabor casero de la costa 🍚🐟",
        "logo_url": None,
        "is_active": True,
        "products": [
            {"name": "Mojarra Frita", "description": "Mojarra del río Sinú con patacón y arroz", "price": 25000},
            {"name": "Arroz con Pollo", "description": "Arroz amarillo con pollo desmechado", "price": 15000},
            {"name": "Bandeja Costeña", "description": "Carne, arroz, tajada, huevo, ensalada", "price": 18000},
            {"name": "Sancocho de Gallina", "description": "Sopa tradicional con yuca y plátano", "price": 16000},
            {"name": "Jugo de Corozo", "description": "Jugo natural de corozo bien frío", "price": 5000},
        ]
    },
    {
        "id": str(uuid.uuid4()),
        "name": "Pizza Lorica Express",
        "description": "Pizza artesanal a domicilio 🍕",
        "logo_url": None,
        "is_active": True,
        "products": [
            {"name": "Pizza Margarita", "description": "Tomate, mozzarella, albahaca", "price": 20000},
            {"name": "Pizza de Pollo BBQ", "description": "Pollo, cebolla caramelizada, salsa BBQ", "price": 25000},
            {"name": "Pizza Hawaiana", "description": "Jamón, piña, queso mozzarella", "price": 22000},
            {"name": "Calzone Mixto", "description": "Jamón, champiñones, queso fundido", "price": 18000},
            {"name": "Gaseosa 1.5L", "description": "Coca-Cola, Pepsi o Colombiana", "price": 5000},
        ]
    },
]


async def seed():
    engine = create_async_engine(DATABASE_URL)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        for r in RESTAURANTS:
            # Insertar restaurante
            await session.execute(text(
                "INSERT INTO restaurants (id, name, description, logo_url, is_active) "
                "VALUES (:id, :name, :description, :logo_url, :is_active) "
                "ON CONFLICT (id) DO NOTHING"
            ), {"id": r["id"], "name": r["name"], "description": r["description"],
                "logo_url": r["logo_url"], "is_active": r["is_active"]})

            # Insertar productos
            for p in r["products"]:
                await session.execute(text(
                    "INSERT INTO products (id, restaurant_id, name, description, price, image_url, is_available) "
                    "VALUES (:id, :rid, :name, :desc, :price, NULL, TRUE)"
                ), {"id": str(uuid.uuid4()), "rid": r["id"], "name": p["name"],
                    "desc": p["description"], "price": p["price"]})

            print(f"  ✅ {r['name']} + {len(r['products'])} productos")

        await session.commit()
        print("\n🎉 ¡3 restaurantes y 15 productos sembrados en la BD!")

    await engine.dispose()

if __name__ == "__main__":
    asyncio.run(seed())

