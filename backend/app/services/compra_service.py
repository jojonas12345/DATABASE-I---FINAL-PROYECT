from sqlalchemy.orm import Session

from app.core.errors import traducir_error_sp
from app.repositories import compra_repo
from app.schemas.compra import CompraRepuestoCreate, CompraCreate


def registrar_compra_repuesto(db: Session, data: CompraRepuestoCreate, id_usuario: int) -> int:
    try:
        return compra_repo.registrar_compra_repuesto(
            db, data.id_proveedor, data.id_bodega, id_usuario,
            data.id_repuesto, data.cantidad, data.costo_unitario)
    except Exception as exc:
        raise traducir_error_sp(exc)


def registrar_compra(db: Session, data: CompraCreate, id_usuario: int) -> tuple[int, bool]:
    """Registra la compra (PENDIENTE) y, si se pidio, la recibe a continuacion.
    Son dos transacciones: si la recepcion fallara, la compra queda PENDIENTE
    (estado consistente) y puede recibirse despues."""
    try:
        id_compra = compra_repo.registrar_compra(
            db, data.id_proveedor, data.id_bodega, id_usuario,
            [l.model_dump() for l in data.detalle])
    except Exception as exc:
        raise traducir_error_sp(exc)
    if data.recibir:
        recibir_compra(db, id_compra, id_usuario)
    return id_compra, data.recibir


def recibir_compra(db: Session, id_compra: int, id_usuario: int) -> None:
    try:
        compra_repo.recibir_compra(db, id_compra, id_usuario)
    except Exception as exc:
        raise traducir_error_sp(exc)
