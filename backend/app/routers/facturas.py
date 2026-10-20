from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.dependencies import require_roles, get_current_user
from app.repositories import factura_repo
from app.schemas.factura import FacturaGenerar, FacturaCreada, PagoCreate, PagoCreado
from app.services import factura_service

router = APIRouter(prefix="/facturas", tags=["Facturacion y pagos"])


@router.get("")
def listar_con_saldo(db: Session = Depends(get_db), _=Depends(get_current_user)):
    """Facturas con su saldo (vista vw_FacturasConSaldo)."""
    return factura_service.listar_con_saldo(db)


@router.get("/{id_factura}")
def detalle(id_factura: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    """Factura con sus renglones (precios historicos) y los pagos recibidos."""
    det = factura_repo.detalle(db, id_factura)
    if not det:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Factura no encontrada")
    return det


@router.post("", response_model=FacturaCreada, status_code=201)
def generar_factura(data: FacturaGenerar, db: Session = Depends(get_db),
                    user: dict = Depends(require_roles("Administrador", "Caja"))):
    """Genera la factura de una orden LISTA (SP usp_GenerarFactura)."""
    return FacturaCreada(id_factura=factura_service.generar_factura(db, data, user["id_usuario"]))


@router.post("/pagos", response_model=PagoCreado, status_code=201)
def registrar_pago(data: PagoCreate, db: Session = Depends(get_db),
                   _=Depends(require_roles("Administrador", "Caja"))):
    """Registra un pago sin exceder el saldo (SP usp_RegistrarPago)."""
    return PagoCreado(id_pago=factura_service.registrar_pago(db, data))
