/* ============================================================================
   PROYECTO FINAL - BASE DE DATOS I
   Sistema Integral de Servicio Tecnico, Inventario y Facturacion
   TechCare Solutions

   SECCION 01 - CREACION DE BASE DE DATOS Y TABLAS
   Motor: Microsoft SQL Server

   Contenido de esta seccion:
     - Creacion de la base de datos
     - 25 tablas con PK, FK, UNIQUE, DEFAULT y CHECK
     - 3 llaves primarias compuestas (Inventario, DetalleCompra,
       ReparacionRepuesto)
     - Eliminacion logica mediante columna 'activo' BIT en todas las tablas

   Convencion de nombres de restricciones:
     PK_  Llave primaria        FK_  Llave foranea
     UQ_  Restriccion UNIQUE     CK_  Restriccion CHECK
     DF_  Valor DEFAULT

   Nota sobre comportamiento de FK:
     La informacion transaccional NO se elimina fisicamente (R14); se maneja
     por eliminacion logica (activo) y por estados de negocio. Por ello las
     llaves foraneas se definen con NO ACTION (comportamiento por defecto):
     se impide borrar un padre referenciado, lo cual es la proteccion
     deseada. No se usa ON DELETE CASCADE para no destruir historia.
   ============================================================================ */

/* ------------------------------------------------------------------
   0. CREACION DE LA BASE DE DATOS
   ------------------------------------------------------------------ */
IF DB_ID('TechCareDB') IS NOT NULL
BEGIN
    ALTER DATABASE TechCareDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE TechCareDB;
END
GO

CREATE DATABASE TechCareDB;
GO

USE TechCareDB;
GO


/* ============================================================================
   1. TABLAS DE SEGURIDAD Y ACCESO
   ============================================================================ */

/* 1. Rol */
CREATE TABLE Rol (
    id_rol      INT IDENTITY(1,1) NOT NULL,
    nombre      NVARCHAR(30)      NOT NULL,
    activo      BIT               NOT NULL CONSTRAINT DF_Rol_activo DEFAULT 1,
    CONSTRAINT PK_Rol PRIMARY KEY (id_rol),
    CONSTRAINT UQ_Rol_nombre UNIQUE (nombre)
);
GO

/* 2. Usuario */
CREATE TABLE Usuario (
    id_usuario      INT IDENTITY(1,1) NOT NULL,
    id_rol          INT               NOT NULL,
    nombre_usuario  NVARCHAR(50)      NOT NULL,
    password_hash   VARCHAR(255)      NOT NULL,
    nombres         NVARCHAR(100)     NOT NULL,
    apellidos       NVARCHAR(100)     NOT NULL,
    activo          BIT               NOT NULL CONSTRAINT DF_Usuario_activo DEFAULT 1,
    CONSTRAINT PK_Usuario PRIMARY KEY (id_usuario),
    CONSTRAINT UQ_Usuario_nombre_usuario UNIQUE (nombre_usuario),
    CONSTRAINT FK_Usuario_Rol FOREIGN KEY (id_rol) REFERENCES Rol (id_rol)
);
GO


/* ============================================================================
   2. TABLAS DE CLIENTES Y EQUIPOS
   ============================================================================ */

/* 3. Cliente */
CREATE TABLE Cliente (
    id_cliente      INT IDENTITY(1,1) NOT NULL,
    tipo            NVARCHAR(15)      NOT NULL,
    nombres         NVARCHAR(100)     NULL,
    apellidos       NVARCHAR(100)     NULL,
    razon_social    NVARCHAR(150)     NULL,
    nit             VARCHAR(20)       NOT NULL,
    telefono        VARCHAR(20)       NULL,
    email           NVARCHAR(100)     NULL,
    direccion       NVARCHAR(200)     NULL,
    activo          BIT               NOT NULL CONSTRAINT DF_Cliente_activo DEFAULT 1,
    CONSTRAINT PK_Cliente PRIMARY KEY (id_cliente),
    CONSTRAINT UQ_Cliente_nit UNIQUE (nit),
    CONSTRAINT CK_Cliente_tipo CHECK (tipo IN ('INDIVIDUAL','EMPRESARIAL')),
    /* Un cliente INDIVIDUAL identifica por nombres+apellidos;
       un cliente EMPRESARIAL identifica por razon_social. */
    CONSTRAINT CK_Cliente_identidad CHECK (
        (tipo = 'INDIVIDUAL'  AND nombres IS NOT NULL AND apellidos IS NOT NULL AND razon_social IS NULL)
        OR
        (tipo = 'EMPRESARIAL' AND razon_social IS NOT NULL AND nombres IS NULL AND apellidos IS NULL)
    )
);
GO

