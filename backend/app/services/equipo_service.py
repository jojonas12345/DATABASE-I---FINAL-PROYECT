from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.errors import traducir_error_sp
from app.repositories import equipo_repo
from app.schemas.equipo import EquipoCreate, EquipoUpdate


def crear_equipo(db: Session, data: EquipoCreate) -> dict:
    if equipo_repo.serie_existe(db, data.serie):
        raise HTTPException(status.HTTP_409_CONFLICT, "Ya existe un equipo con esa serie")
    try:
        nuevo = equipo_repo.crear(db, data.model_dump())
    except Exception as exc:
        db.rollback()
        raise traducir_error_sp(exc)
    return equipo_repo.obtener(db, nuevo)


def actualizar_equipo(db: Session, id_equipo: int, data: EquipoUpdate) -> dict:
    if not equipo_repo.obtener(db, id_equipo):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Equipo no encontrado")
    if equipo_repo.serie_existe(db, data.serie, excluir_id=id_equipo):
        raise HTTPException(status.HTTP_409_CONFLICT, "Ya existe otro equipo con esa serie")
    try:
        equipo_repo.actualizar(db, id_equipo, data.model_dump())
    except Exception as exc:
        db.rollback()
        raise traducir_error_sp(exc)
    return equipo_repo.obtener(db, id_equipo)
