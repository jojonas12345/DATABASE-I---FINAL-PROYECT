"""
Punto de entrada de la API TechCare.
  - Configura CORS para que el frontend (puerto 5173 en desarrollo) pueda consumir.
  - Registra los routers por modulo.
  - Opcionalmente sirve el frontend compilado (opcion 2: un solo proceso web).

Levantar en desarrollo:  uvicorn app.main:app --reload
Docs interactivas:       http://localhost:8000/docs
"""
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.core.config import settings
from app.routers import (
    auth, clientes, compras, reparaciones, ordenes, facturas, catalogos,
    equipos, procesos, inventario, admin, dashboard, reportes,
)

app = FastAPI(
    title="TechCare Solutions API",
    description="Sistema Integral de Servicio Tecnico, Inventario y Facturacion",
    version="1.0.0",
)

# --- CORS: imprescindible en desarrollo (front y back en puertos distintos) ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=[settings.FRONTEND_ORIGIN],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Registro de routers (un router por modulo) ---
app.include_router(auth.router)
app.include_router(clientes.router)
app.include_router(ordenes.router)
app.include_router(reparaciones.router)
app.include_router(compras.router)
app.include_router(facturas.router)
app.include_router(catalogos.router)
app.include_router(equipos.router)
app.include_router(procesos.router)
app.include_router(inventario.router)
app.include_router(admin.router)
app.include_router(dashboard.router)
app.include_router(reportes.router)


@app.get("/api/health", tags=["Sistema"])
def health():
    return {"status": "ok", "servicio": "TechCare API"}


# --- Servir el frontend compilado (OPCION 2, para la entrega) ---
# Cuando hagas "npm run build" en frontend/, se genera frontend/dist.
# Descomenta para servir la interfaz desde el mismo proceso del backend:
#
# _dist = Path(__file__).resolve().parents[2] / "frontend" / "dist"
# if _dist.exists():
#     app.mount("/", StaticFiles(directory=_dist, html=True), name="frontend")
