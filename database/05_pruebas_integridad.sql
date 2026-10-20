/* ============================================================================
   TechCare - SECCION 05 - PRUEBAS FUNCIONALES Y DE INTEGRIDAD
   Ejecutar DESPUES de 01, 02 y 03. Cada prueba imprime OK o FALLO.

   Recorre las pruebas obligatorias del enunciado (seccion 10) y las reglas
   de negocio (R04, R10, R12, R16, 2.7). Usa los procedimientos almacenados
   igual que lo hace la aplicacion, y tambien intenta INSERT/UPDATE directos
   para demostrar que la base rechaza datos invalidos (R16).

   NOTA: este script AGREGA registros de prueba (una orden recorrida de punta
   a punta, una compra, etc.). Para volver al estado inicial, re-ejecutar
   01, 02 y 03.
   ============================================================================ */
USE TechCareDB;
GO
SET NOCOUNT ON;
GO

PRINT '=== FLUJO PRINCIPAL: orden de punta a punta ===';
DECLARE @id INT, @tec INT = 8, @recep INT = 2, @caja INT = 4;
DECLARE @cliente INT, @equipo INT, @orden INT, @rep INT, @fac INT;

/* T01: registrar un cliente y dos equipos */
INSERT INTO Cliente (tipo, nombres, apellidos, nit, telefono)
VALUES ('INDIVIDUAL', 'Prueba', 'Integral', '9999999-9', '55550000');
SET @cliente = SCOPE_IDENTITY();
INSERT INTO Equipo (id_cliente, id_tipo_equipo, id_marca, modelo, serie) VALUES (@cliente, 1, 1, 'T-1', 'SN-PRUEBA-01');
SET @equipo = SCOPE_IDENTITY();
INSERT INTO Equipo (id_cliente, id_tipo_equipo, id_marca, modelo, serie) VALUES (@cliente, 2, 2, 'T-2', 'SN-PRUEBA-02');
IF (SELECT COUNT(*) FROM Equipo WHERE id_cliente = @cliente) = 2
    PRINT 'OK    T01 cliente con dos equipos';
ELSE PRINT 'FALLO T01';

/* T02: crear orden y comprobar estado inicial */
EXEC usp_CrearOrdenServicio @cliente, @equipo, @recep, N'No enciende', 'ALTA', NULL, @orden OUTPUT;
IF (SELECT estado FROM OrdenServicio WHERE id_orden = @orden) = 'RECIBIDO'
    PRINT 'OK    T02 orden creada en estado RECIBIDO';
ELSE PRINT 'FALLO T02';

/* R04: no se puede iniciar reparacion sin diagnostico (via SP) */
BEGIN TRY
    EXEC usp_IniciarReparacion @orden, @tec, N'Intento sin diagnostico', 100, @id OUTPUT;
    PRINT 'FALLO R04 (debio rechazar)';
END TRY
BEGIN CATCH
    PRINT 'OK    R04 (SP) rechazado: ' + ERROR_MESSAGE();
END CATCH

/* R04 + R16: ni siquiera con INSERT directo en la tabla */
BEGIN TRY
    INSERT INTO Reparacion (id_orden, id_tecnico, estado) VALUES (@orden, @tec, 'PENDIENTE');
    PRINT 'FALLO R16/R04 (debio rechazar)';
END TRY
BEGIN CATCH
    PRINT 'OK    R16/R04 (INSERT directo) rechazado: ' + ERROR_MESSAGE();
END CATCH

/* T03: diagnostico con tecnico responsable y cambio de estado */
EXEC usp_RegistrarDiagnostico @orden, @tec, N'Fuente de poder danada', 150, @id OUTPUT;
IF (SELECT estado FROM OrdenServicio WHERE id_orden = @orden) = 'DIAGNOSTICO'
    PRINT 'OK    T03 diagnostico registrado y orden en DIAGNOSTICO';
ELSE PRINT 'FALLO T03';

/* R03: un usuario que no es tecnico no puede diagnosticar */
BEGIN TRY
    EXEC usp_RegistrarDiagnostico @orden, @caja, N'Intento de caja', 0, @id OUTPUT;
    PRINT 'FALLO R03';
END TRY
BEGIN CATCH
    PRINT 'OK    R03 rechazado: ' + ERROR_MESSAGE();
END CATCH

