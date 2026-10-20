/* ============================================================================
   TechCare - SECCION 04 - LOS 12 REPORTES OBLIGATORIOS (seccion 5 del enunciado)
   Mismas consultas que ejecuta la aplicacion (backend: reportes_repo.py).
   Cada reporte declara sus filtros como variables: NULL = sin filtro.
   Condiciones 5.1: sin SELECT *, alias legibles, sin DISTINCT, filtros
   parametrizados, LEFT JOIN donde la informacion es opcional, y totales/
   saldos calculados en la base (fn_SaldoFactura).
   ============================================================================ */
USE TechCareDB;
GO

/* 1. Ordenes activas por estado, prioridad y tecnico responsable */
DECLARE @estado NVARCHAR(25) = NULL;
DECLARE @prioridad NVARCHAR(15) = NULL;
DECLARE @id_tecnico INT = NULL;
SELECT
    o.numero                                   AS numero_orden,
    o.estado,
    o.prioridad,
    o.fecha_ingreso,
    CASE c.tipo WHEN 'INDIVIDUAL' THEN c.nombres + ' ' + c.apellidos ELSE c.razon_social END                                  AS cliente,
    te.nombre + ' ' + me.nombre                                   AS equipo,
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
  AND (@estado IS NULL OR o.estado = @estado)
  AND (@prioridad IS NULL OR o.prioridad = @prioridad)
  AND (@id_tecnico IS NULL OR responsable.id_tecnico = @id_tecnico)
ORDER BY o.estado,
         CASE o.prioridad WHEN 'ALTA' THEN 1 WHEN 'MEDIA' THEN 2 ELSE 3 END,
         o.fecha_ingreso;
GO

/* 2. Historial completo de ordenes de un cliente */
DECLARE @id_cliente INT = 1;
SELECT
    CASE c.tipo WHEN 'INDIVIDUAL' THEN c.nombres + ' ' + c.apellidos ELSE c.razon_social END                    AS cliente,
    c.nit,
    o.numero                     AS numero_orden,
    o.fecha_ingreso,
    te.nombre + ' ' + me.nombre                     AS equipo,
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
WHERE (@id_cliente IS NULL OR c.id_cliente = @id_cliente)
ORDER BY cliente, o.fecha_ingreso DESC;
GO

/* 3. Historial tecnico de un equipo por numero de serie */
DECLARE @serie NVARCHAR(50) = N'SN100013';
SELECT
    e.serie,
    te.nombre + ' ' + me.nombre + ISNULL(' ' + e.modelo, '') AS equipo,
    CASE c.tipo WHEN 'INDIVIDUAL' THEN c.nombres + ' ' + c.apellidos ELSE c.razon_social END                    AS cliente,
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
WHERE e.serie LIKE '%' + @serie + '%'
ORDER BY e.serie, evento.fecha;
GO

/* 4. Diagnosticos y reparaciones por tecnico en un rango de fechas */
DECLARE @id_tecnico INT = NULL;
DECLARE @desde DATE = N'2025-03-01';
DECLARE @hasta DATE = N'2025-04-30';
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
           d.fecha, o.numero AS numero_orden, CASE c.tipo WHEN 'INDIVIDUAL' THEN c.nombres + ' ' + c.apellidos ELSE c.razon_social END AS cliente, te.nombre + ' ' + me.nombre AS equipo,
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
           r.fecha_inicio, o.numero, CASE c.tipo WHEN 'INDIVIDUAL' THEN c.nombres + ' ' + c.apellidos ELSE c.razon_social END, te.nombre + ' ' + me.nombre,
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
WHERE (@id_tecnico IS NULL OR trabajo.id_usuario = @id_tecnico)
  AND (@desde IS NULL OR trabajo.fecha >= CAST(@desde AS DATE))
  AND (@hasta IS NULL OR trabajo.fecha < DATEADD(DAY, 1, CAST(@hasta AS DATE)))
ORDER BY trabajo.tecnico, trabajo.fecha;
GO

/* 5. Repuestos utilizados por orden, tecnico y bodega con costo/venta historico */
DECLARE @numero_orden NVARCHAR(20) = NULL;
DECLARE @id_tecnico INT = NULL;
DECLARE @id_bodega INT = NULL;
SELECT
    o.numero                         AS numero_orden,
    CASE c.tipo WHEN 'INDIVIDUAL' THEN c.nombres + ' ' + c.apellidos ELSE c.razon_social END                        AS cliente,
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
  AND (@numero_orden IS NULL OR o.numero = @numero_orden)
  AND (@id_tecnico IS NULL OR r.id_tecnico = @id_tecnico)
  AND (@id_bodega IS NULL OR rr.id_bodega = @id_bodega)