/* 4a. MarcaEquipo (catalogo - Foco 2 opcion a) */
CREATE TABLE MarcaEquipo (
    id_marca    INT IDENTITY(1,1) NOT NULL,
    nombre      NVARCHAR(50)      NOT NULL,
    activo      BIT               NOT NULL CONSTRAINT DF_MarcaEquipo_activo DEFAULT 1,
    CONSTRAINT PK_MarcaEquipo PRIMARY KEY (id_marca),
    CONSTRAINT UQ_MarcaEquipo_nombre UNIQUE (nombre)
);
GO

/* 4b. TipoEquipo (catalogo - Foco 2 opcion a) */
CREATE TABLE TipoEquipo (
    id_tipo_equipo  INT IDENTITY(1,1) NOT NULL,
    nombre          NVARCHAR(50)      NOT NULL,
    activo          BIT               NOT NULL CONSTRAINT DF_TipoEquipo_activo DEFAULT 1,
    CONSTRAINT PK_TipoEquipo PRIMARY KEY (id_tipo_equipo),
    CONSTRAINT UQ_TipoEquipo_nombre UNIQUE (nombre)
);
GO

/* 4. Equipo */
CREATE TABLE Equipo (
    id_equipo       INT IDENTITY(1,1) NOT NULL,
    id_cliente      INT               NOT NULL,
    id_tipo_equipo  INT               NOT NULL,
    id_marca        INT               NOT NULL,
    modelo          NVARCHAR(50)      NULL,
    serie           NVARCHAR(50)      NOT NULL,
    descripcion     NVARCHAR(255)     NULL,
    estado          NVARCHAR(20)      NOT NULL CONSTRAINT DF_Equipo_estado DEFAULT 'OPERATIVO',
    activo          BIT               NOT NULL CONSTRAINT DF_Equipo_activo DEFAULT 1,
    CONSTRAINT PK_Equipo PRIMARY KEY (id_equipo),
    CONSTRAINT UQ_Equipo_serie UNIQUE (serie),
    CONSTRAINT CK_Equipo_estado CHECK (estado IN ('OPERATIVO','DANADO','EN_REPARACION','DESCONTINUADO')),
    CONSTRAINT FK_Equipo_Cliente    FOREIGN KEY (id_cliente)     REFERENCES Cliente (id_cliente),
    CONSTRAINT FK_Equipo_TipoEquipo FOREIGN KEY (id_tipo_equipo) REFERENCES TipoEquipo (id_tipo_equipo),
    CONSTRAINT FK_Equipo_MarcaEquipo FOREIGN KEY (id_marca)      REFERENCES MarcaEquipo (id_marca)
);
GO


/* ============================================================================
   3. TABLAS DE ORDENES DE SERVICIO
   ============================================================================ */

/* 5. OrdenServicio */
CREATE TABLE OrdenServicio (
    id_orden              INT IDENTITY(1,1) NOT NULL,
    numero                NVARCHAR(20)      NOT NULL,
    id_cliente            INT               NOT NULL,
    id_equipo             INT               NOT NULL,
    id_usuario_recepcion  INT               NOT NULL,
    fecha_ingreso         DATETIME2         NOT NULL CONSTRAINT DF_Orden_fecha_ingreso DEFAULT SYSDATETIME(),
    problema              NVARCHAR(500)     NOT NULL,
    prioridad             NVARCHAR(15)      NOT NULL CONSTRAINT DF_Orden_prioridad DEFAULT 'MEDIA',
    estado                NVARCHAR(25)      NOT NULL CONSTRAINT DF_Orden_estado DEFAULT 'RECIBIDO',
    fecha_estimada        DATE              NULL,
    observaciones         NVARCHAR(500)     NULL,
    activo                BIT               NOT NULL CONSTRAINT DF_Orden_activo DEFAULT 1,
    CONSTRAINT PK_OrdenServicio PRIMARY KEY (id_orden),
    CONSTRAINT UQ_Orden_numero UNIQUE (numero),
    CONSTRAINT CK_Orden_prioridad CHECK (prioridad IN ('ALTA','MEDIA','BAJA')),
    CONSTRAINT CK_Orden_estado CHECK (estado IN
        ('RECIBIDO','DIAGNOSTICO','ESPERANDO_AUTORIZACION','REPARACION','LISTO','ENTREGADO','CANCELADO')),
    CONSTRAINT FK_Orden_Cliente FOREIGN KEY (id_cliente)           REFERENCES Cliente (id_cliente),
    CONSTRAINT FK_Orden_Equipo  FOREIGN KEY (id_equipo)            REFERENCES Equipo (id_equipo),
    CONSTRAINT FK_Orden_Usuario FOREIGN KEY (id_usuario_recepcion) REFERENCES Usuario (id_usuario)
);
GO