/* Inicio de reparacion (ahora si: hay diagnostico) */
EXEC usp_IniciarReparacion @orden, @tec, N'Cambio de fuente', 200, @rep OUTPUT;
IF (SELECT estado FROM OrdenServicio WHERE id_orden = @orden) = 'REPARACION'
    PRINT 'OK    Inicio de reparacion: orden en REPARACION';
ELSE PRINT 'FALLO inicio de reparacion';

/* T04 + T07: repuesto sin stock suficiente -> rechazo SIN cambios parciales */
DECLARE @rp INT, @bd INT, @exist INT, @movs_antes INT, @reprep_antes INT;
SELECT TOP 1 @rp = id_repuesto, @bd = id_bodega, @exist = existencia
FROM Inventario WHERE existencia BETWEEN 2 AND 50 ORDER BY id_repuesto;
SET @movs_antes = (SELECT COUNT(*) FROM MovimientoInventario);
SET @reprep_antes = (SELECT COUNT(*) FROM ReparacionRepuesto);
BEGIN TRY
    DECLARE @mucho INT = @exist + 100;
    EXEC usp_ConsumirRepuesto @rep, @rp, @bd, @mucho, @tec;
    PRINT 'FALLO T04';
END TRY
BEGIN CATCH
    PRINT 'OK    T04 sin stock rechazado: ' + ERROR_MESSAGE();
END CATCH
IF (SELECT existencia FROM Inventario WHERE id_repuesto = @rp AND id_bodega = @bd) = @exist
   AND (SELECT COUNT(*) FROM MovimientoInventario) = @movs_antes
   AND (SELECT COUNT(*) FROM ReparacionRepuesto) = @reprep_antes
    PRINT 'OK    T07 rollback: inventario, movimientos y detalle sin cambios';
ELSE PRINT 'FALLO T07';

/* T05: repuesto con stock -> detalle + salida de inventario + movimiento */
EXEC usp_ConsumirRepuesto @rep, @rp, @bd, 1, @tec;
IF (SELECT existencia FROM Inventario WHERE id_repuesto = @rp AND id_bodega = @bd) = @exist - 1
   AND EXISTS (SELECT 1 FROM MovimientoInventario WHERE doc_tipo = 'REPARACION' AND doc_referencia = @rep
               AND tipo = 'SALIDA' AND existencia_resultante = @exist - 1)
    PRINT 'OK    T05 consumo: existencia -1 y movimiento SALIDA con saldo';
ELSE PRINT 'FALLO T05';

/* Reglas de cambio de estado */
BEGIN TRY
    EXEC usp_CambiarEstadoOrden @orden, 'ENTREGADO', @recep, NULL;
    PRINT 'FALLO regla ENTREGADO manual';
END TRY
BEGIN CATCH
    PRINT 'OK    No se entrega por cambio manual: ' + ERROR_MESSAGE();
END CATCH

/* Cierre de reparacion -> orden LISTO */
EXEC usp_FinalizarReparacion @rep, @tec;
IF (SELECT estado FROM OrdenServicio WHERE id_orden = @orden) = 'LISTO'
    PRINT 'OK    Cierre de reparacion: orden en LISTO';
ELSE PRINT 'FALLO cierre de reparacion';

/* 2.7: no se entrega sin factura */
BEGIN TRY
    EXEC usp_EntregarOrden @orden, @recep, N'Prueba Integral', NULL, @id OUTPUT;
    PRINT 'FALLO entrega sin factura';
END TRY
BEGIN CATCH
    PRINT 'OK    Entrega sin factura rechazada: ' + ERROR_MESSAGE();
END CATCH

/* T08: factura de la orden terminada y calculo de totales */
EXEC usp_GenerarFactura @orden, @caja, @fac OUTPUT;
DECLARE @total DECIMAL(12,2) = (SELECT total FROM Factura WHERE id_factura = @fac);
DECLARE @esperado DECIMAL(12,2) = ROUND(dbo.fn_TotalOrden(@orden) * 1.12, 2);
IF ABS(@total - @esperado) <= 0.01
    PRINT CONCAT('OK    T08 factura total = ', @total, ' (mano de obra + repuestos + 12%)');
ELSE PRINT CONCAT('FALLO T08 total=', @total, ' esperado=', @esperado);

/* 2.7: no se entrega con saldo pendiente */
BEGIN TRY
    EXEC usp_EntregarOrden @orden, @recep, N'Prueba Integral', NULL, @id OUTPUT;
    PRINT 'FALLO entrega con saldo';
