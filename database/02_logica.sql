/* ============================================================================
   PROYECTO FINAL - BASE DE DATOS I
   TechCare Solutions

   SECCION 02 - LOGICA DE BASE DE DATOS
   Motor: Microsoft SQL Server

   Requiere haber ejecutado antes 01_creacion_tablas.sql (base TechCareDB).

   Contenido, en orden de dependencias:
     A. INDICES no agrupados           (8)
     B. FUNCIONES escalares            (2)
     C. VISTAS                         (4)
     D. PROCEDIMIENTOS ALMACENADOS     (12; todos los procesos del negocio)
     E. TRIGGERS                       (3; auditoria y proteccion)

   Convenciones:
     - Procedimientos: usp_<Accion>
     - Funciones:      fn_<Calculo>
     - Vistas:         vw_<Consulta>
     - Triggers:       trg_<Tabla>_<Proposito>
     - Los procesos multi-tabla usan TRY/CATCH + TRANSACTION + ROLLBACK + THROW.
   ============================================================================ */

USE TechCareDB;
GO


/* ============================================================================
   A. INDICES NO AGRUPADOS
   Aceleran los filtros y JOIN mas frecuentes de los reportes.
   (Las PK ya crean indices agrupados; estos son adicionales.)
   ============================================================================ */

CREATE NONCLUSTERED INDEX IX_Orden_estado        ON OrdenServicio (estado);
GO
CREATE NONCLUSTERED INDEX IX_Orden_cliente       ON OrdenServicio (id_cliente);
GO
CREATE NONCLUSTERED INDEX IX_Equipo_cliente      ON Equipo (id_cliente);
GO
CREATE NONCLUSTERED INDEX IX_Mov_repuesto_bodega ON MovimientoInventario (id_repuesto, id_bodega);
GO
CREATE NONCLUSTERED INDEX IX_Factura_fecha       ON Factura (fecha);
GO
CREATE NONCLUSTERED INDEX IX_Pago_factura        ON Pago (id_factura);
GO
/* Apoyan R04 (diagnostico previo) y el historial / trazabilidad de la orden */
CREATE NONCLUSTERED INDEX IX_Diag_orden          ON Diagnostico (id_orden);
GO
CREATE NONCLUSTERED INDEX IX_Historial_orden     ON HistorialEstadoOrden (id_orden, fecha);
GO


/* ============================================================================
   B. FUNCIONES ESCALARES
   ============================================================================ */

/* fn_SaldoFactura: total de la factura menos la suma de pagos activos.
   Se usa en vistas, reportes y en usp_RegistrarPago para no exceder el saldo. */
