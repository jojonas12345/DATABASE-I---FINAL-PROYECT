"""
Repository de Administracion: usuarios y mantenimiento de catalogos.

Mantenimiento generico de catalogos (listar / crear / editar / activar-desactivar):
los nombres de tabla y columna salen de CATALOGOS (texto fijo del codigo, nunca
de la entrada del usuario); los VALORES siempre van como parametros.
Eliminar = desactivar (columna 'activo'): no se borra informacion (R14).
"""
from sqlalchemy import text
from sqlalchemy.orm import Session

# entidad -> (tabla, columna id, columnas editables)
CATALOGOS = {
    "proveedores":  ("Proveedor",         "id_proveedor",   ["nombre", "nit", "telefono", "email", "direccion"]),
    "repuestos":    ("Repuesto",          "id_repuesto",    ["id_categoria", "codigo", "nombre", "descripcion",
                                                             "precio_compra_ref", "precio_venta"]),
    "categorias":   ("CategoriaRepuesto", "id_categoria",   ["nombre"]),
    "bodegas":      ("Bodega",            "id_bodega",      ["nombre", "ubicacion"]),
    "metodos-pago": ("MetodoPago",        "id_metodo",      ["nombre"]),
    "marcas":       ("MarcaEquipo",       "id_marca",       ["nombre"]),
    "tipos-equipo": ("TipoEquipo",        "id_tipo_equipo", ["nombre"]),
}


def _rows(db, sql, params=None):
    return [dict(r) for r in db.execute(text(sql), params or {}).mappings().all()]


def _limpiar(campos: list[str], data: dict) -> dict:
    """Solo deja columnas permitidas; textos vacios -> NULL."""
    limpio = {}
    for c in campos:
        if c in data:
            v = data[c]
            limpio[c] = None if (isinstance(v, str) and v.strip() == "") else v
    return limpio


# ---------------- Catalogos ----------------
def listar_catalogo(db: Session, entidad: str) -> list[dict]:
    tabla, col_id, campos = CATALOGOS[entidad]
    return _rows(db, f"SELECT {col_id} AS id, {', '.join(campos)}, activo FROM {tabla} ORDER BY {col_id};")


def crear_catalogo(db: Session, entidad: str, data: dict) -> int:
    tabla, col_id, campos = CATALOGOS[entidad]
    valores = _limpiar(campos, data)
    if not valores:
        raise ValueError("No se recibieron datos")
    cols = ", ".join(valores)
    params = ", ".join(f":{c}" for c in valores)
    try:
        nuevo = db.execute(text(f"INSERT INTO {tabla} ({cols}) OUTPUT INSERTED.{col_id} VALUES ({params});"),
                           valores).scalar_one()
        db.commit()
        return nuevo
    except Exception:
        db.rollback()
        raise


def actualizar_catalogo(db: Session, entidad: str, id_: int, data: dict) -> None:
    tabla, col_id, campos = CATALOGOS[entidad]
    valores = _limpiar(campos, data)
    if not valores:
        raise ValueError("No se recibieron datos")
    asignaciones = ", ".join(f"{c} = :{c}" for c in valores)
    valores["__id"] = id_
    try:
        db.execute(text(f"UPDATE {tabla} SET {asignaciones} WHERE {col_id} = :__id;"), valores)
        db.commit()
    except Exception:
        db.rollback()
        raise


def estado_catalogo(db: Session, entidad: str, id_: int, activo: bool) -> None:
    tabla, col_id, _ = CATALOGOS[entidad]
    db.execute(text(f"UPDATE {tabla} SET activo = :a WHERE {col_id} = :id;"),
               {"a": 1 if activo else 0, "id": id_})
    db.commit()


# ---------------- Usuarios ----------------
def listar_usuarios(db: Session) -> list[dict]:
    return _rows(db, """
        SELECT u.id_usuario, u.nombre_usuario, u.nombres, u.apellidos, u.activo,
               r.id_rol, r.nombre AS rol
        FROM Usuario u INNER JOIN Rol r ON r.id_rol = u.id_rol
        ORDER BY u.id_usuario;""")


def usuario_existe(db: Session, nombre_usuario: str) -> bool:
    return db.execute(text("SELECT 1 FROM Usuario WHERE nombre_usuario = :u;"),
                      {"u": nombre_usuario}).first() is not None


def crear_usuario(db: Session, id_rol: int, nombre_usuario: str, password_hash: str,
                  nombres: str, apellidos: str) -> int:
    nuevo = db.execute(text("""
        INSERT INTO Usuario (id_rol, nombre_usuario, password_hash, nombres, apellidos)
        OUTPUT INSERTED.id_usuario
        VALUES (:id_rol, :u, :h, :n, :a);"""),
        {"id_rol": id_rol, "u": nombre_usuario, "h": password_hash, "n": nombres, "a": apellidos}
    ).scalar_one()
    db.commit()
    return nuevo


def actualizar_usuario(db: Session, id_usuario: int, id_rol: int, nombres: str, apellidos: str,
                       password_hash: str | None) -> None:
    sql = "UPDATE Usuario SET id_rol = :r, nombres = :n, apellidos = :a"
    params = {"r": id_rol, "n": nombres, "a": apellidos, "id": id_usuario}
    if password_hash:
        sql += ", password_hash = :h"
        params["h"] = password_hash
    db.execute(text(sql + " WHERE id_usuario = :id;"), params)
    db.commit()


def cambiar_estado_usuario(db: Session, id_usuario: int, activo: bool) -> None:
    db.execute(text("UPDATE Usuario SET activo = :a WHERE id_usuario = :id;"),
               {"a": 1 if activo else 0, "id": id_usuario})
    db.commit()


def listar_roles(db: Session) -> list[dict]:
    return _rows(db, "SELECT id_rol, nombre FROM Rol WHERE activo = 1 ORDER BY id_rol;")
