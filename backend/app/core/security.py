"""
Seguridad: hash de contrasenas (bcrypt) y emision/validacion de JWT.

Requisito del proyecto (6.4): las contrasenas se guardan con hash, nunca
en texto plano. Nunca se almacena ni se compara la contrasena en claro.
"""
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt

from app.core.config import settings

# Se usa la libreria bcrypt directamente (sin passlib) para evitar el conflicto
# de versiones passlib<->bcrypt. bcrypt genera y embebe el salt en el hash.


def hash_password(plain: str) -> str:
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt(rounds=12)).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))
    except (ValueError, TypeError):
        return False


def create_access_token(subject: str, rol: str) -> str:
    """Genera un JWT con el usuario y su rol. El rol viaja en el token
    para que el backend pueda restringir endpoints sin volver a la BD."""
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.JWT_EXPIRE_MINUTES)
    payload = {"sub": subject, "rol": rol, "exp": expire}
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def decode_access_token(token: str) -> dict:
    """Devuelve el payload o lanza jwt.PyJWTError si es invalido/expirado."""
    return jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
