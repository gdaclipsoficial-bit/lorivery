import socket
import os
from dotenv import load_dotenv

# Cargar las variables de entorno[cite: 3]
load_dotenv()

from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import declarative_base

# PostgreSQL connection string (lee desde Supabase a través del .env)[cite: 3]
DATABASE_URL = os.getenv(
    "DATABASE_URL", 
    "postgresql+asyncpg://postgres@localhost:5432/lorica_delivery"
)

# Motor asíncrono configurado con SSL y caché de sentencias en 0 para Supabase[cite: 3]
engine = create_async_engine(
    DATABASE_URL, 
    echo=True, 
    pool_size=10, 
    max_overflow=20,
    connect_args={
        "ssl": "require",
        "statement_cache_size": 0
    }
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine, 
    class_=AsyncSession, 
    expire_on_commit=False
)

Base = declarative_base()

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session