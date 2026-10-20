from pydantic import BaseModel, Field


class CompraRepuestoCreate(BaseModel):
    """Compra de UN repuesto, recibida al instante (usp_RegistrarCompraRepuesto)."""
    id_proveedor: int
    id_bodega: int
    id_repuesto: int
    cantidad: int = Field(..., gt=0)
    costo_unitario: float = Field(..., ge=0)


class LineaCompra(BaseModel):
    id_repuesto: int
    cantidad: int = Field(..., gt=0)
    costo: float = Field(..., ge=0)


class CompraCreate(BaseModel):
    """Compra con encabezado + varios renglones de detalle (usp_RegistrarCompra)."""
    id_proveedor: int
    id_bodega: int
    detalle: list[LineaCompra] = Field(..., min_length=1)
    recibir: bool = False   # True = registrar y recibir en inventario de una vez


class CompraCreada(BaseModel):
    id_compra: int
    mensaje: str = "Compra registrada"
