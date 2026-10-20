from pydantic import BaseModel, Field


class FacturaGenerar(BaseModel):
    id_orden: int


class FacturaCreada(BaseModel):
    id_factura: int


class PagoCreate(BaseModel):
    id_factura: int
    id_metodo: int
    monto: float = Field(..., gt=0)
    referencia: str | None = Field(None, max_length=50)


class PagoCreado(BaseModel):
    id_pago: int