ORDER BY o.numero, rep.nombre;
GO

/* 6. Inventario actual por bodega, categoria y repuesto */
DECLARE @id_bodega INT = NULL;
DECLARE @id_categoria INT = NULL;
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
  AND (@id_bodega IS NULL OR i.id_bodega = @id_bodega)
  AND (@id_categoria IS NULL OR rep.id_categoria = @id_categoria)
ORDER BY b.nombre, cat.nombre, rep.nombre;
GO

/* 7. Repuestos con existencia igual o inferior al stock minimo */
DECLARE @id_bodega INT = NULL;
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
  AND (@id_bodega IS NULL OR i.id_bodega = @id_bodega)
ORDER BY faltante DESC, rep.nombre;
GO

/* 8. Compras por proveedor con detalle de repuestos y costos historicos */
DECLARE @id_proveedor INT = NULL;
DECLARE @estado NVARCHAR(15) = NULL;
DECLARE @desde DATE = NULL;
DECLARE @hasta DATE = NULL;
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
  AND (@id_proveedor IS NULL OR p.id_proveedor = @id_proveedor)
  AND (@estado IS NULL OR co.estado = @estado)
  AND (@desde IS NULL OR co.fecha >= CAST(@desde AS DATE))
  AND (@hasta IS NULL OR co.fecha < DATEADD(DAY, 1, CAST(@hasta AS DATE)))
ORDER BY p.nombre, co.fecha DESC, rep.nombre;
GO

/* 9. Movimientos de inventario con documento origen, tipo y usuario */
DECLARE @tipo NVARCHAR(10) = NULL;
DECLARE @id_bodega INT = NULL;
DECLARE @desde DATE = NULL;
DECLARE @hasta DATE = NULL;
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
  AND (@tipo IS NULL OR m.tipo = @tipo)
  AND (@id_bodega IS NULL OR m.id_bodega = @id_bodega)
  AND (@desde IS NULL OR m.fecha >= CAST(@desde AS DATE))
  AND (@hasta IS NULL OR m.fecha < DATEADD(DAY, 1, CAST(@hasta AS DATE)))
ORDER BY m.fecha DESC, m.id_movimiento DESC;
GO

/* 10. Facturas con saldo pendiente y detalle de pagos realizados */
DECLARE @solo_pendientes BIT = 1;
DECLARE @id_cliente INT = NULL;
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
  AND (@solo_pendientes = 0 OR dbo.fn_SaldoFactura(f.id_factura) > 0)
  AND (@id_cliente IS NULL OR o.id_cliente = @id_cliente)
ORDER BY f.fecha, f.numero, p.fecha;
GO

/* 11. Ingresos facturados por periodo (mano de obra y repuestos) */
DECLARE @desde DATE = NULL;
DECLARE @hasta DATE = NULL;
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
  AND (@desde IS NULL OR f.fecha >= CAST(@desde AS DATE))
  AND (@hasta IS NULL OR f.fecha < DATEADD(DAY, 1, CAST(@hasta AS DATE)))
GROUP BY FORMAT(f.fecha, 'yyyy-MM')
ORDER BY periodo;
GO

/* 12a (resumen de todas las ordenes). Trazabilidad completa de una orden */
DECLARE @numero_orden NVARCHAR(20) = NULL;
SELECT
    o.numero                    AS numero_orden,
    o.estado,
    o.fecha_ingreso,
    CASE c.tipo WHEN 'INDIVIDUAL' THEN c.nombres + ' ' + c.apellidos ELSE c.razon_social END                   AS cliente,
    te.nombre + ' ' + me.nombre + ' (' + e.serie + ')' AS equipo,
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
  AND (@numero_orden IS NULL OR o.numero = @numero_orden)
ORDER BY o.fecha_ingreso DESC;
GO

/* 12b (linea de tiempo de una orden). Trazabilidad completa de una orden */
DECLARE @numero_orden NVARCHAR(20) = N'ORD-S0001';
SELECT
    etapa.etapa,
    etapa.fecha,
    etapa.detalle,
    etapa.responsable,
    etapa.monto
FROM OrdenServicio o
CROSS APPLY (
    SELECT 1 AS paso, 'RECEPCION' AS etapa, o.fecha_ingreso AS fecha,
           CONCAT('Cliente: ', CASE c.tipo WHEN 'INDIVIDUAL' THEN c.nombres + ' ' + c.apellidos ELSE c.razon_social END, ' | Equipo: ', te.nombre + ' ' + me.nombre, ' (', e.serie, ') | Problema: ', o.problema) AS detalle,
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
WHERE o.numero = @numero_orden
ORDER BY etapa.fecha, etapa.paso;
GO

