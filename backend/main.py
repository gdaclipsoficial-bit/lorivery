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

@app.on_event("startup")
async def on_startup():
    """Crea las tablas en la BD si no existen (auto-migrate en Render)."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

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

from fastapi.responses import RedirectResponse

@app.get("/")
async def root():
    return {"message": "Lorica Delivery API en línea", "status": "active"}

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

