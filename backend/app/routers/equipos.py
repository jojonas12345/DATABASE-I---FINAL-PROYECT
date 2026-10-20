from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.dependencies import require_roles
from app.repositories import equipo_repo
from app.schemas.equipo import EquipoCreate, EquipoUpdate, EquipoOut
from app.services import equipo_service

router = APIRouter(prefix="/equipos", tags=["Equipos"])
_GESTION = require_roles("Administrador", "Recepcion")


class EstadoIn(BaseModel):
    activo: bool


@router.post("", response_model=EquipoOut, status_code=201)
def crear(data: EquipoCreate, db: Session = Depends(get_db), _=Depends(_GESTION)):
    return equipo_service.crear_equipo(db, data)


@router.put("/{id_equipo}", response_model=EquipoOut)
def actualizar(id_equipo: int, data: EquipoUpdate, db: Session = Depends(get_db), _=Depends(_GESTION)):
    return equipo_service.actualizar_equipo(db, id_equipo, data)


@router.put("/{id_equipo}/estado")
def cambiar_estado(id_equipo: int, data: EstadoIn, db: Session = Depends(get_db), _=Depends(_GESTION)):
    equipo_repo.cambiar_estado(db, id_equipo, data.activo)
    return {"mensaje": "Estado actualizado"}
