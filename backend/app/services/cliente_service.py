from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.errors import traducir_error_sp
from app.repositories import cliente_repo
from app.schemas.cliente import ClienteCreate


def _normalizar(data: ClienteCreate) -> dict:
    body = data.model_dump()
    if body["tipo"] == "INDIVIDUAL":
        body["razon_social"] = None
    else:
        body["nombres"] = body["apellidos"] = None
    for k in ("telefono", "email", "direccion"):
        if isinstance(body.get(k), str) and not body[k].strip():
            body[k] = None
    return body


def listar_clientes(db: Session, incluir_inactivos: bool = False) -> list[dict]:
    return cliente_repo.listar(db, incluir_inactivos)


def obtener_cliente(db: Session, id_cliente: int) -> dict:
    cliente = cliente_repo.obtener(db, id_cliente)
    if not cliente:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Cliente no encontrado")
    return cliente


def crear_cliente(db: Session, data: ClienteCreate) -> dict:
    if cliente_repo.nit_existe(db, data.nit):
        raise HTTPException(status.HTTP_409_CONFLICT, "Ya existe un cliente con ese NIT")
    try:
        nuevo_id = cliente_repo.crear(db, _normalizar(data))
    except Exception as exc:
        db.rollback()
        raise traducir_error_sp(exc)
    return cliente_repo.obtener(db, nuevo_id)


def actualizar_cliente(db: Session, id_cliente: int, data: ClienteCreate) -> dict:
    obtener_cliente(db, id_cliente)
    if cliente_repo.nit_existe(db, data.nit, excluir_id=id_cliente):
        raise HTTPException(status.HTTP_409_CONFLICT, "Ya existe otro cliente con ese NIT")
    try:
        cliente_repo.actualizar(db, id_cliente, _normalizar(data))
    except Exception as exc:
        db.rollback()
        raise traducir_error_sp(exc)
    return cliente_repo.obtener(db, id_cliente)


def cambiar_estado(db: Session, id_cliente: int, activo: bool) -> None:
    obtener_cliente(db, id_cliente)
    cliente_repo.cambiar_estado(db, id_cliente, activo)
