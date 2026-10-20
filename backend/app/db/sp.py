"""
Ayudantes para invocar procedimientos almacenados desde los repositories.

Por que un helper:
  - Todos los SP usan parametros NOMBRADOS (@x = :x), asi que el orden no
    importa y nada se concatena (consulta parametrizada -> sin inyeccion SQL).
  - Para los SP con parametro OUTPUT (id generado) se arma un pequeno lote
    T-SQL que declara la variable de salida, ejecuta el SP y la devuelve con
    un SELECT, que es la forma portable con pyodbc.
  - El SP maneja su propia transaccion (BEGIN TRAN/COMMIT/ROLLBACK). Aqui se
    confirma a nivel de la sesion (commit) o se revierte (rollback) y se
    deja subir el THROW para que el service lo traduzca a HTTP.
"""
from sqlalchemy import text
from sqlalchemy.orm import Session


def _binds(params: dict) -> str:
    """Convierte {'id_bodega': 3} en '@id_bodega = :id_bodega, ...'."""
    return ", ".join(f"@{k} = :{k}" for k in params)


def exec_sp(db: Session, sp_name: str, params: dict) -> None:
    """Ejecuta un SP sin valor de retorno."""
    sql = text(f"EXEC {sp_name} {_binds(params)};")
    try:
        db.execute(sql, params)
        db.commit()
    except Exception:
        db.rollback()
        raise


def exec_sp_output(db: Session, sp_name: str, params: dict, output_name: str) -> int:
    """
    Ejecuta un SP que tiene un parametro OUTPUT entero (id generado) y lo
    devuelve. 'params' son solo los parametros de entrada.
    """
    binds = _binds(params)
    sep = ", " if params else ""
    batch = text(
        f"DECLARE @__out INT; "
        f"EXEC {sp_name} {binds}{sep}@{output_name} = @__out OUTPUT; "
        f"SELECT @__out AS id;"
    )
    try:
        result = db.execute(batch, params).scalar()
        db.commit()
        return int(result)
    except Exception:
        db.rollback()
        raise
