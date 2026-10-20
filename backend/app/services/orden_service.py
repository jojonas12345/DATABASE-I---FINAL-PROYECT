from sqlalchemy.orm import Session

from app.core.errors import traducir_error_sp
from app.repositories import orden_repo
from app.schemas.orden import OrdenCreate, CambioEstado


def crear_orden(db: Session, data: OrdenCreate, id_usuario: int) -> int:
    try:
        return orden_repo.crear_orden(
            db,
            id_cliente=data.id_cliente,
            id_equipo=data.id_equipo,
            id_usuario_recepcion=id_usuario,
            problema=data.problema,
            prioridad=data.prioridad,
            fecha_estimada=data.fecha_estimada,
        )
    except Exception as exc:
        raise traducir_error_sp(exc)


def cambiar_estado(db: Session, id_orden: int, data: CambioEstado, id_usuario: int) -> None:
    try:
        orden_repo.cambiar_estado(db, id_orden, data.estado_nuevo, id_usuario, data.observacion)
    except Exception as exc:
        raise traducir_error_sp(exc)


def listar_activas(db: Session) -> list[dict]:
    return orden_repo.listar_activas(db)


def listar_todas(db: Session, estado: str | None) -> list[dict]:
    return orden_repo.listar_todas(db, estado)


def obtener_detalle(db: Session, id_orden: int) -> dict:
    det = orden_repo.obtener_detalle(db, id_orden)
    if not det:
        from fastapi import HTTPException, status
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Orden no encontrada")
    return det
