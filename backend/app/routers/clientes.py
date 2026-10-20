from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.dependencies import require_roles, get_current_user
from app.schemas.cliente import ClienteCreate, ClienteOut
from app.services import cliente_service

router = APIRouter(prefix="/clientes", tags=["Clientes"])
_GESTION = require_roles("Administrador", "Recepcion")


class EstadoIn(BaseModel):
    activo: bool


@router.get("", response_model=list[ClienteOut])
def listar(incluir_inactivos: bool = False, db: Session = Depends(get_db), _=Depends(get_current_user)):
    return cliente_service.listar_clientes(db, incluir_inactivos)


@router.get("/{id_cliente}", response_model=ClienteOut)
def obtener(id_cliente: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    return cliente_service.obtener_cliente(db, id_cliente)


@router.post("", response_model=ClienteOut, status_code=201)
def crear(data: ClienteCreate, db: Session = Depends(get_db), _=Depends(_GESTION)):
    return cliente_service.crear_cliente(db, data)


@router.put("/{id_cliente}", response_model=ClienteOut)
def actualizar(id_cliente: int, data: ClienteCreate, db: Session = Depends(get_db), _=Depends(_GESTION)):
    return cliente_service.actualizar_cliente(db, id_cliente, data)


@router.put("/{id_cliente}/estado")
def cambiar_estado(id_cliente: int, data: EstadoIn, db: Session = Depends(get_db), _=Depends(_GESTION)):
    cliente_service.cambiar_estado(db, id_cliente, data.activo)
    return {"mensaje": "Estado actualizado"}
