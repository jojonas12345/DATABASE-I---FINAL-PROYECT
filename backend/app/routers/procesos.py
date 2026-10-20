"""
Procesos del flujo de una orden (no son CRUD genericos, seccion 6.2):
diagnostico, inicio/cierre de reparacion y entrega. Cada uno invoca su
procedimiento almacenado; el consumo de repuestos vive en el router 'reparaciones'.
"""
from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.errors import traducir_error_sp
from app.db.database import get_db
from app.dependencies import require_roles
from app.repositories import proceso_repo, orden_repo

router = APIRouter(tags=["Flujo de orden"])


class DiagnosticoIn(BaseModel):
    descripcion: str = Field(..., min_length=1, max_length=500)
    costo_mano_obra: float = Field(0, ge=0)


class ReparacionIn(BaseModel):
    descripcion: str | None = Field(None, max_length=500)
    costo_mano_obra: float = Field(0, ge=0)


class EntregaIn(BaseModel):
    recibe: str = Field(..., min_length=1, max_length=100)
    observaciones: str | None = Field(None, max_length=300)


def _ejecutar(fn, *args):
    try:
        return fn(*args)
    except Exception as exc:
        raise traducir_error_sp(exc)


@router.post("/ordenes/{id_orden}/diagnostico", status_code=201)
def diagnosticar(id_orden: int, data: DiagnosticoIn, db: Session = Depends(get_db),
                 user: dict = Depends(require_roles("Administrador", "Tecnico"))):
    """Registra diagnostico (SP usp_RegistrarDiagnostico)."""
    nuevo = _ejecutar(proceso_repo.registrar_diagnostico, db, id_orden, user["id_usuario"],
                      data.descripcion, data.costo_mano_obra)
    return {"id_diagnostico": nuevo}


@router.post("/ordenes/{id_orden}/reparacion", status_code=201)
def iniciar_reparacion(id_orden: int, data: ReparacionIn, db: Session = Depends(get_db),
                       user: dict = Depends(require_roles("Administrador", "Tecnico"))):
    """Inicia reparacion (SP usp_IniciarReparacion; exige diagnostico previo - R04)."""
    nuevo = _ejecutar(proceso_repo.iniciar_reparacion, db, id_orden, user["id_usuario"],
                      data.descripcion, data.costo_mano_obra)
    return {"id_reparacion": nuevo}


@router.put("/reparaciones/{id_reparacion}/finalizar")
def finalizar_reparacion(id_reparacion: int, db: Session = Depends(get_db),
                         user: dict = Depends(require_roles("Administrador", "Tecnico"))):
    """Cierra la reparacion (SP usp_FinalizarReparacion)."""
    _ejecutar(proceso_repo.finalizar_reparacion, db, id_reparacion, user["id_usuario"])
    return {"mensaje": "Reparacion finalizada"}


@router.get("/reparaciones/{id_reparacion}/repuestos")
def repuestos_de_reparacion(id_reparacion: int, db: Session = Depends(get_db),
                            _=Depends(require_roles("Administrador", "Tecnico", "Recepcion", "Caja"))):
    return orden_repo.repuestos_de_reparacion(db, id_reparacion)


@router.post("/ordenes/{id_orden}/entrega", status_code=201)
def entregar(id_orden: int, data: EntregaIn, db: Session = Depends(get_db),
             user: dict = Depends(require_roles("Administrador", "Recepcion"))):
    """Entrega y cierra la orden (SP usp_EntregarOrden; exige factura saldada)."""
    nuevo = _ejecutar(proceso_repo.entregar_orden, db, id_orden, user["id_usuario"],
                      data.recibe, data.observaciones)
    return {"id_entrega": nuevo}
