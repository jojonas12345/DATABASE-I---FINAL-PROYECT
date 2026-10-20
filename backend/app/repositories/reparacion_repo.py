"""Repository de Reparaciones. Invoca usp_ConsumirRepuesto."""
from sqlalchemy.orm import Session

from app.db.sp import exec_sp


def consumir_repuesto(
    db: Session,
    id_reparacion: int,
    id_repuesto: int,
    id_bodega: int,
    cantidad: int,
    id_usuario: int,
) -> None:
    exec_sp(
        db,
        "usp_ConsumirRepuesto",
        {
            "id_reparacion": id_reparacion,
            "id_repuesto": id_repuesto,
            "id_bodega": id_bodega,
            "cantidad": cantidad,
            "id_usuario": id_usuario,
        },
    )
