from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.dependencies import require_roles, get_current_user
from app.schemas.orden import OrdenCreate, OrdenCreada, CambioEstado
from app.services import orden_service

router = APIRouter(prefix="/ordenes", tags=["Ordenes de servicio"])


@router.get("")
def listar(estado: str | None = None, db: Session = Depends(get_db), _=Depends(get_current_user)):
    """Lista ordenes; sin filtro = todas, o filtra por estado (?estado=REPARACION)."""
    return orden_service.listar_todas(db, estado)


@router.get("/activas")
def listar_activas(db: Session = Depends(get_db), _=Depends(get_current_user)):
    """Ordenes en taller (vista vw_OrdenesActivas)."""
    return orden_service.listar_activas(db)


@router.get("/{id_orden}")
def detalle(id_orden: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    """Detalle completo de la orden (cliente, equipo, diagnosticos, reparaciones, factura, entrega)."""
    return orden_service.obtener_detalle(db, id_orden)


@router.post("", response_model=OrdenCreada, status_code=201)
def crear_orden(
    data: OrdenCreate,
    db: Session = Depends(get_db),
    user: dict = Depends(require_roles("Administrador", "Recepcion")),
):
    """Crea una orden de servicio (SP usp_CrearOrdenServicio)."""
    id_orden = orden_service.crear_orden(db, data, user["id_usuario"])
    return OrdenCreada(id_orden=id_orden)


@router.put("/{id_orden}/estado")
def cambiar_estado(
    id_orden: int,
    data: CambioEstado,
    db: Session = Depends(get_db),
    user: dict = Depends(require_roles("Administrador", "Recepcion", "Tecnico")),
):
    """Cambia el estado de la orden (SP usp_CambiarEstadoOrden + trigger de auditoria)."""
    orden_service.cambiar_estado(db, id_orden, data, user["id_usuario"])
    return {"mensaje": "Estado actualizado"}
