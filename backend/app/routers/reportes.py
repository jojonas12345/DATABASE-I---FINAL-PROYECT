"""Los 12 reportes obligatorios, ejecutados con SQL real desde la base (seccion 5)."""
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.core.errors import traducir_error_sp
from app.db.database import get_db
from app.dependencies import get_current_user
from app.repositories import reportes_repo

router = APIRouter(prefix="/reportes", tags=["Reportes"])


@router.get("")
def listar_reportes(_=Depends(get_current_user)):
    """Catalogo de reportes con sus filtros disponibles."""
    return reportes_repo.catalogo()


@router.get("/{numero}")
def ejecutar_reporte(numero: int, request: Request, db: Session = Depends(get_db),
                     _=Depends(get_current_user)):
    """Ejecuta el reporte; los filtros llegan como query params (?desde=2025-03-01&id_bodega=2)."""
    if numero not in reportes_repo.REPORTES:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Reporte no encontrado")
    try:
        return reportes_repo.ejecutar(db, numero, dict(request.query_params))
    except ValueError:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Algun filtro tiene un formato invalido")
    except Exception as exc:
        raise traducir_error_sp(exc)
