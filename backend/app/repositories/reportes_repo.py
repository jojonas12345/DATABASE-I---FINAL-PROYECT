"""
Los 12 reportes obligatorios (seccion 5 del enunciado).

Fuente unica de verdad: el script database/04_consultas_reportes.sql se genera
a partir de estas mismas consultas, asi la app y el script nunca divergen.

Condiciones tecnicas (5.1) que cumplen todas las consultas:
  - Columnas explicitas (sin SELECT *) y alias legibles; cuando una tabla
    aparece por rutas distintas (p. ej. Usuario como recepcionista y como
    tecnico) cada ruta lleva su propio alias.
  - Sin DISTINCT: los agregados se calculan con subconsultas por fila
    (APPLY) para no duplicar por relaciones 1:N.
  - Filtros opcionales parametrizados: (param IS NULL OR columna = param).
  - LEFT JOIN donde la informacion es opcional y no debe desaparecer
    (orden sin factura, factura sin pagos, movimiento de ajuste, etc.).
  - Saldos y totales salen de la base (fn_SaldoFactura, fn_TotalOrden).
"""
from sqlalchemy import text
from sqlalchemy.orm import Session

# Expresiones reutilizadas (texto SQL fijo del codigo, nunca entrada del usuario)
CLIENTE = "CASE c.tipo WHEN 'INDIVIDUAL' THEN c.nombres + ' ' + c.apellidos ELSE c.razon_social END"
EQUIPO = "te.nombre + ' ' + me.nombre"