/* 6. HistorialEstadoOrden */
CREATE TABLE HistorialEstadoOrden (
    id_historial     INT IDENTITY(1,1) NOT NULL,
    id_orden         INT               NOT NULL,
    estado_anterior  NVARCHAR(25)      NULL,
    estado_nuevo     NVARCHAR(25)      NOT NULL,
    fecha            DATETIME2         NOT NULL CONSTRAINT DF_HistOrden_fecha DEFAULT SYSDATETIME(),
    id_usuario       INT               NOT NULL,
    observacion      NVARCHAR(300)     NULL,
    activo           BIT               NOT NULL CONSTRAINT DF_HistOrden_activo DEFAULT 1,
    CONSTRAINT PK_HistorialEstadoOrden PRIMARY KEY (id_historial),
    CONSTRAINT FK_HistOrden_Orden   FOREIGN KEY (id_orden)   REFERENCES OrdenServicio (id_orden),
    CONSTRAINT FK_HistOrden_Usuario FOREIGN KEY (id_usuario) REFERENCES Usuario (id_usuario)
);
GO


/* ============================================================================
   4. TABLAS DE DIAGNOSTICO Y REPARACION
   ============================================================================ */

/* 7. Diagnostico */
CREATE TABLE Diagnostico (
    id_diagnostico   INT IDENTITY(1,1) NOT NULL,
    id_orden         INT               NOT NULL,
    id_tecnico       INT               NOT NULL,
    fecha            DATETIME2         NOT NULL CONSTRAINT DF_Diag_fecha DEFAULT SYSDATETIME(),
    descripcion      NVARCHAR(500)     NOT NULL,
    costo_mano_obra  DECIMAL(10,2)     NOT NULL CONSTRAINT DF_Diag_costo DEFAULT 0,
    activo           BIT               NOT NULL CONSTRAINT DF_Diag_activo DEFAULT 1,
    CONSTRAINT PK_Diagnostico PRIMARY KEY (id_diagnostico),
    CONSTRAINT CK_Diag_costo CHECK (costo_mano_obra >= 0),
    CONSTRAINT FK_Diag_Orden   FOREIGN KEY (id_orden)   REFERENCES OrdenServicio (id_orden),
    CONSTRAINT FK_Diag_Tecnico FOREIGN KEY (id_tecnico) REFERENCES Usuario (id_usuario)
);
GO

/* 8. Reparacion */
CREATE TABLE Reparacion (
    id_reparacion    INT IDENTITY(1,1) NOT NULL,
    id_orden         INT               NOT NULL,
    id_tecnico       INT               NOT NULL,
    fecha_inicio     DATETIME2         NULL,
    fecha_fin        DATETIME2         NULL,
    descripcion      NVARCHAR(500)     NULL,
    costo_mano_obra  DECIMAL(10,2)     NOT NULL CONSTRAINT DF_Rep_costo DEFAULT 0,
    estado           NVARCHAR(20)      NOT NULL CONSTRAINT DF_Rep_estado DEFAULT 'PENDIENTE',
    activo           BIT               NOT NULL CONSTRAINT DF_Rep_activo DEFAULT 1,
    CONSTRAINT PK_Reparacion PRIMARY KEY (id_reparacion),
    CONSTRAINT CK_Rep_costo CHECK (costo_mano_obra >= 0),
    CONSTRAINT CK_Rep_estado CHECK (estado IN ('PENDIENTE','EN_PROCESO','FINALIZADA','CANCELADA')),
    CONSTRAINT CK_Rep_fechas CHECK (fecha_fin IS NULL OR fecha_inicio IS NULL OR fecha_fin >= fecha_inicio),
    CONSTRAINT FK_Rep_Orden   FOREIGN KEY (id_orden)   REFERENCES OrdenServicio (id_orden),
    CONSTRAINT FK_Rep_Tecnico FOREIGN KEY (id_tecnico) REFERENCES Usuario (id_usuario)
);
GO

