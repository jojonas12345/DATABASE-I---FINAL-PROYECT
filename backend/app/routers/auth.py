"""
Router de autenticacion. /auth/login recibe nombre de usuario y contrasena
(form estandar OAuth2, para que Swagger pueda autenticar con "Authorize")
y devuelve el JWT.
"""
from fastapi import APIRouter, Depends
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.dependencies import get_current_user
from app.schemas.auth import Token
from app.services import auth_service

router = APIRouter(prefix="/auth", tags=["Autenticacion"])


@router.post("/login", response_model=Token)
def login(
    form: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    # form.username lleva el nombre_usuario
    return auth_service.autenticar(db, form.username, form.password)


@router.get("/me")
def quien_soy(user: dict = Depends(get_current_user)):
    """Devuelve el usuario del token (id_usuario y rol)."""
    return user
