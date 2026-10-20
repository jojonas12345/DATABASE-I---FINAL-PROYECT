"""Repository de Inventario y lecturas de bodega (consultas parametrizadas)."""
from sqlalchemy import text
from sqlalchemy.orm import Session


def _rows(db, sql, params=None):
    return [dict(r) for r in db.execute(text(sql), params or {}).mappings().all()]


def existencias(db: Session) -> list[dict]:
    return _rows(db, """
        SELECT r.id_repuesto, r.codigo, r.nombre AS repuesto, cat.nombre AS categoria,
               b.id_bodega, b.nombre AS bodega, i.existencia, i.stock_minimo
        FROM Inventario i
        INNER JOIN Repuesto r ON r.id_repuesto = i.id_repuesto
        INNER JOIN CategoriaRepuesto cat ON cat.id_categoria = r.id_categoria
        INNER JOIN Bodega b ON b.id_bodega = i.id_bodega
        WHERE i.activo = 1
        ORDER BY r.nombre, b.nombre;""")


def movimientos(db: Session) -> list[dict]:
    return _rows(db, """
        SELECT TOP 200 m.id_movimiento, m.fecha, r.nombre AS repuesto, b.nombre AS bodega,
               m.tipo, m.cantidad, m.doc_tipo, m.doc_referencia, m.existencia_resultante,
               u.nombres + ' ' + u.apellidos AS usuario
        FROM MovimientoInventario m
        INNER JOIN Repuesto r ON r.id_repuesto = m.id_repuesto
        INNER JOIN Bodega   b ON b.id_bodega = m.id_bodega
        INNER JOIN Usuario  u ON u.id_usuario = m.id_usuario
        ORDER BY m.fecha DESC, m.id_movimiento DESC;""")


def compras(db: Session) -> list[dict]:
    return _rows(db, """
        SELECT c.id_compra, c.numero, c.fecha, c.estado, c.total,
               p.nombre AS proveedor, b.nombre AS bodega,
               (SELECT COUNT(*) FROM DetalleCompra d WHERE d.id_compra = c.id_compra) AS renglones
        FROM Compra c
        INNER JOIN Proveedor p ON p.id_proveedor = c.id_proveedor
        INNER JOIN Bodega    b ON b.id_bodega = c.id_bodega
        WHERE c.activo = 1
        ORDER BY c.fecha DESC;""")


def compra_detalle(db: Session, id_compra: int) -> dict | None:
    cab = db.execute(text("""
        SELECT c.id_compra, c.numero, c.fecha, c.estado, c.total,
               p.nombre AS proveedor, p.nit AS nit_proveedor, b.nombre AS bodega,
               u.nombres + ' ' + u.apellidos AS registrada_por
        FROM Compra c
        INNER JOIN Proveedor p ON p.id_proveedor = c.id_proveedor
        INNER JOIN Bodega    b ON b.id_bodega = c.id_bodega
        INNER JOIN Usuario   u ON u.id_usuario = c.id_usuario
        WHERE c.id_compra = :id;"""), {"id": id_compra}).mappings().first()
    if not cab:
        return None
    detalle = dict(cab)
    # costo_historico: lo pagado en ESTA compra; costo_actual: referencia vigente del catalogo
    detalle["lineas"] = _rows(db, """
        SELECT r.codigo, r.nombre AS repuesto, d.cantidad, d.costo_historico,
               d.cantidad * d.costo_historico AS subtotal, r.precio_compra_ref AS costo_actual
        FROM DetalleCompra d
        INNER JOIN Repuesto r ON r.id_repuesto = d.id_repuesto
        WHERE d.id_compra = :id AND d.activo = 1
        ORDER BY r.nombre;""", {"id": id_compra})
    return detalle
