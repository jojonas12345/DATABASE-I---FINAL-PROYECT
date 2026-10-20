from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.dependencies import require_roles
from app.repositories import inventario_repo

router = APIRouter(prefix="/inventario", tags=["Inventario"])
_ROLES = require_roles("Administrador", "Bodega")


@router.get("")
def existencias(db: Session = Depends(get_db), _=Depends(_ROLES)):
    return inventario_repo.existencias(db)


@router.get("/movimientos")
def movimientos(db: Session = Depends(get_db), _=Depends(_ROLES)):
    return inventario_repo.movimientos(db)


@router.get("/compras")
def compras(db: Session = Depends(get_db), _=Depends(_ROLES)):
    return inventario_repo.compras(db)


@router.get("/compras/{id_compra}")
def compra_detalle(id_compra: int, db: Session = Depends(get_db), _=Depends(_ROLES)):
    """Encabezado + detalle de la compra, con costo historico vs costo actual."""
    det = inventario_repo.compra_detalle(db, id_compra)
    if not det:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Compra no encontrada")
    return det
