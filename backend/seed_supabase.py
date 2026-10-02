import asyncio
import uuid
import asyncpg

RESTAURANTS = [
    {
        'id': str(uuid.uuid4()),
        'name': 'El Sinuano Burger',
        'description': 'Las mejores hamburguesas del Sinú 🍔',
        'logo_url': None,
        'is_active': True,
        'products': [
            {'name': 'Hamburguesa Clásica', 'description': 'Carne 150g, lechuga, tomate, queso', 'price': 12000.0},
            {'name': 'Hamburguesa Doble', 'description': 'Doble carne, doble queso, salsa especial', 'price': 18000.0},
            {'name': 'Combo Sinuano', 'description': 'Hamburguesa + Papas + Gaseosa', 'price': 22000.0},
            {'name': 'Perro Caliente', 'description': 'Salchicha premium, salsas, papitas', 'price': 8000.0},
            {'name': 'Malteada Oreo', 'description': 'Helado de vainilla con galleta Oreo', 'price': 9000.0},
        ]
    },
    {
        'id': str(uuid.uuid4()),
        'name': 'Doña Luz - Comida Criolla',
        'description': 'Sabor casero de la costa 🍚🐟',
        'logo_url': None,
        'is_active': True,
        'products': [
            {'name': 'Mojarra Frita', 'description': 'Mojarra del río Sinú con patacón y arroz', 'price': 25000.0},
            {'name': 'Arroz con Pollo', 'description': 'Arroz amarillo con pollo desmechado', 'price': 15000.0},
            {'name': 'Bandeja Costeña', 'description': 'Carne, arroz, tajada, huevo, ensalada', 'price': 18000.0},
            {'name': 'Sancocho de Gallina', 'description': 'Sopa tradicional con yuca y plátano', 'price': 16000.0},
            {'name': 'Jugo de Corozo', 'description': 'Jugo natural de corozo bien frío', 'price': 5000.0},
        ]
    },
    {
        'id': str(uuid.uuid4()),
        'name': 'Pizza Lorica Express',
        'description': 'Pizza artesanal a domicilio 🍕',
        'logo_url': None,
        'is_active': True,
        'products': [
            {'name': 'Pizza Margarita', 'description': 'Tomate, mozzarella, albahaca', 'price': 20000.0},
            {'name': 'Pizza de Pollo BBQ', 'description': 'Pollo, cebolla caramelizada, salsa BBQ', 'price': 25000.0},
            {'name': 'Pizza Hawaiana', 'description': 'Jamón, piña, queso mozzarella', 'price': 22000.0},
            {'name': 'Calzone Mixto', 'description': 'Jamón, champiñones, queso fundido', 'price': 18000.0},
            {'name': 'Gaseosa 1.5L', 'description': 'Coca-Cola, Pepsi o Colombiana', 'price': 5000.0},
        ]
    },
]

async def seed():
    url = 'postgresql://postgres.zxzmkcujbmejicepfjip:3235886898daniel@aws-0-ca-central-1.pooler.supabase.com:6543/postgres'
    conn = await asyncpg.connect(url, ssl='require', statement_cache_size=0)
    for r in RESTAURANTS:
        await conn.execute('INSERT INTO restaurants (id, name, description, logo_url, is_active) VALUES ($1, $2, $3, $4, $5) ON CONFLICT (id) DO NOTHING;', r['id'], r['name'], r['description'], r['logo_url'], r['is_active'])
        for p in r['products']:
            await conn.execute('INSERT INTO products (id, restaurant_id, name, description, price, image_url, is_available) VALUES ($1, $2, $3, $4, $5, NULL, TRUE);', str(uuid.uuid4()), r['id'], p['name'], p['description'], p['price'])
        print(f"✅ {r['name']} + {len(r['products'])} productos")
    await conn.close()
    print("🚀 ¡Semilla de restaurantes completada en Supabase!")

if __name__ == '__main__':
    asyncio.run(seed())
