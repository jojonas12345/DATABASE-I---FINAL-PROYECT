"""
Conexion a SQL Server mediante SQLAlchemy sobre pyodbc.

El engine se crea una sola vez y se reutiliza (pool de conexiones).
get_db() es una dependencia de FastAPI que entrega una sesion por peticion
y la cierra al terminar, incluso si hubo error.
"""
from urllib.parse import quote_plus

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

from app.core.config import settings

# SQLAlchemy necesita la cadena ODBC "url-encoded" dentro de la URL mssql+pyodbc
_params = quote_plus(settings.odbc_connection_string)
DATABASE_URL = f"mssql+pyodbc:///?odbc_connect={_params}"

engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,   # verifica la conexion antes de usarla (evita conexiones muertas)
    fast_executemany=True,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base para los modelos ORM (si decides mapear tablas). Los procedimientos
# almacenados se llaman por separado desde los repositories.
Base = declarative_base()


def get_db():
    """Dependencia FastAPI: una sesion por peticion."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
