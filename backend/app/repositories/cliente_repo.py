"""
Repository de Clientes. Mantenimiento de catalogo con consultas parametrizadas.
La integridad (identidad individual/empresarial, NIT unico) la garantizan los
CHECK/UNIQUE de la tabla; el schema Pydantic valida antes para dar mejor mensaje.
"""
from sqlalchemy import text
from sqlalchemy.orm import Session

_COLS = "id_cliente, tipo, nombres, apellidos, razon_social, nit, telefono, email, direccion, activo"


def listar(db: Session, incluir_inactivos: bool = False) -> list[dict]:
    sql = f"SELECT {_COLS} FROM Cliente WHERE (:todos = 1 OR activo = 1) ORDER BY id_cliente DESC;"
    return [dict(r) for r in db.execute(text(sql), {"todos": 1 if incluir_inactivos else 0}).mappings().all()]


def obtener(db: Session, id_cliente: int) -> dict | None:
    row = db.execute(text(f"SELECT {_COLS} FROM Cliente WHERE id_cliente = :id;"),
                     {"id": id_cliente}).mappings().first()
    return dict(row) if row else None


def nit_existe(db: Session, nit: str, excluir_id: int | None = None) -> bool:
    return db.execute(text("SELECT 1 FROM Cliente WHERE nit = :nit AND (:ex IS NULL OR id_cliente <> :ex);"),
                      {"nit": nit, "ex": excluir_id}).first() is not None


def crear(db: Session, data: dict) -> int:
    nuevo = db.execute(text("""
        INSERT INTO Cliente (tipo, nombres, apellidos, razon_social, nit, telefono, email, direccion)
        OUTPUT INSERTED.id_cliente
        VALUES (:tipo, :nombres, :apellidos, :razon_social, :nit, :telefono, :email, :direccion);"""),
        data).scalar_one()
    db.commit()
    return nuevo


def actualizar(db: Session, id_cliente: int, data: dict) -> None:
    db.execute(text("""
        UPDATE Cliente
        SET tipo = :tipo, nombres = :nombres, apellidos = :apellidos, razon_social = :razon_social,
            nit = :nit, telefono = :telefono, email = :email, direccion = :direccion
        WHERE id_cliente = :id_cliente;"""), {**data, "id_cliente": id_cliente})
    db.commit()


def cambiar_estado(db: Session, id_cliente: int, activo: bool) -> None:
    db.execute(text("UPDATE Cliente SET activo = :a WHERE id_cliente = :id;"),
               {"a": 1 if activo else 0, "id": id_cliente})
    db.commit()
