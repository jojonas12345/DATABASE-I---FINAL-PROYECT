from datetime import date
from pydantic import BaseModel, Field


class OrdenCreate(BaseModel):
    id_cliente: int
    id_equipo: int
    problema: str = Field(..., max_length=500)
    prioridad: str = Field("MEDIA", examples=["ALTA", "MEDIA", "BAJA"])
    fecha_estimada: date | None = None


class OrdenCreada(BaseModel):
    id_orden: int


class CambioEstado(BaseModel):
    estado_nuevo: str = Field(..., examples=["DIAGNOSTICO", "REPARACION", "LISTO"])
    observacion: str | None = Field(None, max_length=300)
