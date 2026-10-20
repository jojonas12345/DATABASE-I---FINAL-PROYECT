"""
Dashboard (seccion 6.3): indicadores calculados en la base de datos.
Usa las vistas del proyecto, de modo que las 4 tienen uso real en la app:
  vw_OrdenesActivas, vw_FacturasConSaldo, vw_InventarioBajoStock, vw_HistorialReparaciones.
"""
from sqlalchemy import text
from sqlalchemy.orm import Session


def _rows(db, sql):
    return [dict(r) for r in db.execute(text(sql)).mappings().all()]


def indicadores(db: Session) -> dict:
    fila = db.execute(text("""
        SELECT
            (SELECT COUNT(*) FROM vw_OrdenesActivas)                                         AS ordenes_abiertas,
            (SELECT COUNT(*) FROM vw_OrdenesActivas WHERE estado = 'RECIBIDO')               AS ordenes_recibidas,
            (SELECT COUNT(*) FROM vw_OrdenesActivas WHERE estado = 'DIAGNOSTICO')            AS ordenes_en_diagnostico,
            (SELECT COUNT(*) FROM vw_OrdenesActivas WHERE estado = 'ESPERANDO_AUTORIZACION') AS ordenes_esperando_autorizacion,
            (SELECT COUNT(*) FROM vw_OrdenesActivas WHERE estado = 'REPARACION')             AS ordenes_en_reparacion,
            (SELECT COUNT(*) FROM vw_OrdenesActivas WHERE estado = 'LISTO')                  AS ordenes_listas_para_entregar,
            (SELECT COUNT(*) FROM vw_FacturasConSaldo WHERE estado = 'EMITIDA' AND saldo > 0) AS facturas_con_saldo,
            (SELECT ISNULL(SUM(saldo), 0) FROM vw_FacturasConSaldo WHERE estado = 'EMITIDA')  AS saldo_por_cobrar,
            (SELECT COUNT(*) FROM vw_InventarioBajoStock)                                     AS repuestos_bajo_minimo,
            (SELECT COUNT(*) FROM Compra WHERE activo = 1 AND estado = 'PENDIENTE')           AS compras_pendientes;
    """)).mappings().first()
    return dict(fila)


def actividad(db: Session) -> dict:
    return {
        "movimientos": _rows(db, """
            SELECT TOP 8 m.fecha, m.tipo, r.nombre AS repuesto, b.nombre AS bodega,
                   m.cantidad, m.doc_tipo, m.existencia_resultante,
                   u.nombres + ' ' + u.apellidos AS usuario
            FROM MovimientoInventario m
            INNER JOIN Repuesto r ON r.id_repuesto = m.id_repuesto
            INNER JOIN Bodega   b ON b.id_bodega = m.id_bodega
            INNER JOIN Usuario  u ON u.id_usuario = m.id_usuario
            ORDER BY m.fecha DESC, m.id_movimiento DESC;"""),
        "cambios_estado": _rows(db, """
            SELECT TOP 8 h.fecha, o.numero AS numero_orden, h.estado_anterior, h.estado_nuevo,
                   u.nombres + ' ' + u.apellidos AS usuario
            FROM HistorialEstadoOrden h
            INNER JOIN OrdenServicio o ON o.id_orden = h.id_orden
            INNER JOIN Usuario       u ON u.id_usuario = h.id_usuario
            ORDER BY h.fecha DESC, h.id_historial DESC;"""),
        "reparaciones": _rows(db, """
            SELECT TOP 5 numero_orden, estado_reparacion, fecha_inicio, tecnico, marca, tipo_equipo, total_orden
            FROM vw_HistorialReparaciones
            ORDER BY fecha_inicio DESC;"""),
        "bajo_stock": _rows(db, """
            SELECT TOP 5 codigo, repuesto, bodega, existencia, stock_minimo
            FROM vw_InventarioBajoStock
            ORDER BY existencia, repuesto;"""),
    }
