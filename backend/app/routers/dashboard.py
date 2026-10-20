from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.dependencies import get_current_user
from app.repositories import dashboard_repo

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("")
def dashboard(db: Session = Depends(get_db), _=Depends(get_current_user)):
    """Indicadores calculados en la BD + actividad reciente (seccion 6.3)."""
    return {
        "indicadores": dashboard_repo.indicadores(db),
        "actividad": dashboard_repo.actividad(db),
    }
