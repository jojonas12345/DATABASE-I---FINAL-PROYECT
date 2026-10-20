"""
Dependencias transversales de FastAPI:
  - get_current_user: extrae y valida el JWT, devuelve {id_usuario, rol}.
  - require_roles: fabrica una dependencia que exige uno de los roles dados.

Roles del sistema (segun enunciado):
    Administrador, Recepcion, Tecnico, Bodega, Caja

Uso:  Depends(require_roles("Administrador", "Caja"))
"""
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer

from app.core.security import decode_access_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")


def get_current_user(token: str = Depends(oauth2_scheme)) -> dict:
    cred_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Credenciales invalidas o sesion expirada",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = decode_access_token(token)
    except jwt.PyJWTError:
        raise cred_error

    sub = payload.get("sub")
    rol = payload.get("rol")
    if sub is None or rol is None:
        raise cred_error

    try:
        id_usuario = int(sub)
    except (TypeError, ValueError):
        raise cred_error

    return {"id_usuario": id_usuario, "rol": rol}


def require_roles(*roles_permitidos: str):
    """Devuelve una dependencia que exige que el rol del usuario este en la lista."""
    def checker(user: dict = Depends(get_current_user)) -> dict:
        if user["rol"] not in roles_permitidos:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tiene permiso para esta operacion",
            )
        return user
    return checker
