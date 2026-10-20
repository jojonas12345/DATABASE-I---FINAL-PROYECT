from sqlalchemy.orm import Session

from app.core.errors import traducir_error_sp
from app.repositories import factura_repo
from app.schemas.factura import FacturaGenerar, PagoCreate


def generar_factura(db: Session, data: FacturaGenerar, id_usuario: int) -> int:
    try:
        return factura_repo.generar_factura(db, data.id_orden, id_usuario)
    except Exception as exc:
        raise traducir_error_sp(exc)


def registrar_pago(db: Session, data: PagoCreate) -> int:
    try:
        return factura_repo.registrar_pago(
            db, data.id_factura, data.id_metodo, data.monto, data.referencia
        )
    except Exception as exc:
        raise traducir_error_sp(exc)


def listar_con_saldo(db: Session) -> list[dict]:
    return factura_repo.listar_con_saldo(db)
