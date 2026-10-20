from pydantic import BaseModel, Field


class ConsumoRepuestoCreate(BaseModel):
    id_repuesto: int
    id_bodega: int
    cantidad: int = Field(..., gt=0)


class ConsumoRegistrado(BaseModel):
    mensaje: str = "Repuesto consumido e inventario descontado"
