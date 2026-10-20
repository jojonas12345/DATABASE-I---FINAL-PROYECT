from pydantic import BaseModel, Field

ESTADOS_EQUIPO = ("OPERATIVO", "DANADO", "EN_REPARACION", "DESCONTINUADO")


class EquipoCreate(BaseModel):
    id_cliente: int
    id_tipo_equipo: int
    id_marca: int
    serie: str = Field(..., min_length=1, max_length=50)
    modelo: str | None = Field(None, max_length=50)
    descripcion: str | None = Field(None, max_length=255)


class EquipoUpdate(BaseModel):
    id_tipo_equipo: int
    id_marca: int
    serie: str = Field(..., min_length=1, max_length=50)
    modelo: str | None = Field(None, max_length=50)
    descripcion: str | None = Field(None, max_length=255)
    estado: str = Field("OPERATIVO", examples=list(ESTADOS_EQUIPO))


class EquipoOut(BaseModel):
    id_equipo: int
    serie: str
    modelo: str | None
    tipo: str
    marca: str