REPORTES = {
    1: {
        "titulo": "Ordenes activas por estado, prioridad y tecnico responsable",
        "params": [("estado", "NVARCHAR(25)", None), ("prioridad", "NVARCHAR(15)", None),
                   ("id_tecnico", "INT", None)],
        "sql": f"""
SELECT
    o.numero                                   AS numero_orden,
    o.estado,
    o.prioridad,
    o.fecha_ingreso,
    {CLIENTE}                                  AS cliente,
    {EQUIPO}                                   AS equipo,
    e.serie,
    recep.nombres + ' ' + recep.apellidos      AS recepcionista,
    ISNULL(tecnico.nombres + ' ' + tecnico.apellidos, 'Sin asignar') AS tecnico_responsable,
    DATEDIFF(DAY, o.fecha_ingreso, SYSDATETIME()) AS dias_en_taller
FROM OrdenServicio o
INNER JOIN Cliente     c     ON c.id_cliente = o.id_cliente
INNER JOIN Equipo      e     ON e.id_equipo = o.id_equipo
INNER JOIN TipoEquipo  te    ON te.id_tipo_equipo = e.id_tipo_equipo
INNER JOIN MarcaEquipo me    ON me.id_marca = e.id_marca
INNER JOIN Usuario     recep ON recep.id_usuario = o.id_usuario_recepcion
OUTER APPLY (
    SELECT TOP 1 trabajo.id_tecnico
    FROM (SELECT r.id_tecnico, r.fecha_inicio AS fecha, 2 AS peso
          FROM Reparacion r WHERE r.id_orden = o.id_orden AND r.activo = 1
          UNION ALL
          SELECT d.id_tecnico, d.fecha, 1
          FROM Diagnostico d WHERE d.id_orden = o.id_orden AND d.activo = 1) trabajo
    ORDER BY trabajo.peso DESC, trabajo.fecha DESC
) responsable
LEFT JOIN Usuario tecnico ON tecnico.id_usuario = responsable.id_tecnico
WHERE o.activo = 1
  AND o.estado NOT IN ('ENTREGADO', 'CANCELADO')
  AND (:estado IS NULL OR o.estado = :estado)
  AND (:prioridad IS NULL OR o.prioridad = :prioridad)
  AND (:id_tecnico IS NULL OR responsable.id_tecnico = :id_tecnico)
ORDER BY o.estado,
         CASE o.prioridad WHEN 'ALTA' THEN 1 WHEN 'MEDIA' THEN 2 ELSE 3 END,
         o.fecha_ingreso;""",
    },
    2: {
        "titulo": "Historial completo de ordenes de un cliente",
        "params": [("id_cliente", "INT", 1)],
        "sql": f"""
SELECT
    {CLIENTE}                    AS cliente,
    c.nit,
    o.numero                     AS numero_orden,
    o.fecha_ingreso,
    {EQUIPO}                     AS equipo,
    e.serie,
    o.problema,
    o.estado,
    f.numero                     AS numero_factura,
    f.total                      AS total_facturado,
    CASE WHEN f.id_factura IS NULL THEN NULL ELSE dbo.fn_SaldoFactura(f.id_factura) END AS saldo_pendiente,
    en.fecha                     AS fecha_entrega
FROM Cliente c
INNER JOIN OrdenServicio o  ON o.id_cliente = c.id_cliente AND o.activo = 1
INNER JOIN Equipo        e  ON e.id_equipo = o.id_equipo
INNER JOIN TipoEquipo    te ON te.id_tipo_equipo = e.id_tipo_equipo
INNER JOIN MarcaEquipo   me ON me.id_marca = e.id_marca
LEFT  JOIN Factura       f  ON f.id_orden = o.id_orden AND f.activo = 1
LEFT  JOIN Entrega       en ON en.id_orden = o.id_orden
WHERE (:id_cliente IS NULL OR c.id_cliente = :id_cliente)
ORDER BY cliente, o.fecha_ingreso DESC;""",
    },
    3: {
        "titulo": "Historial tecnico de un equipo por numero de serie",
        "params": [("serie", "NVARCHAR(50)", "SN100013")],
        "sql": f"""
SELECT
    e.serie,
    {EQUIPO} + ISNULL(' ' + e.modelo, '') AS equipo,
    {CLIENTE}                    AS cliente,
    o.numero                     AS numero_orden,
    evento.tipo                  AS evento,
    evento.fecha,
    evento.detalle,
    evento.responsable,
    evento.costo
FROM Equipo e
INNER JOIN TipoEquipo    te ON te.id_tipo_equipo = e.id_tipo_equipo
INNER JOIN MarcaEquipo   me ON me.id_marca = e.id_marca
INNER JOIN Cliente       c  ON c.id_cliente = e.id_cliente
INNER JOIN OrdenServicio o  ON o.id_equipo = e.id_equipo
CROSS APPLY (
    SELECT 'INGRESO' AS tipo, o.fecha_ingreso AS fecha, o.problema AS detalle,
           recep.nombres + ' ' + recep.apellidos AS responsable, CAST(NULL AS DECIMAL(10,2)) AS costo
    FROM Usuario recep WHERE recep.id_usuario = o.id_usuario_recepcion
    UNION ALL
    SELECT 'DIAGNOSTICO', d.fecha, d.descripcion,
           tec.nombres + ' ' + tec.apellidos, d.costo_mano_obra
    FROM Diagnostico d INNER JOIN Usuario tec ON tec.id_usuario = d.id_tecnico
    WHERE d.id_orden = o.id_orden AND d.activo = 1
    UNION ALL
    SELECT 'REPARACION ' + r.estado, r.fecha_inicio, ISNULL(r.descripcion, ''),
           tec.nombres + ' ' + tec.apellidos, r.costo_mano_obra
    FROM Reparacion r INNER JOIN Usuario tec ON tec.id_usuario = r.id_tecnico
    WHERE r.id_orden = o.id_orden AND r.activo = 1
    UNION ALL
    SELECT 'ENTREGA', en.fecha, 'Recibe: ' + en.recibe,
           entrega.nombres + ' ' + entrega.apellidos, NULL
    FROM Entrega en INNER JOIN Usuario entrega ON entrega.id_usuario = en.id_usuario_entrega
    WHERE en.id_orden = o.id_orden
) evento
WHERE e.serie LIKE '%' + :serie + '%'
ORDER BY e.serie, evento.fecha;""",
    },
    4: {
        "titulo": "Diagnosticos y reparaciones por tecnico en un rango de fechas",
        "params": [("id_tecnico", "INT", None), ("desde", "DATE", "2025-03-01"), ("hasta", "DATE", "2025-04-30")],
        "sql": f"""
SELECT
    trabajo.tecnico,
    trabajo.tipo_trabajo,
    trabajo.fecha,
    trabajo.numero_orden,
    trabajo.cliente,
    trabajo.equipo,
    trabajo.descripcion,
    trabajo.estado_trabajo,
    trabajo.costo_mano_obra
FROM (
    SELECT tec.id_usuario, tec.nombres + ' ' + tec.apellidos AS tecnico, 'DIAGNOSTICO' AS tipo_trabajo,
           d.fecha, o.numero AS numero_orden, {CLIENTE} AS cliente, {EQUIPO} AS equipo,
           d.descripcion, 'REGISTRADO' AS estado_trabajo, d.costo_mano_obra
    FROM Diagnostico d
    INNER JOIN Usuario       tec ON tec.id_usuario = d.id_tecnico
    INNER JOIN OrdenServicio o   ON o.id_orden = d.id_orden
    INNER JOIN Cliente       c   ON c.id_cliente = o.id_cliente
    INNER JOIN Equipo        e   ON e.id_equipo = o.id_equipo
    INNER JOIN TipoEquipo    te  ON te.id_tipo_equipo = e.id_tipo_equipo
    INNER JOIN MarcaEquipo   me  ON me.id_marca = e.id_marca
    WHERE d.activo = 1
    UNION ALL
    SELECT tec.id_usuario, tec.nombres + ' ' + tec.apellidos, 'REPARACION',
           r.fecha_inicio, o.numero, {CLIENTE}, {EQUIPO},
           ISNULL(r.descripcion, ''), r.estado, r.costo_mano_obra
    FROM Reparacion r
    INNER JOIN Usuario       tec ON tec.id_usuario = r.id_tecnico
    INNER JOIN OrdenServicio o   ON o.id_orden = r.id_orden
    INNER JOIN Cliente       c   ON c.id_cliente = o.id_cliente
    INNER JOIN Equipo        e   ON e.id_equipo = o.id_equipo
    INNER JOIN TipoEquipo    te  ON te.id_tipo_equipo = e.id_tipo_equipo
    INNER JOIN MarcaEquipo   me  ON me.id_marca = e.id_marca
    WHERE r.activo = 1
) trabajo
WHERE (:id_tecnico IS NULL OR trabajo.id_usuario = :id_tecnico)
  AND (:desde IS NULL OR trabajo.fecha >= CAST(:desde AS DATE))
  AND (:hasta IS NULL OR trabajo.fecha < DATEADD(DAY, 1, CAST(:hasta AS DATE)))
ORDER BY trabajo.tecnico, trabajo.fecha;""",
    },
    5: {
        "titulo": "Repuestos utilizados por orden, tecnico y bodega con costo/venta historico",
        "params": [("numero_orden", "NVARCHAR(20)", None), ("id_tecnico", "INT", None), ("id_bodega", "INT", None)],
        "sql": f"""
SELECT
    o.numero                         AS numero_orden,
    {CLIENTE}                        AS cliente,
    tec.nombres + ' ' + tec.apellidos AS tecnico,
    r.fecha_inicio                   AS fecha_reparacion,
    b.nombre                         AS bodega,
    rep.codigo,
    rep.nombre                       AS repuesto,
    rr.cantidad,
    costo.costo_promedio_compra      AS costo_historico_compra,
    rr.precio_historico              AS precio_venta_historico,
    rep.precio_venta                 AS precio_venta_actual,
    rr.cantidad * rr.precio_historico AS subtotal_venta
FROM ReparacionRepuesto rr
INNER JOIN Reparacion    r   ON r.id_reparacion = rr.id_reparacion
INNER JOIN OrdenServicio o   ON o.id_orden = r.id_orden
INNER JOIN Cliente       c   ON c.id_cliente = o.id_cliente
INNER JOIN Usuario       tec ON tec.id_usuario = r.id_tecnico
INNER JOIN Bodega        b   ON b.id_bodega = rr.id_bodega
INNER JOIN Repuesto      rep ON rep.id_repuesto = rr.id_repuesto
OUTER APPLY (
    SELECT CAST(AVG(dc.costo_historico) AS DECIMAL(10,2)) AS costo_promedio_compra
    FROM DetalleCompra dc
    INNER JOIN Compra co ON co.id_compra = dc.id_compra
    WHERE dc.id_repuesto = rr.id_repuesto AND co.estado = 'RECIBIDA'
) costo
WHERE rr.activo = 1
  AND (:numero_orden IS NULL OR o.numero = :numero_orden)
  AND (:id_tecnico IS NULL OR r.id_tecnico = :id_tecnico)
  AND (:id_bodega IS NULL OR rr.id_bodega = :id_bodega)
ORDER BY o.numero, rep.nombre;""",
    },
    6: {
        "titulo": "Inventario actual por bodega, categoria y repuesto",
        "params": [("id_bodega", "INT", None), ("id_categoria", "INT", None)],
        "sql": """
SELECT
    b.nombre                    AS bodega,
    cat.nombre                  AS categoria,
    rep.codigo,
    rep.nombre                  AS repuesto,
    i.existencia,
    i.stock_minimo,
    CASE WHEN i.existencia = 0 THEN 'SIN STOCK'
         WHEN i.existencia <= i.stock_minimo THEN 'BAJO MINIMO'
         ELSE 'OK' END          AS situacion,
    rep.precio_compra_ref,
    i.existencia * rep.precio_compra_ref AS valor_inventario
FROM Inventario i
INNER JOIN Bodega            b   ON b.id_bodega = i.id_bodega
INNER JOIN Repuesto          rep ON rep.id_repuesto = i.id_repuesto
INNER JOIN CategoriaRepuesto cat ON cat.id_categoria = rep.id_categoria
WHERE i.activo = 1
  AND (:id_bodega IS NULL OR i.id_bodega = :id_bodega)
  AND (:id_categoria IS NULL OR rep.id_categoria = :id_categoria)
ORDER BY b.nombre, cat.nombre, rep.nombre;""",
    },
    7: {
        "titulo": "Repuestos con existencia igual o inferior al stock minimo",
        "params": [("id_bodega", "INT", None)],
        "sql": """
SELECT
    b.nombre                    AS bodega,
    cat.nombre                  AS categoria,
    rep.codigo,
    rep.nombre                  AS repuesto,
    i.existencia,
    i.stock_minimo,
    i.stock_minimo - i.existencia AS faltante,
    ultima.proveedor            AS ultimo_proveedor,
    ultima.fecha                AS fecha_ultima_compra,
    ultima.costo_historico      AS ultimo_costo
FROM Inventario i
INNER JOIN Bodega            b   ON b.id_bodega = i.id_bodega
INNER JOIN Repuesto          rep ON rep.id_repuesto = i.id_repuesto
INNER JOIN CategoriaRepuesto cat ON cat.id_categoria = rep.id_categoria
OUTER APPLY (
    SELECT TOP 1 p.nombre AS proveedor, co.fecha, dc.costo_historico
    FROM DetalleCompra dc
    INNER JOIN Compra    co ON co.id_compra = dc.id_compra
    INNER JOIN Proveedor p  ON p.id_proveedor = co.id_proveedor
    WHERE dc.id_repuesto = i.id_repuesto AND co.estado = 'RECIBIDA'
    ORDER BY co.fecha DESC
) ultima
WHERE i.activo = 1
  AND i.existencia <= i.stock_minimo
  AND (:id_bodega IS NULL OR i.id_bodega = :id_bodega)
ORDER BY faltante DESC, rep.nombre;""",
    },
    8: {
        "titulo": "Compras por proveedor con detalle de repuestos y costos historicos",
        "params": [("id_proveedor", "INT", None), ("estado", "NVARCHAR(15)", None),
                   ("desde", "DATE", None), ("hasta", "DATE", None)],
        "sql": """
SELECT
    p.nombre                    AS proveedor,
    co.numero                   AS numero_compra,
    co.fecha,
    co.estado,
    b.nombre                    AS bodega,
    registra.nombres + ' ' + registra.apellidos AS registrada_por,
    rep.codigo,
    rep.nombre                  AS repuesto,
    dc.cantidad,
    dc.costo_historico,
    dc.cantidad * dc.costo_historico AS subtotal,
    rep.precio_compra_ref       AS costo_referencia_actual
FROM Proveedor p
INNER JOIN Compra        co       ON co.id_proveedor = p.id_proveedor
INNER JOIN DetalleCompra dc       ON dc.id_compra = co.id_compra
INNER JOIN Repuesto      rep      ON rep.id_repuesto = dc.id_repuesto
INNER JOIN Bodega        b        ON b.id_bodega = co.id_bodega
INNER JOIN Usuario       registra ON registra.id_usuario = co.id_usuario
WHERE co.activo = 1
  AND (:id_proveedor IS NULL OR p.id_proveedor = :id_proveedor)
  AND (:estado IS NULL OR co.estado = :estado)
  AND (:desde IS NULL OR co.fecha >= CAST(:desde AS DATE))
  AND (:hasta IS NULL OR co.fecha < DATEADD(DAY, 1, CAST(:hasta AS DATE)))
ORDER BY p.nombre, co.fecha DESC, rep.nombre;""",
    },
    9: {
        "titulo": "Movimientos de inventario con documento origen, tipo y usuario",
        "params": [("tipo", "NVARCHAR(10)", None), ("id_bodega", "INT", None),
                   ("desde", "DATE", None), ("hasta", "DATE", None)],
        "sql": """
SELECT
    m.fecha,
    m.tipo,
    rep.codigo,
    rep.nombre                  AS repuesto,
    b.nombre                    AS bodega,
    m.cantidad,
    m.existencia_resultante,
    m.doc_tipo                  AS tipo_documento,
    CASE m.doc_tipo
        WHEN 'COMPRA'     THEN co.numero
        WHEN 'REPARACION' THEN o.numero + ' / reparacion ' + CAST(r.id_reparacion AS VARCHAR(10))
        ELSE 'Ajuste de inventario'
    END                         AS documento_origen,
    u.nombres + ' ' + u.apellidos AS usuario_responsable
FROM MovimientoInventario m
INNER JOIN Repuesto      rep ON rep.id_repuesto = m.id_repuesto
INNER JOIN Bodega        b   ON b.id_bodega = m.id_bodega
INNER JOIN Usuario       u   ON u.id_usuario = m.id_usuario
LEFT  JOIN Compra        co  ON m.doc_tipo = 'COMPRA' AND co.id_compra = m.doc_referencia
LEFT  JOIN Reparacion    r   ON m.doc_tipo = 'REPARACION' AND r.id_reparacion = m.doc_referencia
LEFT  JOIN OrdenServicio o   ON o.id_orden = r.id_orden
WHERE m.activo = 1
  AND (:tipo IS NULL OR m.tipo = :tipo)
  AND (:id_bodega IS NULL OR m.id_bodega = :id_bodega)
  AND (:desde IS NULL OR m.fecha >= CAST(:desde AS DATE))
  AND (:hasta IS NULL OR m.fecha < DATEADD(DAY, 1, CAST(:hasta AS DATE)))
ORDER BY m.fecha DESC, m.id_movimiento DESC;""",
    },
    10: {
        "titulo": "Facturas con saldo pendiente y detalle de pagos realizados",
        "params": [("solo_pendientes", "BIT", 1), ("id_cliente", "INT", None)],
        "sql": """
SELECT
    f.numero                    AS numero_factura,
    f.fecha                     AS fecha_factura,
    o.numero                    AS numero_orden,
    f.nombre_facturacion        AS cliente,
    f.total,
    dbo.fn_SaldoFactura(f.id_factura) AS saldo_pendiente,
    p.fecha                     AS fecha_pago,
    mp.nombre                   AS metodo_pago,
    p.monto                     AS monto_pago,
    p.referencia
FROM Factura f
INNER JOIN OrdenServicio o  ON o.id_orden = f.id_orden
LEFT  JOIN Pago          p  ON p.id_factura = f.id_factura AND p.activo = 1
LEFT  JOIN MetodoPago    mp ON mp.id_metodo = p.id_metodo
WHERE f.activo = 1
  AND f.estado = 'EMITIDA'
  AND (:solo_pendientes = 0 OR dbo.fn_SaldoFactura(f.id_factura) > 0)
  AND (:id_cliente IS NULL OR o.id_cliente = :id_cliente)
ORDER BY f.fecha, f.numero, p.fecha;""",
    },
    11: {
        "titulo": "Ingresos facturados por periodo (mano de obra y repuestos)",
        "params": [("desde", "DATE", None), ("hasta", "DATE", None)],
        "sql": """
SELECT
    FORMAT(f.fecha, 'yyyy-MM')  AS periodo,
    COUNT(*)                    AS facturas,
    SUM(detalle.mano_obra)      AS ingreso_mano_obra,
    SUM(detalle.repuestos)      AS ingreso_repuestos,
    SUM(f.subtotal)             AS subtotal,
    SUM(f.impuesto)             AS impuesto,
    SUM(f.total)                AS total_facturado,
    SUM(cobro.cobrado)          AS total_cobrado,
    SUM(f.total) - SUM(cobro.cobrado) AS pendiente_de_cobro
FROM Factura f
CROSS APPLY (
    SELECT ISNULL(SUM(CASE WHEN df.tipo = 'MANO_OBRA' THEN df.subtotal END), 0) AS mano_obra,
           ISNULL(SUM(CASE WHEN df.tipo = 'REPUESTO'  THEN df.subtotal END), 0) AS repuestos
    FROM DetalleFactura df
    WHERE df.id_factura = f.id_factura AND df.activo = 1
) detalle
CROSS APPLY (
    SELECT ISNULL(SUM(pg.monto), 0) AS cobrado
    FROM Pago pg
    WHERE pg.id_factura = f.id_factura AND pg.activo = 1
) cobro
WHERE f.activo = 1
  AND f.estado = 'EMITIDA'
  AND (:desde IS NULL OR f.fecha >= CAST(:desde AS DATE))
  AND (:hasta IS NULL OR f.fecha < DATEADD(DAY, 1, CAST(:hasta AS DATE)))
GROUP BY FORMAT(f.fecha, 'yyyy-MM')
ORDER BY periodo;""",
    },
    12: {
        "titulo": "Trazabilidad completa de una orden",
        "params": [("numero_orden", "NVARCHAR(20)", None)],
        # Sin numero de orden: una fila por orden con todo su recorrido (resumen).
        "sql": f"""
SELECT
    o.numero                    AS numero_orden,
    o.estado,
    o.fecha_ingreso,
    {CLIENTE}                   AS cliente,
    {EQUIPO} + ' (' + e.serie + ')' AS equipo,
    recep.nombres + ' ' + recep.apellidos AS recepcion,
    diag.diagnosticos,
    diag.tecnico_diagnostico,
    trabajo.reparaciones,
    trabajo.tecnico_reparacion,
    trabajo.mano_obra,
    usado.unidades_repuestos,
    usado.valor_repuestos,
    mov.movimientos_inventario,
    f.numero                    AS numero_factura,
    f.total                     AS total_factura,
    pagos.pagado,
    CASE WHEN f.id_factura IS NULL THEN NULL ELSE dbo.fn_SaldoFactura(f.id_factura) END AS saldo,
    en.fecha                    AS fecha_entrega,
    en.recibe
FROM OrdenServicio o
INNER JOIN Cliente     c     ON c.id_cliente = o.id_cliente
INNER JOIN Equipo      e     ON e.id_equipo = o.id_equipo
INNER JOIN TipoEquipo  te    ON te.id_tipo_equipo = e.id_tipo_equipo
INNER JOIN MarcaEquipo me    ON me.id_marca = e.id_marca
INNER JOIN Usuario     recep ON recep.id_usuario = o.id_usuario_recepcion
OUTER APPLY (
    SELECT COUNT(*) AS diagnosticos,
           MAX(tec.nombres + ' ' + tec.apellidos) AS tecnico_diagnostico
    FROM Diagnostico d INNER JOIN Usuario tec ON tec.id_usuario = d.id_tecnico
    WHERE d.id_orden = o.id_orden AND d.activo = 1
) diag
OUTER APPLY (
    SELECT COUNT(*) AS reparaciones,
           MAX(tec.nombres + ' ' + tec.apellidos) AS tecnico_reparacion,
           ISNULL(SUM(r.costo_mano_obra), 0) AS mano_obra
    FROM Reparacion r INNER JOIN Usuario tec ON tec.id_usuario = r.id_tecnico
    WHERE r.id_orden = o.id_orden AND r.activo = 1
) trabajo
OUTER APPLY (
    SELECT ISNULL(SUM(rr.cantidad), 0) AS unidades_repuestos,
           ISNULL(SUM(rr.cantidad * rr.precio_historico), 0) AS valor_repuestos
    FROM ReparacionRepuesto rr INNER JOIN Reparacion r ON r.id_reparacion = rr.id_reparacion
    WHERE r.id_orden = o.id_orden AND rr.activo = 1
) usado
OUTER APPLY (
    SELECT COUNT(*) AS movimientos_inventario
    FROM MovimientoInventario m INNER JOIN Reparacion r ON r.id_reparacion = m.doc_referencia
    WHERE m.doc_tipo = 'REPARACION' AND r.id_orden = o.id_orden
) mov
LEFT JOIN Factura f  ON f.id_orden = o.id_orden AND f.activo = 1
OUTER APPLY (
    SELECT ISNULL(SUM(p.monto), 0) AS pagado
    FROM Pago p WHERE p.id_factura = f.id_factura AND p.activo = 1
) pagos
LEFT JOIN Entrega en ON en.id_orden = o.id_orden
WHERE o.activo = 1
  AND (:numero_orden IS NULL OR o.numero = :numero_orden)
ORDER BY o.fecha_ingreso DESC;""",
        # Con numero de orden: linea de tiempo detallada de cada etapa.
        "sql_detalle": f"""
SELECT
    etapa.etapa,
    etapa.fecha,
    etapa.detalle,
    etapa.responsable,
    etapa.monto
FROM OrdenServicio o
CROSS APPLY (
    SELECT 1 AS paso, 'RECEPCION' AS etapa, o.fecha_ingreso AS fecha,
           CONCAT('Cliente: ', {CLIENTE}, ' | Equipo: ', {EQUIPO}, ' (', e.serie, ') | Problema: ', o.problema) AS detalle,
           recep.nombres + ' ' + recep.apellidos AS responsable, CAST(NULL AS DECIMAL(12,2)) AS monto
    FROM Cliente c
    INNER JOIN Equipo      e     ON e.id_equipo = o.id_equipo
    INNER JOIN TipoEquipo  te    ON te.id_tipo_equipo = e.id_tipo_equipo
    INNER JOIN MarcaEquipo me    ON me.id_marca = e.id_marca
    INNER JOIN Usuario     recep ON recep.id_usuario = o.id_usuario_recepcion
    WHERE c.id_cliente = o.id_cliente
    UNION ALL
    SELECT 2, 'CAMBIO DE ESTADO', h.fecha,
           CONCAT(ISNULL(h.estado_anterior, '(inicio)'), ' -> ', h.estado_nuevo, ISNULL(' | ' + h.observacion, '')),
           cambio.nombres + ' ' + cambio.apellidos, NULL
    FROM HistorialEstadoOrden h INNER JOIN Usuario cambio ON cambio.id_usuario = h.id_usuario
    WHERE h.id_orden = o.id_orden
    UNION ALL
    SELECT 3, 'DIAGNOSTICO', d.fecha, d.descripcion, tec.nombres + ' ' + tec.apellidos, d.costo_mano_obra
    FROM Diagnostico d INNER JOIN Usuario tec ON tec.id_usuario = d.id_tecnico
    WHERE d.id_orden = o.id_orden AND d.activo = 1
    UNION ALL
    SELECT 4, 'REPARACION', r.fecha_inicio,
           CONCAT(ISNULL(r.descripcion, ''), ' [', r.estado, ']'),
           tec.nombres + ' ' + tec.apellidos, r.costo_mano_obra
    FROM Reparacion r INNER JOIN Usuario tec ON tec.id_usuario = r.id_tecnico
    WHERE r.id_orden = o.id_orden AND r.activo = 1
    UNION ALL
    SELECT 5, 'REPUESTO / MOVIMIENTO', ISNULL(m.fecha, r.fecha_inicio),
           CONCAT(rep.nombre, ' x', rr.cantidad, ' desde ', b.nombre,
                  ' | precio historico ', rr.precio_historico,
                  ' | saldo en bodega: ', m.existencia_resultante),
           tec.nombres + ' ' + tec.apellidos, rr.cantidad * rr.precio_historico
    FROM ReparacionRepuesto rr
    INNER JOIN Reparacion r   ON r.id_reparacion = rr.id_reparacion
    INNER JOIN Repuesto   rep ON rep.id_repuesto = rr.id_repuesto
    INNER JOIN Bodega     b   ON b.id_bodega = rr.id_bodega
    INNER JOIN Usuario    tec ON tec.id_usuario = r.id_tecnico
    LEFT  JOIN MovimientoInventario m ON m.doc_tipo = 'REPARACION' AND m.doc_referencia = rr.id_reparacion
                                     AND m.id_repuesto = rr.id_repuesto AND m.id_bodega = rr.id_bodega
    WHERE r.id_orden = o.id_orden AND rr.activo = 1
    UNION ALL
    SELECT 6, 'FACTURA', f.fecha,
           CONCAT(f.numero, ' | subtotal ', f.subtotal, ' + impuesto ', f.impuesto, ' [', f.estado, ']'),
           f.nombre_facturacion, f.total
    FROM Factura f WHERE f.id_orden = o.id_orden AND f.activo = 1
    UNION ALL
    SELECT 7, 'PAGO', p.fecha, CONCAT(mp.nombre, ISNULL(' | ref. ' + p.referencia, '')), f.nombre_facturacion, p.monto
    FROM Factura f
    INNER JOIN Pago       p  ON p.id_factura = f.id_factura AND p.activo = 1
    INNER JOIN MetodoPago mp ON mp.id_metodo = p.id_metodo
    WHERE f.id_orden = o.id_orden
    UNION ALL
    SELECT 8, 'ENTREGA', en.fecha, CONCAT('Recibe: ', en.recibe, ISNULL(' | ' + en.observaciones, '')),
           entrega.nombres + ' ' + entrega.apellidos, NULL
    FROM Entrega en INNER JOIN Usuario entrega ON entrega.id_usuario = en.id_usuario_entrega
    WHERE en.id_orden = o.id_orden
) etapa
WHERE o.numero = :numero_orden
ORDER BY etapa.fecha, etapa.paso;""",
    },
}


