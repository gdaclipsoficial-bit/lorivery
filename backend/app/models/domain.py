import uuid
from sqlalchemy import Column, String, Float, Boolean, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from geoalchemy2 import Geometry, Geography
from app.core.database import Base

class User(Base):
    __tablename__ = "users"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False)
    password_hash = Column(String, nullable=False)
    role = Column(String, default="CLIENT")  # CLIENT, COURIER, ADMIN

class Courier(Base):
    __tablename__ = "couriers"
    user_id = Column(String, ForeignKey("users.id"), primary_key=True)
    vehicle_type = Column(String, default="MOTORCYCLE")
    phone_number = Column(String, nullable=True)
    national_id = Column(String, nullable=True)
    is_available = Column(Boolean, default=False)
    balance = Column(Float, default=0.0)
    
    # Verificación de Identidad
    id_front_url = Column(String, nullable=True)
    id_back_url = Column(String, nullable=True)
    selfie_url = Column(String, nullable=True)
    is_approved = Column(Boolean, default=False)  # Admin debe aprobarlo
    
    # Updated to Geography for strict meter-based distances
    location = Column(Geography(geometry_type='POINT', srid=4326, spatial_index=True))
    
    rating = Column(Float, default=5.0)

class Order(Base):
    __tablename__ = "orders"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    client_id = Column(String, ForeignKey("users.id"))
    courier_id = Column(String, ForeignKey("couriers.user_id"), nullable=True)
    restaurant_id = Column(String, ForeignKey("restaurants.id"), nullable=True)
    status = Column(String, default="CREATED") # CREATED, READY, ASSIGNED...
    payment_proof_url = Column(String, nullable=True)
    
    # Campo agregado para almacenar la dirección de entrega del cliente
    delivery_address = Column(String, nullable=True)
    
    delivery_lat = Column(Float)
    delivery_lng = Column(Float)
    restaurant_lat = Column(Float)
    restaurant_lng = Column(Float)
    delivery_fee = Column(Float, default=0.0)
    pickup_code = Column(String(4), nullable=True)
    delivery_code = Column(String(4), nullable=True)

class Restaurant(Base):
    __tablename__ = "restaurants"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    logo_url = Column(String, nullable=True)
    is_active = Column(Boolean, default=True)
    is_approved = Column(Boolean, default=False)  # Requiere aprobación del administrador
    # location = Column(Geography(geometry_type='POINT', srid=4326))

class Product(Base):
    __tablename__ = "products"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    restaurant_id = Column(String, ForeignKey("restaurants.id"), nullable=False)
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    price = Column(Float, nullable=False)
    image_url = Column(String, nullable=True)
    is_available = Column(Boolean, default=True)