/* 9. ActividadReparacion */
CREATE TABLE ActividadReparacion (
    id_actividad     INT IDENTITY(1,1) NOT NULL,
    id_reparacion    INT               NOT NULL,
    descripcion      NVARCHAR(300)     NOT NULL,
    costo            DECIMAL(10,2)     NOT NULL CONSTRAINT DF_Act_costo DEFAULT 0,
    activo           BIT               NOT NULL CONSTRAINT DF_Act_activo DEFAULT 1,
    CONSTRAINT PK_ActividadReparacion PRIMARY KEY (id_actividad),
    CONSTRAINT CK_Act_costo CHECK (costo >= 0),
    CONSTRAINT FK_Act_Reparacion FOREIGN KEY (id_reparacion) REFERENCES Reparacion (id_reparacion)
);
GO


/* ============================================================================
   5. TABLAS DE REPUESTOS E INVENTARIO
   ============================================================================ */

/* 11. CategoriaRepuesto */
CREATE TABLE CategoriaRepuesto (
    id_categoria  INT IDENTITY(1,1) NOT NULL,
    nombre        NVARCHAR(50)      NOT NULL,
    activo        BIT               NOT NULL CONSTRAINT DF_CatRep_activo DEFAULT 1,
    CONSTRAINT PK_CategoriaRepuesto PRIMARY KEY (id_categoria),
    CONSTRAINT UQ_CatRep_nombre UNIQUE (nombre)
);
GO

/* 12. Repuesto */
CREATE TABLE Repuesto (
    id_repuesto        INT IDENTITY(1,1) NOT NULL,
    id_categoria       INT               NOT NULL,
    codigo             NVARCHAR(30)      NOT NULL,
    nombre             NVARCHAR(100)     NOT NULL,
    descripcion        NVARCHAR(255)     NULL,
    precio_compra_ref  DECIMAL(10,2)     NOT NULL CONSTRAINT DF_Rep_pcompra DEFAULT 0,
    precio_venta       DECIMAL(10,2)     NOT NULL CONSTRAINT DF_Rep_pventa DEFAULT 0,
    activo             BIT               NOT NULL CONSTRAINT DF_Repuesto_activo DEFAULT 1,
    CONSTRAINT PK_Repuesto PRIMARY KEY (id_repuesto),
    CONSTRAINT UQ_Repuesto_codigo UNIQUE (codigo),
    CONSTRAINT CK_Repuesto_pcompra CHECK (precio_compra_ref >= 0),
    CONSTRAINT CK_Repuesto_pventa  CHECK (precio_venta >= 0),
    CONSTRAINT FK_Repuesto_Categoria FOREIGN KEY (id_categoria) REFERENCES CategoriaRepuesto (id_categoria)
);
GO

/* 13. Bodega */
CREATE TABLE Bodega (
    id_bodega   INT IDENTITY(1,1) NOT NULL,
    nombre      NVARCHAR(50)      NOT NULL,
    ubicacion   NVARCHAR(150)     NULL,
    activo      BIT               NOT NULL CONSTRAINT DF_Bodega_activo DEFAULT 1,
    CONSTRAINT PK_Bodega PRIMARY KEY (id_bodega),
    CONSTRAINT UQ_Bodega_nombre UNIQUE (nombre)
);
GO

/* 14. Inventario  (PK COMPUESTA: id_repuesto + id_bodega) */
CREATE TABLE Inventario (
    id_repuesto    INT           NOT NULL,
    id_bodega      INT           NOT NULL,
    existencia     INT           NOT NULL CONSTRAINT DF_Inv_existencia DEFAULT 0,
    stock_minimo   INT           NOT NULL CONSTRAINT DF_Inv_stockmin DEFAULT 0,
    activo         BIT           NOT NULL CONSTRAINT DF_Inv_activo DEFAULT 1,
    CONSTRAINT PK_Inventario PRIMARY KEY (id_repuesto, id_bodega),
    CONSTRAINT CK_Inv_existencia CHECK (existencia >= 0),
    CONSTRAINT CK_Inv_stockmin   CHECK (stock_minimo >= 0),
    CONSTRAINT FK_Inv_Repuesto FOREIGN KEY (id_repuesto) REFERENCES Repuesto (id_repuesto),
    CONSTRAINT FK_Inv_Bodega   FOREIGN KEY (id_bodega)   REFERENCES Bodega (id_bodega)
);
GO