END TRY
BEGIN CATCH
    PRINT 'OK    Entrega con saldo rechazada: ' + ERROR_MESSAGE();
END CATCH

/* T09: dos pagos parciales y saldo restante */
DECLARE @p1 DECIMAL(12,2) = ROUND(@total * 0.4, 2);
EXEC usp_RegistrarPago @fac, 1, @p1, N'REC-T1', @id OUTPUT;
EXEC usp_RegistrarPago @fac, 2, 10.00, N'REC-T2', @id OUTPUT;
IF dbo.fn_SaldoFactura(@fac) = @total - @p1 - 10.00
    PRINT CONCAT('OK    T09 dos pagos parciales, saldo restante = ', dbo.fn_SaldoFactura(@fac));
ELSE PRINT 'FALLO T09';

/* T10: pago que excede el saldo */
BEGIN TRY
    DECLARE @excede DECIMAL(12,2) = dbo.fn_SaldoFactura(@fac) + 1;
    EXEC usp_RegistrarPago @fac, 1, @excede, NULL, @id OUTPUT;
    PRINT 'FALLO T10';
END TRY
BEGIN CATCH
    PRINT 'OK    T10 pago excedente rechazado: ' + ERROR_MESSAGE();
END CATCH

/* Saldar y entregar */
DECLARE @resto DECIMAL(12,2) = dbo.fn_SaldoFactura(@fac);
EXEC usp_RegistrarPago @fac, 1, @resto, N'REC-T3', @id OUTPUT;
EXEC usp_EntregarOrden @orden, @recep, N'Prueba Integral', N'Conforme', @id OUTPUT;
IF (SELECT estado FROM OrdenServicio WHERE id_orden = @orden) = 'ENTREGADO'
    PRINT 'OK    Entrega con factura saldada: orden ENTREGADO';
ELSE PRINT 'FALLO entrega';

/* R05: historial con cada transicion */
DECLARE @hist INT = (SELECT COUNT(*) FROM HistorialEstadoOrden WHERE id_orden = @orden);
IF @hist = 5
    PRINT 'OK    R05 historial: 5 transiciones (RECIBIDO > DIAGNOSTICO > REPARACION > LISTO > ENTREGADO)';
ELSE PRINT CONCAT('FALLO R05 transiciones=', @hist);

/* Trigger de proteccion: no se anula factura con pagos */
BEGIN TRY
    UPDATE Factura SET estado = 'ANULADA' WHERE id_factura = @fac;
    PRINT 'FALLO trigger de factura';
END TRY
BEGIN CATCH
    PRINT 'OK    Factura con pagos no se anula: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '';
PRINT '=== FLUJO DE ABASTECIMIENTO: compra con varios repuestos ===';
DECLARE @compra INT, @bodega INT = 2, @bodeguero INT = 6;
DECLARE @r1 INT = 25, @r2 INT = 26;   /* repuestos que aun no tienen inventario en ninguna bodega */
DECLARE @inv_antes INT = (SELECT COUNT(*) FROM Inventario);

/* T06 parte 1: registrar compra (encabezado + detalle) en estado PENDIENTE */
DECLARE @json NVARCHAR(MAX) = CONCAT('[{"id_repuesto":', @r1, ',"cantidad":10,"costo":150.00},',
                                     '{"id_repuesto":', @r2, ',"cantidad":5,"costo":80.50}]');
EXEC usp_RegistrarCompra 1, @bodega, @bodeguero, @json, @compra OUTPUT;
IF (SELECT estado FROM Compra WHERE id_compra = @compra) = 'PENDIENTE'
   AND (SELECT COUNT(*) FROM DetalleCompra WHERE id_compra = @compra) = 2
   AND (SELECT total FROM Compra WHERE id_compra = @compra) = 1902.50
   AND (SELECT COUNT(*) FROM Inventario) = @inv_antes
    PRINT 'OK    T06a compra PENDIENTE con 2 renglones, total 1902.50, inventario sin cambios';
ELSE PRINT 'FALLO T06a';

