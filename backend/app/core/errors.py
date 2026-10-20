"""
Traduce los errores de SQL Server en respuestas HTTP comprensibles.

- Un THROW de un procedimiento almacenado llega como excepcion de pyodbc cuyo
  texto incluye el mensaje de negocio (p. ej. "Existencia insuficiente...").
- Una violacion de restriccion (UNIQUE, CHECK, FK) se traduce a un mensaje
  claro, conservando el nombre de la restriccion para poder explicarla.
Ambos casos responden 400 (dato o regla de negocio invalida).
"""
import re

from fastapi import HTTPException, status


def _mensaje_sql(exc: Exception) -> str:
    """Extrae el texto legible del error de SQL Server."""
    texto = str(exc)
    m = re.search(r"\[SQL Server\]([^\[\]]+?)\s*\(\d+\)\s*\(SQL\w+\)", texto)
    if m:
        msg = m.group(1).strip()
    else:
        partes = re.findall(r"\[SQL Server\]([^\[\]]+)", texto)
        msg = partes[-1].strip() if partes else ""
    if not msg:
        return "Error al ejecutar la operacion en la base de datos."

    # Violaciones de restricciones -> mensaje claro + nombre de la restriccion
    nombre = re.search(r"constraint ['\"]([^'\"]+)['\"]", msg)
    restriccion = f" ({nombre.group(1)})" if nombre else ""
    if "UNIQUE KEY" in msg or "duplicate key" in msg:
        return f"Ya existe un registro con ese valor; el dato debe ser unico{restriccion}."
    if "CHECK constraint" in msg:
        return f"El dato no cumple una regla de validacion de la base de datos{restriccion}."
    if "FOREIGN KEY" in msg:
        return f"El registro hace referencia a otro que no existe o esta en uso{restriccion}."
    if "Cannot insert the value NULL" in msg:
        col = re.search(r"column '([^']+)'", msg)
        return f"Falta un dato obligatorio{(': ' + col.group(1)) if col else ''}."
    return msg


def traducir_error_sp(exc: Exception) -> HTTPException:
    """Devuelve una HTTPException 400 con el mensaje de negocio o de restriccion."""
    if isinstance(exc, HTTPException):
        return exc
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=_mensaje_sql(exc))
