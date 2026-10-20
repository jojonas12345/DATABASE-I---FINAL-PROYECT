from sqlalchemy.orm import Session

from app.core.errors import traducir_error_sp
from app.repositories import reparacion_repo
from app.schemas.reparacion import ConsumoRepuestoCreate


def consumir_repuesto(
    db: Session, id_reparacion: int, data: ConsumoRepuestoCreate, id_usuario: int
) -> None:
    try:
        reparacion_repo.consumir_repuesto(
            db,
            id_reparacion=id_reparacion,
            id_repuesto=data.id_repuesto,
            id_bodega=data.id_bodega,
            cantidad=data.cantidad,
            id_usuario=id_usuario,
        )
    except Exception as exc:
        raise traducir_error_sp(exc)