/* 10. ReparacionRepuesto  (PK COMPUESTA: id_reparacion + id_repuesto)
   Se crea aqui porque depende de Repuesto y Bodega, ya definidos. */
CREATE TABLE ReparacionRepuesto (
    id_reparacion    INT           NOT NULL,
    id_repuesto      INT           NOT NULL,
    id_bodega        INT           NOT NULL,
    cantidad         INT           NOT NULL,
    precio_historico DECIMAL(10,2) NOT NULL,
    activo           BIT           NOT NULL CONSTRAINT DF_RepRep_activo DEFAULT 1,
    CONSTRAINT PK_ReparacionRepuesto PRIMARY KEY (id_reparacion, id_repuesto),
    CONSTRAINT CK_RepRep_cantidad CHECK (cantidad > 0),
    CONSTRAINT CK_RepRep_precio   CHECK (precio_historico >= 0),
    CONSTRAINT FK_RepRep_Reparacion FOREIGN KEY (id_reparacion) REFERENCES Reparacion (id_reparacion),
    CONSTRAINT FK_RepRep_Repuesto   FOREIGN KEY (id_repuesto)   REFERENCES Repuesto (id_repuesto),
    CONSTRAINT FK_RepRep_Bodega     FOREIGN KEY (id_bodega)     REFERENCES Bodega (id_bodega)
);
GO


/* ============================================================================
   6. TABLAS DE PROVEEDORES Y COMPRAS
   ============================================================================ */

/* 16. Proveedor */
CREATE TABLE Proveedor (
    id_proveedor  INT IDENTITY(1,1) NOT NULL,
    nombre        NVARCHAR(100)     NOT NULL,
    nit           VARCHAR(20)       NOT NULL,
    telefono      VARCHAR(20)       NULL,
    email         NVARCHAR(100)     NULL,
    direccion     NVARCHAR(200)     NULL,
    activo        BIT               NOT NULL CONSTRAINT DF_Proveedor_activo DEFAULT 1,
    CONSTRAINT PK_Proveedor PRIMARY KEY (id_proveedor),
    CONSTRAINT UQ_Proveedor_nit UNIQUE (nit)
);
GO

/* 17. Compra */
CREATE TABLE Compra (
    id_compra     INT IDENTITY(1,1) NOT NULL,
    numero        NVARCHAR(20)      NOT NULL,
    id_proveedor  INT               NOT NULL,
    id_usuario    INT               NOT NULL,
    id_bodega     INT               NOT NULL,
    fecha         DATETIME2         NOT NULL CONSTRAINT DF_Compra_fecha DEFAULT SYSDATETIME(),
    estado        NVARCHAR(15)      NOT NULL CONSTRAINT DF_Compra_estado DEFAULT 'PENDIENTE',
    total         DECIMAL(12,2)     NOT NULL CONSTRAINT DF_Compra_total DEFAULT 0,
    activo        BIT               NOT NULL CONSTRAINT DF_Compra_activo DEFAULT 1,
    CONSTRAINT PK_Compra PRIMARY KEY (id_compra),
    CONSTRAINT UQ_Compra_numero UNIQUE (numero),
    CONSTRAINT CK_Compra_estado CHECK (estado IN ('PENDIENTE','RECIBIDA','ANULADA')),
    CONSTRAINT CK_Compra_total  CHECK (total >= 0),
    CONSTRAINT FK_Compra_Proveedor FOREIGN KEY (id_proveedor) REFERENCES Proveedor (id_proveedor),
    CONSTRAINT FK_Compra_Usuario   FOREIGN KEY (id_usuario)   REFERENCES Usuario (id_usuario),
    CONSTRAINT FK_Compra_Bodega    FOREIGN KEY (id_bodega)    REFERENCES Bodega (id_bodega)
);
GO

