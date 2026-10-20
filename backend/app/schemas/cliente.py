"""Schemas del modulo Clientes, alineados al esquema real (individual vs empresarial)."""
from pydantic import BaseModel, Field, model_validator


class ClienteCreate(BaseModel):
    tipo: str = Field(..., examples=["INDIVIDUAL", "EMPRESARIAL"])
    nombres: str | None = Field(None, max_length=100)
    apellidos: str | None = Field(None, max_length=100)
    razon_social: str | None = Field(None, max_length=150)
    nit: str = Field(..., max_length=20)
    telefono: str | None = Field(None, max_length=20)
    email: str | None = Field(None, max_length=100)
    direccion: str | None = Field(None, max_length=200)

    @model_validator(mode="after")
    def validar_identidad(self):
        # Mismo criterio que el CHECK CK_Cliente_identidad de la tabla.
        if self.tipo == "INDIVIDUAL":
            if not (self.nombres and self.apellidos) or self.razon_social:
                raise ValueError("Un cliente INDIVIDUAL requiere nombres y apellidos, sin razon_social")
        elif self.tipo == "EMPRESARIAL":
            if not self.razon_social or self.nombres or self.apellidos:
                raise ValueError("Un cliente EMPRESARIAL requiere razon_social, sin nombres/apellidos")
        else:
            raise ValueError("tipo debe ser INDIVIDUAL o EMPRESARIAL")
        return self


class ClienteOut(BaseModel):
    id_cliente: int
    tipo: str
    nombres: str | None
    apellidos: str | None
    razon_social: str | None
    nit: str
    telefono: str | None
    email: str | None
    direccion: str | None
    activo: bool
