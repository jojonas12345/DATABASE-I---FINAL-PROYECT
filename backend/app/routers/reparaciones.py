from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.dependencies import require_roles
from app.schemas.reparacion import ConsumoRepuestoCreate, ConsumoRegistrado
from app.services import reparacion_service

router = APIRouter(prefix="/reparaciones", tags=["Reparaciones"])


@router.post("/{id_reparacion}/repuestos", response_model=ConsumoRegistrado, status_code=201)
def consumir_repuesto(
    id_reparacion: int,
    data: ConsumoRepuestoCreate,
    db: Session = Depends(get_db),
    user: dict = Depends(require_roles("Administrador", "Tecnico")),
):
    """Consume un repuesto en la reparacion (SP usp_ConsumirRepuesto)."""
    reparacion_service.consumir_repuesto(db, id_reparacion, data, user["id_usuario"])
    return ConsumoRegistrado()