CREATE OR ALTER FUNCTION fn_SaldoFactura (@id_factura INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @total   DECIMAL(12,2);
    DECLARE @pagado  DECIMAL(12,2);

    SELECT @total = total
    FROM Factura
    WHERE id_factura = @id_factura;

    SELECT @pagado = ISNULL(SUM(monto), 0)
    FROM Pago
    WHERE id_factura = @id_factura
      AND activo = 1;

    RETURN ISNULL(@total, 0) - ISNULL(@pagado, 0);
END;
GO

/* fn_TotalOrden: costo total de una orden = mano de obra de sus reparaciones
   + repuestos consumidos (cantidad * precio historico). */
CREATE OR ALTER FUNCTION fn_TotalOrden (@id_orden INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @mano_obra  DECIMAL(12,2);
    DECLARE @repuestos  DECIMAL(12,2);

    SELECT @mano_obra = ISNULL(SUM(r.costo_mano_obra), 0)
    FROM Reparacion r
    WHERE r.id_orden = @id_orden
      AND r.activo = 1;

    SELECT @repuestos = ISNULL(SUM(rr.cantidad * rr.precio_historico), 0)
    FROM ReparacionRepuesto rr
    INNER JOIN Reparacion r ON r.id_reparacion = rr.id_reparacion
    WHERE r.id_orden = @id_orden
      AND rr.activo = 1;

    RETURN @mano_obra + @repuestos;
END;
GO


/* ============================================================================
   C. VISTAS
   ============================================================================ */

/* vw_OrdenesActivas: ordenes que aun estan en el taller (no entregadas ni
   canceladas), con cliente, equipo y tecnico de recepcion. */
CREATE OR ALTER VIEW vw_OrdenesActivas AS
SELECT
    o.id_orden,
    o.numero,
    o.estado,
    o.prioridad,
    o.fecha_ingreso,
    o.fecha_estimada,
    c.id_cliente,
    CASE c.tipo
        WHEN 'INDIVIDUAL'  THEN c.nombres + ' ' + c.apellidos
        WHEN 'EMPRESARIAL' THEN c.razon_social
    END                          AS cliente,
    e.id_equipo,
    te.nombre                    AS tipo_equipo,
    me.nombre                    AS marca,
    e.serie,
    u.nombres + ' ' + u.apellidos AS recepcionista
FROM OrdenServicio o
INNER JOIN Cliente    c  ON c.id_cliente     = o.id_cliente
INNER JOIN Equipo     e  ON e.id_equipo      = o.id_equipo
INNER JOIN TipoEquipo te ON te.id_tipo_equipo = e.id_tipo_equipo
INNER JOIN MarcaEquipo me ON me.id_marca     = e.id_marca
INNER JOIN Usuario    u  ON u.id_usuario     = o.id_usuario_recepcion
WHERE o.activo = 1
  AND o.estado NOT IN ('ENTREGADO', 'CANCELADO');
GO

/* vw_InventarioBajoStock: existencias en o por debajo del minimo. */
CREATE OR ALTER VIEW vw_InventarioBajoStock AS
SELECT
    r.id_repuesto,
    r.codigo,
    r.nombre              AS repuesto,
    cat.nombre            AS categoria,
    b.id_bodega,
    b.nombre              AS bodega,
    i.existencia,
    i.stock_minimo
FROM Inventario i
INNER JOIN Repuesto          r   ON r.id_repuesto  = i.id_repuesto
INNER JOIN CategoriaRepuesto cat ON cat.id_categoria = r.id_categoria
INNER JOIN Bodega            b   ON b.id_bodega    = i.id_bodega
WHERE i.activo = 1
  AND i.existencia <= i.stock_minimo;
GO

/* vw_FacturasConSaldo: estado de cuenta de cada factura usando fn_SaldoFactura. */
CREATE OR ALTER VIEW vw_FacturasConSaldo AS
SELECT
    f.id_factura,
    f.numero,
    f.fecha,
    f.id_orden,
    o.numero                     AS numero_orden,
    f.nombre_facturacion,
    f.nit,
    f.total,
    dbo.fn_SaldoFactura(f.id_factura)        AS saldo,
    (f.total - dbo.fn_SaldoFactura(f.id_factura)) AS pagado,
    f.estado
FROM Factura f
INNER JOIN OrdenServicio o ON o.id_orden = f.id_orden
WHERE f.activo = 1;
GO

/* vw_HistorialReparaciones: reparaciones con su orden, equipo, tecnico y costo
   total de orden (mano de obra + repuestos). */
CREATE OR ALTER VIEW vw_HistorialReparaciones AS
SELECT
    rep.id_reparacion,
    o.id_orden,
    o.numero                      AS numero_orden,
    rep.estado                    AS estado_reparacion,
    rep.fecha_inicio,
    rep.fecha_fin,
    e.serie,
    me.nombre                     AS marca,
    te.nombre                     AS tipo_equipo,
    u.nombres + ' ' + u.apellidos AS tecnico,
    rep.costo_mano_obra,
    dbo.fn_TotalOrden(o.id_orden) AS total_orden
FROM Reparacion rep
INNER JOIN OrdenServicio o  ON o.id_orden       = rep.id_orden
INNER JOIN Equipo     e     ON e.id_equipo      = o.id_equipo
INNER JOIN TipoEquipo te    ON te.id_tipo_equipo = e.id_tipo_equipo
INNER JOIN MarcaEquipo me   ON me.id_marca      = e.id_marca
INNER JOIN Usuario    u     ON u.id_usuario     = rep.id_tecnico
WHERE rep.activo = 1;
GO


/* ============================================================================
   D. PROCEDIMIENTOS ALMACENADOS
   ============================================================================ */

/* ----------------------------------------------------------------------------
   D.1  usp_RegistrarCompraRepuesto   (PROCESO DE NEGOCIO - el ejemplo pedido)

   Registra la compra de UN repuesto a un proveedor. En una sola transaccion:
     1. Valida proveedor, bodega, repuesto, cantidad y costo.
     2. Crea Compra y recupera el id generado.
     3. Inserta DetalleCompra con costo historico.
     4. Aumenta Inventario (crea el registro si no existe).
     5. Registra MovimientoInventario tipo ENTRADA con existencia resultante.
   Usa TRY/CATCH, TRANSACTION, ROLLBACK y THROW.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE usp_RegistrarCompraRepuesto
    @id_proveedor    INT,
    @id_bodega       INT,
    @id_usuario      INT,
    @id_repuesto     INT,
    @cantidad        INT,
    @costo_unitario  DECIMAL(10,2),
    @id_compra       INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;      -- cualquier error aborta la transaccion

    BEGIN TRY
        /* 1. Validaciones de existencia y de dominio ------------------------ */
        IF @cantidad IS NULL OR @cantidad <= 0
            THROW 51001, 'La cantidad debe ser mayor que cero.', 1;

        IF @costo_unitario IS NULL OR @costo_unitario < 0
            THROW 51002, 'El costo unitario no puede ser negativo.', 1;

        IF NOT EXISTS (SELECT 1 FROM Proveedor WHERE id_proveedor = @id_proveedor AND activo = 1)
            THROW 51003, 'El proveedor no existe o esta inactivo.', 1;

        IF NOT EXISTS (SELECT 1 FROM Bodega WHERE id_bodega = @id_bodega AND activo = 1)
            THROW 51004, 'La bodega no existe o esta inactiva.', 1;

        IF NOT EXISTS (SELECT 1 FROM Repuesto WHERE id_repuesto = @id_repuesto AND activo = 1)
            THROW 51005, 'El repuesto no existe o esta inactivo.', 1;

        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE id_usuario = @id_usuario AND activo = 1)
            THROW 51006, 'El usuario no existe o esta inactivo.', 1;

        DECLARE @total DECIMAL(12,2) = @cantidad * @costo_unitario;

        BEGIN TRANSACTION;

        /* 2. Crear Compra y recuperar el id generado ------------------------ */
        DECLARE @correlativo INT = (SELECT ISNULL(MAX(id_compra), 0) + 1 FROM Compra);
        DECLARE @numero NVARCHAR(20) = 'COMP-' + RIGHT('000000' + CAST(@correlativo AS VARCHAR(6)), 6);

        INSERT INTO Compra (numero, id_proveedor, id_usuario, id_bodega, estado, total)
        VALUES (@numero, @id_proveedor, @id_usuario, @id_bodega, 'RECIBIDA', @total);

        SET @id_compra = SCOPE_IDENTITY();

        /* 3. Insertar DetalleCompra con el costo historico ------------------ */
        INSERT INTO DetalleCompra (id_compra, id_repuesto, cantidad, costo_historico)
        VALUES (@id_compra, @id_repuesto, @cantidad, @costo_unitario);

        /* 4. Aumentar Inventario (crear el registro si aun no existe) ------- */
        DECLARE @existencia_final INT;

        IF EXISTS (SELECT 1 FROM Inventario WHERE id_repuesto = @id_repuesto AND id_bodega = @id_bodega)
        BEGIN
            UPDATE Inventario
            SET existencia = existencia + @cantidad
            WHERE id_repuesto = @id_repuesto AND id_bodega = @id_bodega;

            SELECT @existencia_final = existencia
            FROM Inventario
            WHERE id_repuesto = @id_repuesto AND id_bodega = @id_bodega;
        END
        ELSE
        BEGIN
            INSERT INTO Inventario (id_repuesto, id_bodega, existencia, stock_minimo)
            VALUES (@id_repuesto, @id_bodega, @cantidad, 0);

            SET @existencia_final = @cantidad;
        END

        /* 5. Registrar MovimientoInventario ENTRADA ------------------------- */
        INSERT INTO MovimientoInventario
            (id_repuesto, id_bodega, tipo, cantidad, id_usuario,
             doc_tipo, doc_referencia, existencia_resultante)
        VALUES
            (@id_repuesto, @id_bodega, 'ENTRADA', @cantidad, @id_usuario,
             'COMPRA', @id_compra, @existencia_final);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;   -- relanza el error al backend conservando numero y mensaje
    END CATCH
END;
GO


/* ----------------------------------------------------------------------------
   D.2  usp_ConsumirRepuesto   (PROCESO DE NEGOCIO)

   Consume un repuesto dentro de una reparacion. En una transaccion:
     - valida reparacion, repuesto, bodega, cantidad y existencia suficiente,
     - inserta ReparacionRepuesto con precio historico (precio de venta actual),
     - descuenta Inventario,
     - registra MovimientoInventario tipo SALIDA.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE usp_ConsumirRepuesto
    @id_reparacion INT,
    @id_repuesto   INT,
    @id_bodega     INT,
    @cantidad      INT,
    @id_usuario    INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF @cantidad IS NULL OR @cantidad <= 0
            THROW 52001, 'La cantidad debe ser mayor que cero.', 1;

        IF NOT EXISTS (SELECT 1 FROM Reparacion WHERE id_reparacion = @id_reparacion AND activo = 1)
            THROW 52002, 'La reparacion no existe o esta inactiva.', 1;

        IF NOT EXISTS (SELECT 1 FROM Repuesto WHERE id_repuesto = @id_repuesto AND activo = 1)
            THROW 52003, 'El repuesto no existe o esta inactivo.', 1;

        IF NOT EXISTS (SELECT 1 FROM Bodega WHERE id_bodega = @id_bodega AND activo = 1)
            THROW 52004, 'La bodega no existe o esta inactiva.', 1;

        IF EXISTS (SELECT 1 FROM ReparacionRepuesto
                   WHERE id_reparacion = @id_reparacion AND id_repuesto = @id_repuesto)
            THROW 52005, 'Ese repuesto ya fue registrado en esta reparacion.', 1;

        DECLARE @existencia INT;
        SELECT @existencia = existencia
        FROM Inventario
        WHERE id_repuesto = @id_repuesto AND id_bodega = @id_bodega AND activo = 1;

        IF @existencia IS NULL
            THROW 52006, 'El repuesto no tiene inventario en esa bodega.', 1;

        IF @existencia < @cantidad
            THROW 52007, 'Existencia insuficiente para el consumo solicitado.', 1;

        DECLARE @precio DECIMAL(10,2) = (SELECT precio_venta FROM Repuesto WHERE id_repuesto = @id_repuesto);

        BEGIN TRANSACTION;

        INSERT INTO ReparacionRepuesto (id_reparacion, id_repuesto, id_bodega, cantidad, precio_historico)
        VALUES (@id_reparacion, @id_repuesto, @id_bodega, @cantidad, @precio);

        UPDATE Inventario
        SET existencia = existencia - @cantidad
        WHERE id_repuesto = @id_repuesto AND id_bodega = @id_bodega;

        DECLARE @existencia_final INT = @existencia - @cantidad;

        INSERT INTO MovimientoInventario
            (id_repuesto, id_bodega, tipo, cantidad, id_usuario,
             doc_tipo, doc_referencia, existencia_resultante)
        VALUES
            (@id_repuesto, @id_bodega, 'SALIDA', @cantidad, @id_usuario,
             'REPARACION', @id_reparacion, @existencia_final);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


/* ----------------------------------------------------------------------------
   D.3  usp_GenerarFactura   (PROCESO DE NEGOCIO)

   Genera la factura de una orden LISTA. Calcula subtotal (mano de obra +
   repuestos), impuesto (12%) y total; inserta Factura (1:1 con la orden) y
   sus lineas de DetalleFactura. Todo en una transaccion.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE usp_GenerarFactura
    @id_orden   INT,
    @id_usuario INT,
    @id_factura INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        DECLARE @estado NVARCHAR(25);
        SELECT @estado = estado FROM OrdenServicio WHERE id_orden = @id_orden AND activo = 1;

        IF @estado IS NULL
            THROW 53001, 'La orden no existe o esta inactiva.', 1;

        IF @estado <> 'LISTO'
            THROW 53002, 'Solo se factura una orden en estado LISTO.', 1;

        IF EXISTS (SELECT 1 FROM Factura WHERE id_orden = @id_orden AND activo = 1)
            THROW 53003, 'La orden ya tiene una factura emitida.', 1;

        DECLARE @subtotal DECIMAL(12,2) = dbo.fn_TotalOrden(@id_orden);
        DECLARE @impuesto DECIMAL(12,2) = ROUND(@subtotal * 0.12, 2);
        DECLARE @total    DECIMAL(12,2) = @subtotal + @impuesto;

        /* Datos de facturacion tomados del cliente de la orden */
        DECLARE @nit NVARCHAR(20), @nombre NVARCHAR(150);
        SELECT
            @nit = c.nit,
            @nombre = CASE c.tipo
                        WHEN 'INDIVIDUAL'  THEN c.nombres + ' ' + c.apellidos
                        WHEN 'EMPRESARIAL' THEN c.razon_social
                      END
        FROM OrdenServicio o
        INNER JOIN Cliente c ON c.id_cliente = o.id_cliente
        WHERE o.id_orden = @id_orden;

        BEGIN TRANSACTION;

        DECLARE @correlativo INT = (SELECT ISNULL(MAX(id_factura), 0) + 1 FROM Factura);
        DECLARE @numero NVARCHAR(20) = 'FAC-' + RIGHT('000000' + CAST(@correlativo AS VARCHAR(6)), 6);

        INSERT INTO Factura (numero, id_orden, nit, nombre_facturacion, subtotal, impuesto, total, estado)
        VALUES (@numero, @id_orden, @nit, @nombre, @subtotal, @impuesto, @total, 'EMITIDA');

        SET @id_factura = SCOPE_IDENTITY();

        /* Lineas de mano de obra (una por reparacion con costo > 0) */
        INSERT INTO DetalleFactura (id_factura, tipo, descripcion, cantidad, precio_historico, subtotal)
        SELECT @id_factura, 'MANO_OBRA',
               'Mano de obra reparacion #' + CAST(r.id_reparacion AS VARCHAR(10)),
               1, r.costo_mano_obra, r.costo_mano_obra
        FROM Reparacion r
        WHERE r.id_orden = @id_orden AND r.activo = 1 AND r.costo_mano_obra > 0;

        /* Lineas de repuestos consumidos */
        INSERT INTO DetalleFactura (id_factura, tipo, descripcion, cantidad, precio_historico, subtotal)
        SELECT @id_factura, 'REPUESTO', rep.nombre,
               rr.cantidad, rr.precio_historico, rr.cantidad * rr.precio_historico
        FROM ReparacionRepuesto rr
        INNER JOIN Reparacion r  ON r.id_reparacion = rr.id_reparacion
        INNER JOIN Repuesto   rep ON rep.id_repuesto = rr.id_repuesto
        WHERE r.id_orden = @id_orden AND rr.activo = 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


/* ----------------------------------------------------------------------------
   D.4  usp_RegistrarPago   (PROCESO DE NEGOCIO)

   Registra un pago sobre una factura sin que la suma de pagos exceda el total
   (usa fn_SaldoFactura). Valida factura, metodo y monto.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE usp_RegistrarPago
    @id_factura INT,
    @id_metodo  INT,
    @monto      DECIMAL(12,2),
    @referencia NVARCHAR(50) = NULL,
    @id_pago    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF @monto IS NULL OR @monto <= 0
            THROW 54001, 'El monto debe ser mayor que cero.', 1;

        DECLARE @estado NVARCHAR(15);
        SELECT @estado = estado FROM Factura WHERE id_factura = @id_factura AND activo = 1;

        IF @estado IS NULL
            THROW 54002, 'La factura no existe o esta inactiva.', 1;

        IF @estado <> 'EMITIDA'
            THROW 54003, 'Solo se pueden pagar facturas en estado EMITIDA.', 1;

        IF NOT EXISTS (SELECT 1 FROM MetodoPago WHERE id_metodo = @id_metodo AND activo = 1)
            THROW 54004, 'El metodo de pago no existe o esta inactivo.', 1;

        DECLARE @saldo DECIMAL(12,2) = dbo.fn_SaldoFactura(@id_factura);

        IF @monto > @saldo
            THROW 54005, 'El monto excede el saldo pendiente de la factura.', 1;

        BEGIN TRANSACTION;

        INSERT INTO Pago (id_factura, id_metodo, monto, referencia)
        VALUES (@id_factura, @id_metodo, @monto, @referencia);

        SET @id_pago = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


/* ----------------------------------------------------------------------------
   D.5  usp_CrearOrdenServicio   (proceso de apoyo)

   Crea una orden con numero correlativo, estado inicial RECIBIDO, y registra
   la primera fila de historial de estado.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE usp_CrearOrdenServicio
    @id_cliente           INT,
    @id_equipo            INT,
    @id_usuario_recepcion INT,
    @problema             NVARCHAR(500),
    @prioridad            NVARCHAR(15) = 'MEDIA',
    @fecha_estimada       DATE = NULL,
    @id_orden             INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM Cliente WHERE id_cliente = @id_cliente AND activo = 1)
            THROW 55001, 'El cliente no existe o esta inactivo.', 1;

        /* El equipo debe pertenecer al cliente indicado */
        IF NOT EXISTS (SELECT 1 FROM Equipo WHERE id_equipo = @id_equipo AND id_cliente = @id_cliente AND activo = 1)
            THROW 55002, 'El equipo no existe o no pertenece al cliente.', 1;

        IF @prioridad NOT IN ('ALTA', 'MEDIA', 'BAJA')
            THROW 55003, 'Prioridad invalida.', 1;

        BEGIN TRANSACTION;

        DECLARE @correlativo INT = (SELECT ISNULL(MAX(id_orden), 0) + 1 FROM OrdenServicio);
        DECLARE @numero NVARCHAR(20) = 'ORD-' + RIGHT('000000' + CAST(@correlativo AS VARCHAR(6)), 6);

        INSERT INTO OrdenServicio
            (numero, id_cliente, id_equipo, id_usuario_recepcion, problema, prioridad, estado, fecha_estimada)
        VALUES
            (@numero, @id_cliente, @id_equipo, @id_usuario_recepcion, @problema, @prioridad, 'RECIBIDO', @fecha_estimada);

        SET @id_orden = SCOPE_IDENTITY();

        /* Primera fila de historial (estado inicial, sin estado anterior) */
        INSERT INTO HistorialEstadoOrden (id_orden, estado_anterior, estado_nuevo, id_usuario, observacion)
        VALUES (@id_orden, NULL, 'RECIBIDO', @id_usuario_recepcion, 'Creacion de la orden');

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


/* ----------------------------------------------------------------------------
   D.6  usp_CambiarEstadoOrden   (proceso de apoyo)

   Cambia el estado de una orden validando transiciones. Pasa el id_usuario a
   SESSION_CONTEXT para que el trigger de auditoria registre quien hizo el
   cambio en HistorialEstadoOrden.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE usp_CambiarEstadoOrden
    @id_orden     INT,
    @estado_nuevo NVARCHAR(25),
    @id_usuario   INT,
    @observacion  NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        DECLARE @estado_actual NVARCHAR(25);
        SELECT @estado_actual = estado FROM OrdenServicio WHERE id_orden = @id_orden AND activo = 1;

        IF @estado_actual IS NULL
            THROW 56001, 'La orden no existe o esta inactiva.', 1;

        IF @estado_nuevo NOT IN
            ('RECIBIDO','DIAGNOSTICO','ESPERANDO_AUTORIZACION','REPARACION','LISTO','ENTREGADO','CANCELADO')
            THROW 56002, 'Estado destino invalido.', 1;

        IF @estado_actual IN ('ENTREGADO','CANCELADO')
            THROW 56003, 'Una orden entregada o cancelada ya no cambia de estado.', 1;

        IF @estado_actual = @estado_nuevo
            THROW 56004, 'La orden ya se encuentra en ese estado.', 1;

        /* La entrega tiene su propio proceso (valida factura y saldo): usp_EntregarOrden */
        IF @estado_nuevo = 'ENTREGADO'
            THROW 56005, 'Para entregar la orden use el proceso de entrega (valida factura y saldo).', 1;

        /* R04: no se pasa a REPARACION sin diagnostico previo */
        IF @estado_nuevo = 'REPARACION'
           AND NOT EXISTS (SELECT 1 FROM Diagnostico WHERE id_orden = @id_orden AND activo = 1)
            THROW 56006, 'La orden no puede pasar a REPARACION sin un diagnostico previo (R04).', 1;

        /* Una orden queda LISTA solo si tiene al menos una reparacion finalizada */
        IF @estado_nuevo = 'LISTO'
           AND NOT EXISTS (SELECT 1 FROM Reparacion WHERE id_orden = @id_orden AND activo = 1 AND estado = 'FINALIZADA')
            THROW 56007, 'La orden solo puede pasar a LISTO con al menos una reparacion finalizada.', 1;

        /* No se cancela una orden que ya tiene factura emitida */
        IF @estado_nuevo = 'CANCELADO'
           AND EXISTS (SELECT 1 FROM Factura WHERE id_orden = @id_orden AND activo = 1 AND estado = 'EMITIDA')
            THROW 56008, 'No se puede cancelar una orden con factura emitida.', 1;

        /* El trigger de auditoria leera este valor para saber quien cambio el estado */
        EXEC sp_set_session_context @key = N'id_usuario', @value = @id_usuario;
        EXEC sp_set_session_context @key = N'obs_estado', @value = @observacion;

        BEGIN TRANSACTION;

        UPDATE OrdenServicio
        SET estado = @estado_nuevo
        WHERE id_orden = @id_orden;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


/* ----------------------------------------------------------------------------
   D.7  usp_RegistrarDiagnostico   (proceso: registro de diagnostico)

   Registra el diagnostico de una orden. Valida que el responsable sea un
   tecnico autorizado (R03). Si la orden estaba RECIBIDO, la pasa a
   DIAGNOSTICO (el trigger de auditoria registra el cambio).
   ---------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE usp_RegistrarDiagnostico
    @id_orden        INT,
    @id_tecnico      INT,
    @descripcion     NVARCHAR(500),
    @costo_mano_obra DECIMAL(10,2) = 0,
    @id_diagnostico  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        DECLARE @estado NVARCHAR(25);
        SELECT @estado = estado FROM OrdenServicio WHERE id_orden = @id_orden AND activo = 1;

        IF @estado IS NULL
            THROW 58001, 'La orden no existe o esta inactiva.', 1;

        IF @estado IN ('LISTO', 'ENTREGADO', 'CANCELADO')
            THROW 58002, 'No se puede diagnosticar una orden lista, entregada o cancelada.', 1;

        IF NOT EXISTS (SELECT 1 FROM Usuario u INNER JOIN Rol r ON r.id_rol = u.id_rol
                       WHERE u.id_usuario = @id_tecnico AND u.activo = 1
                         AND r.nombre IN ('Tecnico', 'Administrador'))
            THROW 58003, 'El responsable no es un tecnico autorizado (R03).', 1;

        IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
            THROW 58004, 'La descripcion del diagnostico es obligatoria.', 1;

        IF @costo_mano_obra IS NULL OR @costo_mano_obra < 0
            THROW 58005, 'El costo de mano de obra no puede ser negativo.', 1;

        BEGIN TRANSACTION;

        INSERT INTO Diagnostico (id_orden, id_tecnico, descripcion, costo_mano_obra)
        VALUES (@id_orden, @id_tecnico, @descripcion, @costo_mano_obra);

        SET @id_diagnostico = SCOPE_IDENTITY();

        IF @estado = 'RECIBIDO'
        BEGIN
            EXEC sp_set_session_context @key = N'id_usuario', @value = @id_tecnico;
            EXEC sp_set_session_context @key = N'obs_estado', @value = N'Diagnostico registrado';
            UPDATE OrdenServicio SET estado = 'DIAGNOSTICO' WHERE id_orden = @id_orden;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


/* ----------------------------------------------------------------------------
   D.8  usp_IniciarReparacion   (proceso: inicio de reparacion)

   Abre una reparacion para una orden. Aplica R04: exige orden valida y un
   diagnostico previo. Aplica R03: el responsable debe ser tecnico autorizado.
   Si la orden no estaba en REPARACION, la pasa a ese estado (con historial).
   ---------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE usp_IniciarReparacion
    @id_orden        INT,
    @id_tecnico      INT,
    @descripcion     NVARCHAR(500) = NULL,
    @costo_mano_obra DECIMAL(10,2) = 0,
    @id_reparacion   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        DECLARE @estado NVARCHAR(25);
        SELECT @estado = estado FROM OrdenServicio WHERE id_orden = @id_orden AND activo = 1;

        IF @estado IS NULL
            THROW 59001, 'La orden no existe o esta inactiva.', 1;

        IF @estado IN ('LISTO', 'ENTREGADO', 'CANCELADO')
            THROW 59002, 'No se puede iniciar una reparacion en una orden lista, entregada o cancelada.', 1;

        IF NOT EXISTS (SELECT 1 FROM Diagnostico WHERE id_orden = @id_orden AND activo = 1)
            THROW 59003, 'No se puede registrar una reparacion sin un diagnostico previo (R04).', 1;

        IF NOT EXISTS (SELECT 1 FROM Usuario u INNER JOIN Rol r ON r.id_rol = u.id_rol
                       WHERE u.id_usuario = @id_tecnico AND u.activo = 1
                         AND r.nombre IN ('Tecnico', 'Administrador'))
            THROW 59004, 'El responsable no es un tecnico autorizado (R03).', 1;

        IF @costo_mano_obra IS NULL OR @costo_mano_obra < 0
            THROW 59005, 'El costo de mano de obra no puede ser negativo.', 1;

        BEGIN TRANSACTION;

        INSERT INTO Reparacion (id_orden, id_tecnico, fecha_inicio, descripcion, costo_mano_obra, estado)
        VALUES (@id_orden, @id_tecnico, SYSDATETIME(), @descripcion, @costo_mano_obra, 'EN_PROCESO');

        SET @id_reparacion = SCOPE_IDENTITY();

        IF @estado <> 'REPARACION'
        BEGIN
            EXEC sp_set_session_context @key = N'id_usuario', @value = @id_tecnico;
            EXEC sp_set_session_context @key = N'obs_estado', @value = N'Inicio de reparacion';
            UPDATE OrdenServicio SET estado = 'REPARACION' WHERE id_orden = @id_orden;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


/* ----------------------------------------------------------------------------
   D.9  usp_FinalizarReparacion   (proceso: cierre de reparacion)

   Cierra una reparacion (FINALIZADA + fecha_fin). Si ya no quedan reparaciones
   abiertas en la orden y esta seguia en REPARACION, la pasa a LISTO.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE usp_FinalizarReparacion
    @id_reparacion INT,
    @id_usuario    INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        DECLARE @id_orden INT, @estado_rep NVARCHAR(20);
        SELECT @id_orden = id_orden, @estado_rep = estado
        FROM Reparacion WHERE id_reparacion = @id_reparacion AND activo = 1;

        IF @id_orden IS NULL
            THROW 60001, 'La reparacion no existe o esta inactiva.', 1;

        IF @estado_rep NOT IN ('PENDIENTE', 'EN_PROCESO')
            THROW 60002, 'Solo se puede finalizar una reparacion pendiente o en proceso.', 1;

        BEGIN TRANSACTION;

        UPDATE Reparacion
        SET estado = 'FINALIZADA',
            fecha_inicio = ISNULL(fecha_inicio, SYSDATETIME()),
            fecha_fin = SYSDATETIME()
        WHERE id_reparacion = @id_reparacion;

        IF NOT EXISTS (SELECT 1 FROM Reparacion
                       WHERE id_orden = @id_orden AND activo = 1
                         AND estado IN ('PENDIENTE', 'EN_PROCESO'))
           AND EXISTS (SELECT 1 FROM OrdenServicio WHERE id_orden = @id_orden AND estado = 'REPARACION')
        BEGIN
            EXEC sp_set_session_context @key = N'id_usuario', @value = @id_usuario;
            EXEC sp_set_session_context @key = N'obs_estado', @value = N'Reparacion finalizada';
            UPDATE OrdenServicio SET estado = 'LISTO' WHERE id_orden = @id_orden;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


/* ----------------------------------------------------------------------------
   D.10 usp_EntregarOrden   (proceso: entrega y cierre de la orden)

   Cierra la orden validando reglas de negocio y financieras (2.7 / 2.8):
     - la orden debe estar LISTO y no haber sido entregada,
     - debe tener factura emitida,
     - la factura NO puede tener saldo pendiente (fn_SaldoFactura = 0).
   Registra la Entrega y pasa la orden a ENTREGADO (con historial).
   ---------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE usp_EntregarOrden
    @id_orden      INT,
    @id_usuario    INT,
    @recibe        NVARCHAR(100),
    @observaciones NVARCHAR(300) = NULL,
    @id_entrega    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        DECLARE @estado NVARCHAR(25), @id_factura INT;
        SELECT @estado = estado FROM OrdenServicio WHERE id_orden = @id_orden AND activo = 1;

        IF @estado IS NULL
            THROW 61001, 'La orden no existe o esta inactiva.', 1;

        IF EXISTS (SELECT 1 FROM Entrega WHERE id_orden = @id_orden)
            THROW 61002, 'La orden ya fue entregada.', 1;

        IF @estado <> 'LISTO'
            THROW 61003, 'Solo se puede entregar una orden en estado LISTO.', 1;

        SELECT @id_factura = id_factura FROM Factura
        WHERE id_orden = @id_orden AND activo = 1 AND estado = 'EMITIDA';

        IF @id_factura IS NULL
            THROW 61004, 'La orden no tiene factura emitida; debe facturarse antes de entregar.', 1;

        IF dbo.fn_SaldoFactura(@id_factura) > 0
            THROW 61005, 'No se puede entregar: la factura tiene saldo pendiente.', 1;

        IF @recibe IS NULL OR LTRIM(RTRIM(@recibe)) = ''
            THROW 61006, 'Debe indicar quien recibe el equipo.', 1;

        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE id_usuario = @id_usuario AND activo = 1)
            THROW 61007, 'El usuario no existe o esta inactivo.', 1;

        BEGIN TRANSACTION;

        INSERT INTO Entrega (id_orden, id_usuario_entrega, recibe, observaciones)
        VALUES (@id_orden, @id_usuario, @recibe, @observaciones);

        SET @id_entrega = SCOPE_IDENTITY();

        EXEC sp_set_session_context @key = N'id_usuario', @value = @id_usuario;
        EXEC sp_set_session_context @key = N'obs_estado', @value = N'Entrega al cliente';
        UPDATE OrdenServicio SET estado = 'ENTREGADO' WHERE id_orden = @id_orden;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


/* ----------------------------------------------------------------------------
   D.11 usp_RegistrarCompra   (proceso: registro de compra con varios repuestos)

   Registra el ENCABEZADO (Compra, estado PENDIENTE) y su DETALLE (varios
   repuestos con costo historico) en una sola transaccion. El detalle llega
   como JSON:  [{"id_repuesto":1,"cantidad":5,"costo":120.50}, ...]
   El inventario NO cambia aqui: cambia al recibirla (usp_RecibirCompra).
   ---------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE usp_RegistrarCompra
    @id_proveedor INT,
    @id_bodega    INT,
    @id_usuario   INT,
    @detalle      NVARCHAR(MAX),
    @id_compra    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM Proveedor WHERE id_proveedor = @id_proveedor AND activo = 1)
            THROW 62001, 'El proveedor no existe o esta inactivo.', 1;

        IF NOT EXISTS (SELECT 1 FROM Bodega WHERE id_bodega = @id_bodega AND activo = 1)
            THROW 62002, 'La bodega no existe o esta inactiva.', 1;

        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE id_usuario = @id_usuario AND activo = 1)
            THROW 62003, 'El usuario no existe o esta inactivo.', 1;

        IF @detalle IS NULL OR ISJSON(@detalle) = 0
            THROW 62004, 'El detalle de la compra no tiene un formato valido.', 1;

        DECLARE @lineas TABLE (id_repuesto INT, cantidad INT, costo DECIMAL(10,2));

        INSERT INTO @lineas (id_repuesto, cantidad, costo)
        SELECT id_repuesto, cantidad, costo
        FROM OPENJSON(@detalle)
        WITH (id_repuesto INT '$.id_repuesto',
              cantidad    INT '$.cantidad',
              costo       DECIMAL(10,2) '$.costo');

        IF NOT EXISTS (SELECT 1 FROM @lineas)
            THROW 62005, 'La compra debe tener al menos un repuesto.', 1;

        IF EXISTS (SELECT 1 FROM @lineas WHERE cantidad IS NULL OR cantidad <= 0)
            THROW 62006, 'Todas las cantidades deben ser mayores que cero.', 1;

        IF EXISTS (SELECT 1 FROM @lineas WHERE costo IS NULL OR costo < 0)
            THROW 62007, 'Los costos no pueden ser negativos.', 1;

        IF EXISTS (SELECT id_repuesto FROM @lineas GROUP BY id_repuesto HAVING COUNT(*) > 1)
            THROW 62008, 'Un repuesto no puede repetirse en la misma compra.', 1;

        IF EXISTS (SELECT 1 FROM @lineas l
                   LEFT JOIN Repuesto r ON r.id_repuesto = l.id_repuesto AND r.activo = 1
                   WHERE r.id_repuesto IS NULL)
            THROW 62009, 'Uno de los repuestos no existe o esta inactivo.', 1;

        DECLARE @total DECIMAL(12,2);
        SELECT @total = SUM(cantidad * costo) FROM @lineas;

        BEGIN TRANSACTION;

        DECLARE @correlativo INT = (SELECT ISNULL(MAX(id_compra), 0) + 1 FROM Compra);
        DECLARE @numero NVARCHAR(20) = 'COMP-' + RIGHT('000000' + CAST(@correlativo AS VARCHAR(6)), 6);

        INSERT INTO Compra (numero, id_proveedor, id_usuario, id_bodega, estado, total)
        VALUES (@numero, @id_proveedor, @id_usuario, @id_bodega, 'PENDIENTE', @total);

        SET @id_compra = SCOPE_IDENTITY();

        INSERT INTO DetalleCompra (id_compra, id_repuesto, cantidad, costo_historico)
        SELECT @id_compra, id_repuesto, cantidad, costo FROM @lineas;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


/* ----------------------------------------------------------------------------
   D.12 usp_RecibirCompra   (proceso: recepcion de compra en inventario)

   Recibe una compra PENDIENTE. En UNA transaccion (2.6 / R08):
     - crea el registro de inventario si el repuesto no existia en la bodega,
     - aumenta la existencia de cada repuesto del detalle,
     - registra un MovimientoInventario ENTRADA por renglon con su saldo,
     - marca la compra como RECIBIDA.
   Si algo falla, no queda nada aplicado (ROLLBACK).
   ---------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE usp_RecibirCompra
    @id_compra  INT,
    @id_usuario INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        DECLARE @estado NVARCHAR(15), @id_bodega INT;
        SELECT @estado = estado, @id_bodega = id_bodega
        FROM Compra WHERE id_compra = @id_compra AND activo = 1;

        IF @estado IS NULL
            THROW 63001, 'La compra no existe o esta inactiva.', 1;

        IF @estado <> 'PENDIENTE'
            THROW 63002, 'Solo se puede recibir una compra en estado PENDIENTE.', 1;

        IF NOT EXISTS (SELECT 1 FROM DetalleCompra WHERE id_compra = @id_compra AND activo = 1)
            THROW 63003, 'La compra no tiene detalle de repuestos.', 1;

        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE id_usuario = @id_usuario AND activo = 1)
            THROW 63004, 'El usuario no existe o esta inactivo.', 1;

        BEGIN TRANSACTION;

        /* 1. Crear inventario para los repuestos que aun no existian en la bodega */
        INSERT INTO Inventario (id_repuesto, id_bodega, existencia, stock_minimo)
        SELECT d.id_repuesto, @id_bodega, 0, 0
        FROM DetalleCompra d
        WHERE d.id_compra = @id_compra AND d.activo = 1
          AND NOT EXISTS (SELECT 1 FROM Inventario i
                          WHERE i.id_repuesto = d.id_repuesto AND i.id_bodega = @id_bodega);

        /* 2. Aumentar existencias */
        UPDATE i
        SET i.existencia = i.existencia + d.cantidad
        FROM Inventario i
        INNER JOIN DetalleCompra d ON d.id_repuesto = i.id_repuesto
        WHERE d.id_compra = @id_compra AND d.activo = 1 AND i.id_bodega = @id_bodega;

        /* 3. Movimiento de ENTRADA por renglon, con la existencia resultante */
        INSERT INTO MovimientoInventario
            (id_repuesto, id_bodega, tipo, cantidad, id_usuario, doc_tipo, doc_referencia, existencia_resultante)
        SELECT d.id_repuesto, @id_bodega, 'ENTRADA', d.cantidad, @id_usuario, 'COMPRA', @id_compra, i.existencia
        FROM DetalleCompra d
        INNER JOIN Inventario i ON i.id_repuesto = d.id_repuesto AND i.id_bodega = @id_bodega
        WHERE d.id_compra = @id_compra AND d.activo = 1;

        /* 4. Marcar la compra como recibida */
        UPDATE Compra SET estado = 'RECIBIDA' WHERE id_compra = @id_compra;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


/* ============================================================================
   E. TRIGGERS
   ============================================================================ */

/* ----------------------------------------------------------------------------
   E.1  trg_Orden_AuditoriaEstado  (AUDITORIA)

   Despues de actualizar OrdenServicio, si cambio el estado, registra el cambio
   en HistorialEstadoOrden. Toma el id_usuario y la observacion de SESSION_CONTEXT
   (los fija usp_CambiarEstadoOrden); si no viene, usa el recepcionista de la orden.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER trg_Orden_AuditoriaEstado
ON OrdenServicio
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(estado)
        RETURN;

    DECLARE @id_usuario INT =
        TRY_CAST(SESSION_CONTEXT(N'id_usuario') AS INT);
    DECLARE @obs NVARCHAR(300) =
        TRY_CAST(SESSION_CONTEXT(N'obs_estado') AS NVARCHAR(300));

    INSERT INTO HistorialEstadoOrden (id_orden, estado_anterior, estado_nuevo, id_usuario, observacion)
    SELECT
        i.id_orden,
        d.estado,
        i.estado,
        ISNULL(@id_usuario, i.id_usuario_recepcion),
        @obs
    FROM inserted i
    INNER JOIN deleted d ON d.id_orden = i.id_orden
    WHERE i.estado <> d.estado;   -- solo cuando realmente cambio
END;
GO

/* ----------------------------------------------------------------------------
   E.2  trg_Factura_ProtegerAnulacion  (PROTECCION)

   Impide anular una factura que ya tiene pagos registrados. Protege la
   integridad contable aunque alguien intente el UPDATE directamente en SQL.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER trg_Factura_ProtegerAnulacion
ON Factura
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(estado)
        RETURN;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN deleted d ON d.id_factura = i.id_factura
        WHERE d.estado = 'EMITIDA'
          AND i.estado = 'ANULADA'
          AND EXISTS (SELECT 1 FROM Pago p WHERE p.id_factura = i.id_factura AND p.activo = 1)
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 57001, 'No se puede anular una factura con pagos registrados.', 1;
    END
END;
GO


/* ----------------------------------------------------------------------------
   E.3  trg_Reparacion_RequiereDiagnostico  (PROTECCION - R04 / R16)

   Impide registrar una reparacion si la orden no tiene diagnostico previo,
   incluso cuando se intenta insertar directamente desde SQL Server (R16).
   ---------------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER trg_Reparacion_RequiereDiagnostico
ON Reparacion
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE NOT EXISTS (SELECT 1 FROM Diagnostico d
                          WHERE d.id_orden = i.id_orden AND d.activo = 1)
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 57002, 'No se puede registrar una reparacion sin un diagnostico previo (R04).', 1;
    END
END;
GO


/* ============================================================================
   FIN SECCION 02 - LOGICA
     Indices: 8   Funciones: 2   Vistas: 4   Procedimientos: 12   Triggers: 3
   ============================================================================ */
