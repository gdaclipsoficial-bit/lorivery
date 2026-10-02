import socket
import os
from dotenv import load_dotenv

# Cargar las variables de entorno[cite: 3]
load_dotenv()

from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import declarative_base

raw_url = os.getenv(
    "DATABASE_URL", 
    "postgresql+asyncpg://postgres@localhost:5432/lorica_delivery"
)

# Limpiar comillas, espacios y caracteres invisibles si fueron copiados en Render
DATABASE_URL = raw_url.strip().strip("'").strip('"')

# Normalizar prefijo para asyncpg si proviene de Supabase o Render
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql+asyncpg://", 1)
elif DATABASE_URL.startswith("postgresql://") and not DATABASE_URL.startswith("postgresql+asyncpg://"):
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://", 1)

from sqlalchemy.engine import make_url

print(f"--> [DATABASE_URL RAW PREFIX]: '{DATABASE_URL[:18]}...' (Length: {len(DATABASE_URL)})")

try:
    url_obj = make_url(DATABASE_URL)
    print(f"--> [DATABASE_URL] Parsed OK: driver={url_obj.drivername}, host={url_obj.host}, db={url_obj.database}")
except Exception as err:
    print(f"--> [DATABASE_URL ERROR] Failed to parse URL: {err}")
    raise err

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