from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv
load_dotenv()  # Esto busca y carga el archivo .env automáticamente
import os
from app.websockets.connection_manager import manager
from app.api.routes import orders
from app.api.routes import admin
from app.api.routes import admin_web
from app.api.routes import auth
from app.api.routes import api_restaurants
from app.api.routes import couriers
from app.api.routes import merchant_web
from app.core.database import engine, Base
# Importar todos los modelos para que Base.metadata los registre
import app.models.domain  # noqa: F401

app = FastAPI(title="Lorica Delivery MVP Backend")

from sqlalchemy import text

@app.on_event("startup")
async def on_startup():
    """Crea las tablas en la BD si no existen (auto-migrate en Render) y aplica columnas faltantes."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        # Migraciones de columnas adicionales
        try:
            await conn.execute(text('ALTER TABLE orders ADD COLUMN IF NOT EXISTS courier_rating FLOAT;'))
            await conn.execute(text('ALTER TABLE orders ADD COLUMN IF NOT EXISTS courier_feedback VARCHAR;'))
            await conn.execute(text('ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_address VARCHAR;'))
            await conn.execute(text('ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_fee FLOAT DEFAULT 0.0;'))
            await conn.execute(text('ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_code VARCHAR(4);'))
            await conn.execute(text('ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_code VARCHAR(4);'))
            await conn.execute(text('ALTER TABLE orders ADD COLUMN IF NOT EXISTS restaurant_id VARCHAR;'))
            await conn.execute(text('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS access_pin VARCHAR DEFAULT \'1234\';'))
            await conn.execute(text('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT FALSE;'))
            await conn.execute(text('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;'))
            await conn.execute(text('ALTER TABLE couriers ADD COLUMN IF NOT EXISTS id_front_url VARCHAR;'))
            await conn.execute(text('ALTER TABLE couriers ADD COLUMN IF NOT EXISTS id_back_url VARCHAR;'))
            await conn.execute(text('ALTER TABLE couriers ADD COLUMN IF NOT EXISTS selfie_url VARCHAR;'))
            await conn.execute(text('ALTER TABLE couriers ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT FALSE;'))
            await conn.execute(text('ALTER TABLE couriers ADD COLUMN IF NOT EXISTS phone_number VARCHAR;'))
            await conn.execute(text('ALTER TABLE couriers ADD COLUMN IF NOT EXISTS national_id VARCHAR;'))
            await conn.execute(text('ALTER TABLE couriers ADD COLUMN IF NOT EXISTS rating FLOAT DEFAULT 5.0;'))
        except Exception as ex:
            print(f"[STARTUP MIGRATION WARNING] {ex}")

os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(orders.router)
app.include_router(admin.router)
app.include_router(admin_web.router)
app.include_router(auth.router)
app.include_router(api_restaurants.router)
app.include_router(couriers.router)
app.include_router(merchant_web.router)

from fastapi import Request
from fastapi.templating import Jinja2Templates

templates = Jinja2Templates(directory="templates")

@app.get("/")
async def root(request: Request):
    accept = request.headers.get("accept", "")
    if "text/html" in accept or "*/*" in accept:
        return templates.TemplateResponse(request=request, name="landing.html")
    return {"message": "Lorica Delivery API en línea", "status": "active"}

@app.get("/download")
async def download_page(request: Request):
    return templates.TemplateResponse(request=request, name="landing.html")

from fastapi.responses import FileResponse, Response, RedirectResponse

@app.get("/repartidor.jpg")
async def serve_repartidor():
    if os.path.exists("repartidor.jpg"):
        return FileResponse("repartidor.jpg")
    if os.path.exists("uploads/repartidor.jpg"):
        return FileResponse("uploads/repartidor.jpg")
    return Response(status_code=404)

@app.get("/cliente.jpg")
async def serve_cliente():
    if os.path.exists("cliente.jpg"):
        return FileResponse("cliente.jpg")
    if os.path.exists("uploads/cliente.jpg"):
        return FileResponse("uploads/cliente.jpg")
    return Response(status_code=404)

@app.get("/dashboard")
async def dashboard_redirect():
    return RedirectResponse(url="/admin-web/dashboard")

@app.websocket("/ws/orders/{order_id}")
async def order_websocket(websocket: WebSocket, order_id: str):
    await manager.connect(websocket, room_id=order_id)
    try:
        while True:
            data = await websocket.receive_json()
            # Retransmitir actualizaciones GPS hiperrápidas (Modo Dios)
            if data.get("type") == "GPS_UPDATE":
                await manager.broadcast_to_room(
                    room_id=order_id, 
                    message=data # Rebote directo sin latencia
                )
    except WebSocketDisconnect:
        manager.disconnect(websocket, room_id=order_id)