/* T06 parte 2: recibirla -> inventario y movimientos */
EXEC usp_RecibirCompra @compra, @bodeguero;
IF (SELECT estado FROM Compra WHERE id_compra = @compra) = 'RECIBIDA'
   AND (SELECT existencia FROM Inventario WHERE id_repuesto = @r1 AND id_bodega = @bodega) = 10
   AND (SELECT existencia FROM Inventario WHERE id_repuesto = @r2 AND id_bodega = @bodega) = 5
   AND (SELECT COUNT(*) FROM MovimientoInventario WHERE doc_tipo = 'COMPRA' AND doc_referencia = @compra AND tipo = 'ENTRADA') = 2
    PRINT 'OK    T06b compra RECIBIDA: inventario +10 / +5 y 2 movimientos de ENTRADA';
ELSE PRINT 'FALLO T06b';

BEGIN TRY
    EXEC usp_RecibirCompra @compra, @bodeguero;
    PRINT 'FALLO doble recepcion';
END TRY
BEGIN CATCH
    PRINT 'OK    No se recibe dos veces: ' + ERROR_MESSAGE();
END CATCH

BEGIN TRY
    DECLARE @dup NVARCHAR(MAX) = '[{"id_repuesto":1,"cantidad":1,"costo":1},{"id_repuesto":1,"cantidad":2,"costo":1}]';
    EXEC usp_RegistrarCompra 1, 1, 6, @dup, @compra OUTPUT;
    PRINT 'FALLO repuesto repetido';
END TRY
BEGIN CATCH
    PRINT 'OK    Repuesto repetido rechazado: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '';
PRINT '=== T14: precios historicos ===';
DECLARE @rid INT, @rpid INT, @hist_antes DECIMAL(10,2);
SELECT TOP 1 @rid = id_reparacion, @rpid = id_repuesto, @hist_antes = precio_historico FROM ReparacionRepuesto;
UPDATE Repuesto SET precio_venta = precio_venta * 2 WHERE id_repuesto = @rpid;
IF (SELECT precio_historico FROM ReparacionRepuesto WHERE id_reparacion = @rid AND id_repuesto = @rpid) = @hist_antes
    PRINT 'OK    T14 cambio de precio en catalogo NO altera el precio historico';
ELSE PRINT 'FALLO T14';
UPDATE Repuesto SET precio_venta = precio_venta / 2 WHERE id_repuesto = @rpid;   /* se restaura */
GO

PRINT '';
PRINT '=== R16: la base rechaza datos invalidos insertados directamente ===';
BEGIN TRY UPDATE Inventario SET existencia = -1 WHERE id_repuesto = 1 AND id_bodega = 1; PRINT 'FALLO R10'; END TRY
BEGIN CATCH PRINT 'OK    R10 existencia negativa: ' + ERROR_MESSAGE(); END CATCH

BEGIN TRY INSERT INTO Pago (id_factura, id_metodo, monto) VALUES (1, 1, 0); PRINT 'FALLO CHECK monto'; END TRY
BEGIN CATCH PRINT 'OK    Pago con monto 0: ' + ERROR_MESSAGE(); END CATCH

BEGIN TRY INSERT INTO Cliente (tipo, nombres, apellidos, razon_social, nit) VALUES ('INDIVIDUAL', 'A', 'B', 'Empresa', '1-1'); PRINT 'FALLO CHECK cliente'; END TRY
BEGIN CATCH PRINT 'OK    Cliente individual con razon social: ' + ERROR_MESSAGE(); END CATCH

BEGIN TRY INSERT INTO Cliente (tipo, nombres, apellidos, nit) SELECT 'INDIVIDUAL', 'X', 'Y', nit FROM Cliente WHERE id_cliente = 1; PRINT 'FALLO UNIQUE'; END TRY
BEGIN CATCH PRINT 'OK    NIT duplicado: ' + ERROR_MESSAGE(); END CATCH

BEGIN TRY INSERT INTO Equipo (id_cliente, id_tipo_equipo, id_marca, serie) VALUES (99999, 1, 1, 'SN-HUERFANO'); PRINT 'FALLO FK'; END TRY
BEGIN CATCH PRINT 'OK    Equipo con cliente inexistente: ' + ERROR_MESSAGE(); END CATCH

BEGIN TRY INSERT INTO OrdenServicio (numero, id_cliente, id_equipo, id_usuario_recepcion, problema, estado) VALUES ('ORD-X', 1, 1, 1, 'x', 'PERDIDO'); PRINT 'FALLO CHECK estado'; END TRY
BEGIN CATCH PRINT 'OK    Orden con estado invalido: ' + ERROR_MESSAGE(); END CATCH
GO
