"""
Lecturas de catalogos (solo activos) para los selects y vistas de consulta del
frontend. Consultas parametrizadas de solo lectura.
"""
from sqlalchemy import text
from sqlalchemy.orm import Session


def _rows(db: Session, sql: str, params: dict | None = None) -> list[dict]:
    return [dict(r) for r in db.execute(text(sql), params or {}).mappings().all()]


def repuestos(db: Session) -> list[dict]:
    """Catalogo de repuestos con codigo unico, precios y existencia total en bodegas."""
    return _rows(db, """
        SELECT r.id_repuesto, r.codigo, r.nombre, r.descripcion, c.nombre AS categoria,
               r.precio_compra_ref, r.precio_venta,
               ISNULL(inv.existencia_total, 0) AS existencia_total
        FROM Repuesto r
        INNER JOIN CategoriaRepuesto c ON c.id_categoria = r.id_categoria
        OUTER APPLY (SELECT SUM(i.existencia) AS existencia_total
                     FROM Inventario i WHERE i.id_repuesto = r.id_repuesto AND i.activo = 1) inv
        WHERE r.activo = 1
        ORDER BY r.nombre;""")


def proveedores(db: Session) -> list[dict]:
    return _rows(db, """
        SELECT id_proveedor, nombre, nit, telefono, email
        FROM Proveedor WHERE activo = 1 ORDER BY nombre;""")


def bodegas(db: Session) -> list[dict]:
    return _rows(db, "SELECT id_bodega, nombre, ubicacion FROM Bodega WHERE activo = 1 ORDER BY nombre;")


def metodos_pago(db: Session) -> list[dict]:
    return _rows(db, "SELECT id_metodo, nombre FROM MetodoPago WHERE activo = 1 ORDER BY nombre;")


def marcas(db: Session) -> list[dict]:
    return _rows(db, "SELECT id_marca, nombre FROM MarcaEquipo WHERE activo = 1 ORDER BY nombre;")


def tipos_equipo(db: Session) -> list[dict]:
    return _rows(db, "SELECT id_tipo_equipo, nombre FROM TipoEquipo WHERE activo = 1 ORDER BY nombre;")


def categorias(db: Session) -> list[dict]:
    return _rows(db, "SELECT id_categoria, nombre FROM CategoriaRepuesto WHERE activo = 1 ORDER BY nombre;")


def tecnicos(db: Session) -> list[dict]:
    return _rows(db, """
        SELECT u.id_usuario, u.nombres + ' ' + u.apellidos AS nombre
        FROM Usuario u INNER JOIN Rol r ON r.id_rol = u.id_rol
        WHERE u.activo = 1 AND r.nombre = 'Tecnico'
        ORDER BY u.nombres;""")


def equipos_de_cliente(db: Session, id_cliente: int) -> list[dict]:
    return _rows(db, """
        SELECT e.id_equipo, e.serie, e.modelo, e.descripcion, e.estado,
               e.id_tipo_equipo, te.nombre AS tipo, e.id_marca, me.nombre AS marca,
               (SELECT COUNT(*) FROM OrdenServicio o WHERE o.id_equipo = e.id_equipo) AS ordenes
        FROM Equipo e
        INNER JOIN TipoEquipo te ON te.id_tipo_equipo = e.id_tipo_equipo
        INNER JOIN MarcaEquipo me ON me.id_marca = e.id_marca
        WHERE e.id_cliente = :id AND e.activo = 1
        ORDER BY e.serie;""", {"id": id_cliente})
