from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.dependencies import require_roles
from app.schemas.compra import CompraRepuestoCreate, CompraCreate, CompraCreada
from app.services import compra_service

router = APIRouter(prefix="/compras", tags=["Compras"])
_BODEGA = require_roles("Administrador", "Bodega")


@router.post("", response_model=CompraCreada, status_code=201)
def registrar_compra(data: CompraCreate, db: Session = Depends(get_db), user: dict = Depends(_BODEGA)):
    """Compra con varios repuestos (SP usp_RegistrarCompra); con recibir=true tambien la recibe."""
    id_compra, recibida = compra_service.registrar_compra(db, data, user["id_usuario"])
    msg = "Compra registrada y recibida en inventario" if recibida else "Compra registrada (pendiente de recibir)"
    return CompraCreada(id_compra=id_compra, mensaje=msg)


@router.post("/{id_compra}/recibir")
def recibir_compra(id_compra: int, db: Session = Depends(get_db), user: dict = Depends(_BODEGA)):
    """Recibe una compra PENDIENTE: inventario + movimientos de entrada (SP usp_RecibirCompra)."""
    compra_service.recibir_compra(db, id_compra, user["id_usuario"])
    return {"mensaje": "Compra recibida en inventario"}


@router.post("/repuesto", response_model=CompraCreada, status_code=201)
def registrar_compra_repuesto(data: CompraRepuestoCreate, db: Session = Depends(get_db),
                              user: dict = Depends(_BODEGA)):
    """Compra rapida de UN repuesto, recibida al instante (SP usp_RegistrarCompraRepuesto)."""
    id_compra = compra_service.registrar_compra_repuesto(db, data, user["id_usuario"])
    return CompraCreada(id_compra=id_compra, mensaje="Compra registrada y recibida en inventario")
