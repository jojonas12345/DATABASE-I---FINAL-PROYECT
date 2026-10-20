"""Repository de Equipos. Mantenimiento con consultas parametrizadas."""
from sqlalchemy import text
from sqlalchemy.orm import Session


def serie_existe(db: Session, serie: str, excluir_id: int | None = None) -> bool:
    return db.execute(text("SELECT 1 FROM Equipo WHERE serie = :s AND (:ex IS NULL OR id_equipo <> :ex);"),
                      {"s": serie, "ex": excluir_id}).first() is not None


def crear(db: Session, data: dict) -> int:
    nuevo = db.execute(text("""
        INSERT INTO Equipo (id_cliente, id_tipo_equipo, id_marca, modelo, serie, descripcion)
        OUTPUT INSERTED.id_equipo
        VALUES (:id_cliente, :id_tipo_equipo, :id_marca, :modelo, :serie, :descripcion);"""), data).scalar_one()
    db.commit()
    return nuevo


def actualizar(db: Session, id_equipo: int, data: dict) -> None:
    db.execute(text("""
        UPDATE Equipo
        SET id_tipo_equipo = :id_tipo_equipo, id_marca = :id_marca, modelo = :modelo,
            serie = :serie, descripcion = :descripcion, estado = :estado
        WHERE id_equipo = :id_equipo;"""), {**data, "id_equipo": id_equipo})
    db.commit()


def cambiar_estado(db: Session, id_equipo: int, activo: bool) -> None:
    db.execute(text("UPDATE Equipo SET activo = :a WHERE id_equipo = :id;"),
               {"a": 1 if activo else 0, "id": id_equipo})
    db.commit()


def obtener(db: Session, id_equipo: int) -> dict | None:
    row = db.execute(text("""
        SELECT e.id_equipo, e.serie, e.modelo, te.nombre AS tipo, me.nombre AS marca
        FROM Equipo e
        INNER JOIN TipoEquipo te ON te.id_tipo_equipo = e.id_tipo_equipo
        INNER JOIN MarcaEquipo me ON me.id_marca = e.id_marca
        WHERE e.id_equipo = :id;"""), {"id": id_equipo}).mappings().first()
    return dict(row) if row else None
