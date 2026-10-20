"""
Modulo de Administracion (solo rol Administrador):
  - Usuarios: listar, crear (contrasena con hash), editar, activar/desactivar.
  - Mantenimiento de catalogos: listar, crear, editar, activar/desactivar
    (proveedores, repuestos, categorias, bodegas, metodos de pago, marcas, tipos).
"""
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.errors import traducir_error_sp
from app.core.security import hash_password
from app.db.database import get_db
from app.dependencies import require_roles
from app.repositories import admin_repo

router = APIRouter(prefix="/admin", tags=["Administracion"])
_ADMIN = require_roles("Administrador")


class EstadoIn(BaseModel):
    activo: bool


# ---------------- Usuarios ----------------
class UsuarioIn(BaseModel):
    id_rol: int
    nombre_usuario: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=4, max_length=72)
    nombres: str = Field(..., min_length=1, max_length=100)
    apellidos: str = Field(..., min_length=1, max_length=100)


class UsuarioUpdate(BaseModel):
    id_rol: int
    nombres: str = Field(..., min_length=1, max_length=100)
    apellidos: str = Field(..., min_length=1, max_length=100)
    password: str | None = Field(None, max_length=72)   # opcional: solo si se cambia


@router.get("/usuarios")
def listar_usuarios(db: Session = Depends(get_db), _=Depends(_ADMIN)):
    return admin_repo.listar_usuarios(db)


@router.post("/usuarios", status_code=201)
def crear_usuario(data: UsuarioIn, db: Session = Depends(get_db), _=Depends(_ADMIN)):
    if admin_repo.usuario_existe(db, data.nombre_usuario):
        raise HTTPException(status.HTTP_409_CONFLICT, "El nombre de usuario ya existe")
    try:
        nuevo = admin_repo.crear_usuario(db, data.id_rol, data.nombre_usuario,
                                         hash_password(data.password), data.nombres, data.apellidos)
    except Exception as exc:
        db.rollback()
        raise traducir_error_sp(exc)
    return {"id_usuario": nuevo}


@router.put("/usuarios/{id_usuario}")
def actualizar_usuario(id_usuario: int, data: UsuarioUpdate, db: Session = Depends(get_db), _=Depends(_ADMIN)):
    if data.password is not None and 0 < len(data.password) < 4:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "La contrasena debe tener al menos 4 caracteres")
    try:
        admin_repo.actualizar_usuario(db, id_usuario, data.id_rol, data.nombres, data.apellidos,
                                      hash_password(data.password) if data.password else None)
    except Exception as exc:
        db.rollback()
        raise traducir_error_sp(exc)
    return {"mensaje": "Usuario actualizado"}


@router.put("/usuarios/{id_usuario}/estado")
def cambiar_estado_usuario(id_usuario: int, data: EstadoIn, db: Session = Depends(get_db),
                           user: dict = Depends(_ADMIN)):
    if id_usuario == user["id_usuario"] and not data.activo:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "No puede desactivar su propio usuario")
    admin_repo.cambiar_estado_usuario(db, id_usuario, data.activo)
    return {"mensaje": "Estado actualizado"}


@router.get("/roles")
def listar_roles(db: Session = Depends(get_db), _=Depends(_ADMIN)):
    return admin_repo.listar_roles(db)


# ---------------- Catalogos (mantenimiento generico) ----------------
def _entidad(entidad: str) -> str:
    if entidad not in admin_repo.CATALOGOS:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Catalogo no encontrado")
    return entidad


@router.get("/catalogos/{entidad}")
def listar_catalogo(entidad: str, db: Session = Depends(get_db), _=Depends(_ADMIN)):
    return admin_repo.listar_catalogo(db, _entidad(entidad))


@router.post("/catalogos/{entidad}", status_code=201)
def crear_catalogo(entidad: str, data: dict[str, Any], db: Session = Depends(get_db), _=Depends(_ADMIN)):
    try:
        return {"id": admin_repo.crear_catalogo(db, _entidad(entidad), data)}
    except HTTPException:
        raise
    except Exception as exc:
        raise traducir_error_sp(exc)


@router.put("/catalogos/{entidad}/{id_}")
def actualizar_catalogo(entidad: str, id_: int, data: dict[str, Any], db: Session = Depends(get_db),
                        _=Depends(_ADMIN)):
    try:
        admin_repo.actualizar_catalogo(db, _entidad(entidad), id_, data)
    except HTTPException:
        raise
    except Exception as exc:
        raise traducir_error_sp(exc)
    return {"mensaje": "Registro actualizado"}


@router.put("/catalogos/{entidad}/{id_}/estado")
def estado_catalogo(entidad: str, id_: int, data: EstadoIn, db: Session = Depends(get_db), _=Depends(_ADMIN)):
    admin_repo.estado_catalogo(db, _entidad(entidad), id_, data.activo)
    return {"mensaje": "Estado actualizado"}