def catalogo() -> list[dict]:
    """Lista de reportes disponibles (para el selector del frontend)."""
    return [{"numero": n, "titulo": r["titulo"], "params": [p[0] for p in r["params"]]}
            for n, r in REPORTES.items()]


def _convertir(tipo: str, valor):
    """Convierte el valor recibido (texto de la URL) al tipo del parametro."""
    if valor is None or valor == "":
        return None
    if tipo == "INT":
        return int(valor)
    if tipo == "BIT":
        return 1 if str(valor).lower() in ("1", "true", "si") else 0
    if tipo == "DATE":
        # formato esperado YYYY-MM-DD (lo valida SQL Server con CAST)
        return str(valor)[:10]
    return str(valor)


def ejecutar(db: Session, numero: int, valores: dict) -> dict:
    rep = REPORTES[numero]
    params = {}
    for nombre, tipo, defecto in rep["params"]:
        bruto = valores.get(nombre)
        params[nombre] = _convertir(tipo, bruto) if bruto not in (None, "") else (
            defecto if tipo == "BIT" else None)
    sql = rep["sql"]
    modo = "resumen"
    if numero == 12 and params.get("numero_orden"):
        sql, modo = rep["sql_detalle"], "detalle"
    filas = [dict(r) for r in db.execute(text(sql), params).mappings().all()]
    return {"numero": numero, "titulo": rep["titulo"], "modo": modo, "filas": filas}
