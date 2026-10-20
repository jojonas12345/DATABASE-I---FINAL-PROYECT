"""
Service de autenticacion: valida credenciales y emite el JWT.
El token lleva el id_usuario (sub) y el rol, para proteger endpoints y
para que los SP reciban el id_usuario que audita las operaciones.
"""
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import verify_password, create_access_token
from app.repositories import usuario_repo


def autenticar(db: Session, nombre_usuario: str, password: str) -> dict:
    usuario = usuario_repo.obtener_por_nombre_usuario(db, nombre_usuario)

    # Mismo mensaje para "no existe" y "password incorrecta": no revelar cual fallo.
    if not usuario or not verify_password(password, usuario["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario o contrasena incorrectos",
        )

    if not usuario["activo"]:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Usuario inactivo")

    # sub = id_usuario (como texto); el rol viaja para el control de acceso.
    token = create_access_token(subject=str(usuario["id_usuario"]), rol=usuario["rol"])
    return {
        "access_token": token,
        "token_type": "bearer",
        "rol": usuario["rol"],
        "id_usuario": usuario["id_usuario"],
        "nombre": f"{usuario['nombres']} {usuario['apellidos']}",
    }
