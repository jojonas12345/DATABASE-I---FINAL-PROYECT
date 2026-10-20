"""Endpoints de solo lectura: catalogos activos para selects y consultas."""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.dependencies import get_current_user
from app.repositories import catalogo_repo

router = APIRouter(prefix="/catalogos", tags=["Catalogos"])


@router.get("/repuestos")
def repuestos(db: Session = Depends(get_db), _=Depends(get_current_user)):
    return catalogo_repo.repuestos(db)


@router.get("/proveedores")
def proveedores(db: Session = Depends(get_db), _=Depends(get_current_user)):
    return catalogo_repo.proveedores(db)


@router.get("/bodegas")
def bodegas(db: Session = Depends(get_db), _=Depends(get_current_user)):
    return catalogo_repo.bodegas(db)


@router.get("/metodos-pago")
def metodos_pago(db: Session = Depends(get_db), _=Depends(get_current_user)):
    return catalogo_repo.metodos_pago(db)


@router.get("/marcas")
def marcas(db: Session = Depends(get_db), _=Depends(get_current_user)):
    return catalogo_repo.marcas(db)


@router.get("/tipos-equipo")
def tipos_equipo(db: Session = Depends(get_db), _=Depends(get_current_user)):
    return catalogo_repo.tipos_equipo(db)


@router.get("/categorias")
def categorias(db: Session = Depends(get_db), _=Depends(get_current_user)):
    return catalogo_repo.categorias(db)


@router.get("/tecnicos")
def tecnicos(db: Session = Depends(get_db), _=Depends(get_current_user)):
    return catalogo_repo.tecnicos(db)


@router.get("/clientes/{id_cliente}/equipos")
def equipos_de_cliente(id_cliente: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    return catalogo_repo.equipos_de_cliente(db, id_cliente)