/* 18. DetalleCompra  (PK COMPUESTA: id_compra + id_repuesto) */
CREATE TABLE DetalleCompra (
    id_compra        INT           NOT NULL,
    id_repuesto      INT           NOT NULL,
    cantidad         INT           NOT NULL,
    costo_historico  DECIMAL(10,2) NOT NULL,
    activo           BIT           NOT NULL CONSTRAINT DF_DetCompra_activo DEFAULT 1,
    CONSTRAINT PK_DetalleCompra PRIMARY KEY (id_compra, id_repuesto),
    CONSTRAINT CK_DetCompra_cantidad CHECK (cantidad > 0),
    CONSTRAINT CK_DetCompra_costo    CHECK (costo_historico >= 0),
    CONSTRAINT FK_DetCompra_Compra   FOREIGN KEY (id_compra)   REFERENCES Compra (id_compra),
    CONSTRAINT FK_DetCompra_Repuesto FOREIGN KEY (id_repuesto) REFERENCES Repuesto (id_repuesto)
);
GO

/* 15. MovimientoInventario
   doc_tipo + doc_referencia = referencia polimorfica al documento origen
   (COMPRA / REPARACION / AJUSTE). Su integridad se valida por procedimiento
   almacenado dentro de la transaccion, no por FK directa. */
CREATE TABLE MovimientoInventario (
    id_movimiento          INT IDENTITY(1,1) NOT NULL,
    id_repuesto            INT               NOT NULL,
    id_bodega              INT               NOT NULL,
    tipo                   NVARCHAR(10)      NOT NULL,
    cantidad               INT               NOT NULL,
    fecha                  DATETIME2         NOT NULL CONSTRAINT DF_Mov_fecha DEFAULT SYSDATETIME(),
    id_usuario             INT               NOT NULL,
    doc_tipo               NVARCHAR(20)      NOT NULL,
    doc_referencia         INT               NOT NULL,
    existencia_resultante  INT               NOT NULL,
    activo                 BIT               NOT NULL CONSTRAINT DF_Mov_activo DEFAULT 1,
    CONSTRAINT PK_MovimientoInventario PRIMARY KEY (id_movimiento),
    CONSTRAINT CK_Mov_tipo CHECK (tipo IN ('ENTRADA','SALIDA')),
    CONSTRAINT CK_Mov_doctipo CHECK (doc_tipo IN ('COMPRA','REPARACION','AJUSTE')),
    CONSTRAINT CK_Mov_cantidad CHECK (cantidad > 0),
    CONSTRAINT CK_Mov_existencia CHECK (existencia_resultante >= 0),
    CONSTRAINT FK_Mov_Repuesto FOREIGN KEY (id_repuesto) REFERENCES Repuesto (id_repuesto),
    CONSTRAINT FK_Mov_Bodega   FOREIGN KEY (id_bodega)   REFERENCES Bodega (id_bodega),
    CONSTRAINT FK_Mov_Usuario  FOREIGN KEY (id_usuario)  REFERENCES Usuario (id_usuario)
);
GO


/* ============================================================================
   7. TABLAS DE FACTURACION Y PAGOS
   ============================================================================ */

/* 19. Factura  (relacion 1:1 con Orden mediante UNIQUE en id_orden) */
CREATE TABLE Factura (
    id_factura          INT IDENTITY(1,1) NOT NULL,
    numero              NVARCHAR(20)      NOT NULL,
    id_orden            INT               NOT NULL,
    nit                 VARCHAR(20)       NOT NULL,
    nombre_facturacion  NVARCHAR(150)     NOT NULL,
    fecha               DATETIME2         NOT NULL CONSTRAINT DF_Factura_fecha DEFAULT SYSDATETIME(),
    subtotal            DECIMAL(12,2)     NOT NULL,
    impuesto            DECIMAL(12,2)     NOT NULL CONSTRAINT DF_Factura_impuesto DEFAULT 0,
    total               DECIMAL(12,2)     NOT NULL,
    estado              NVARCHAR(15)      NOT NULL CONSTRAINT DF_Factura_estado DEFAULT 'EMITIDA',
    activo              BIT               NOT NULL CONSTRAINT DF_Factura_activo DEFAULT 1,
    CONSTRAINT PK_Factura PRIMARY KEY (id_factura),
    CONSTRAINT UQ_Factura_numero UNIQUE (numero),
    CONSTRAINT UQ_Factura_orden  UNIQUE (id_orden),
    CONSTRAINT CK_Factura_estado   CHECK (estado IN ('EMITIDA','ANULADA')),
    CONSTRAINT CK_Factura_subtotal CHECK (subtotal >= 0),
    CONSTRAINT CK_Factura_impuesto CHECK (impuesto >= 0),
    CONSTRAINT CK_Factura_total    CHECK (total >= 0),
    CONSTRAINT FK_Factura_Orden FOREIGN KEY (id_orden) REFERENCES OrdenServicio (id_orden)
);
GO

/* 20. DetalleFactura */
CREATE TABLE DetalleFactura (
    id_detalle        INT IDENTITY(1,1) NOT NULL,
    id_factura        INT               NOT NULL,
    tipo              NVARCHAR(15)      NOT NULL,
    descripcion       NVARCHAR(255)     NOT NULL,
    cantidad          INT               NOT NULL CONSTRAINT DF_DetFactura_cantidad DEFAULT 1,
    precio_historico  DECIMAL(10,2)     NOT NULL,
    subtotal          DECIMAL(12,2)     NOT NULL,
    activo            BIT               NOT NULL CONSTRAINT DF_DetFactura_activo DEFAULT 1,
    CONSTRAINT PK_DetalleFactura PRIMARY KEY (id_detalle),
    CONSTRAINT CK_DetFactura_tipo CHECK (tipo IN ('MANO_OBRA','REPUESTO')),
    CONSTRAINT CK_DetFactura_cantidad CHECK (cantidad > 0),
    CONSTRAINT CK_DetFactura_precio   CHECK (precio_historico >= 0),
    CONSTRAINT CK_DetFactura_subtotal CHECK (subtotal >= 0),
    CONSTRAINT FK_DetFactura_Factura FOREIGN KEY (id_factura) REFERENCES Factura (id_factura)
);
GO

/* 21. MetodoPago */
CREATE TABLE MetodoPago (
    id_metodo  INT IDENTITY(1,1) NOT NULL,
    nombre     NVARCHAR(30)      NOT NULL,
    activo     BIT               NOT NULL CONSTRAINT DF_MetodoPago_activo DEFAULT 1,
    CONSTRAINT PK_MetodoPago PRIMARY KEY (id_metodo),
    CONSTRAINT UQ_MetodoPago_nombre UNIQUE (nombre)
);
GO

/* 22. Pago */
CREATE TABLE Pago (
    id_pago      INT IDENTITY(1,1) NOT NULL,
    id_factura   INT               NOT NULL,
    id_metodo    INT               NOT NULL,
    fecha        DATETIME2         NOT NULL CONSTRAINT DF_Pago_fecha DEFAULT SYSDATETIME(),
    monto        DECIMAL(12,2)     NOT NULL,
    referencia   NVARCHAR(50)      NULL,
    activo       BIT               NOT NULL CONSTRAINT DF_Pago_activo DEFAULT 1,
    CONSTRAINT PK_Pago PRIMARY KEY (id_pago),
    CONSTRAINT CK_Pago_monto CHECK (monto > 0),
    CONSTRAINT FK_Pago_Factura FOREIGN KEY (id_factura) REFERENCES Factura (id_factura),
    CONSTRAINT FK_Pago_Metodo  FOREIGN KEY (id_metodo)  REFERENCES MetodoPago (id_metodo)
);
GO


/* ============================================================================
   8. TABLA DE ENTREGA
   ============================================================================ */

/* 23. Entrega  (relacion 1:1 con Orden mediante UNIQUE en id_orden) */
CREATE TABLE Entrega (
    id_entrega          INT IDENTITY(1,1) NOT NULL,
    id_orden            INT               NOT NULL,
    id_usuario_entrega  INT               NOT NULL,
    recibe              NVARCHAR(100)     NOT NULL,
    fecha               DATETIME2         NOT NULL CONSTRAINT DF_Entrega_fecha DEFAULT SYSDATETIME(),
    observaciones       NVARCHAR(300)     NULL,
    activo              BIT               NOT NULL CONSTRAINT DF_Entrega_activo DEFAULT 1,
    CONSTRAINT PK_Entrega PRIMARY KEY (id_entrega),
    CONSTRAINT UQ_Entrega_orden UNIQUE (id_orden),
    CONSTRAINT FK_Entrega_Orden   FOREIGN KEY (id_orden)           REFERENCES OrdenServicio (id_orden),
    CONSTRAINT FK_Entrega_Usuario FOREIGN KEY (id_usuario_entrega) REFERENCES Usuario (id_usuario)
);
GO

/* ============================================================================
   FIN SECCION 01 - CREACION DE TABLAS
   25 tablas creadas en orden de dependencias.
   Siguiente seccion: 02_logica.sql (indices, vistas, funciones, SP y triggers).
   ============================================================================ */
