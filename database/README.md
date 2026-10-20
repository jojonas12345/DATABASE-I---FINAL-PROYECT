# Scripts de base de datos — TechCareDB (SQL Server)

## Orden de ejecución

| # | Script | Qué hace | ¿Obligatorio? |
|---|--------|----------|---------------|
| 1 | `01_creacion_tablas.sql` | Crea la base `TechCareDB` desde cero y sus 25 tablas con PK, FK, UNIQUE, DEFAULT, CHECK y 3 PK compuestas. **Borra la base si ya existe.** | Sí |
| 2 | `02_logica.sql` | Índices, funciones, vistas, procedimientos almacenados y triggers. | Sí |
| 3 | `03_datos_prueba.sql` | Datos de prueba coherentes que cumplen los mínimos y escenarios de la sección 7. | Sí |
| 4 | `04_consultas_reportes.sql` | Los 12 reportes obligatorios (mismas consultas que ejecuta la app). | Consulta |
| 5 | `05_pruebas_integridad.sql` | 31 pruebas funcionales y de integridad (imprime OK/FALLO). **Agrega registros**: para volver al estado inicial, re-ejecutar 01→02→03. | Evidencia |
| 6 | `99_verificacion.sql` | Cuenta los objetos de la base contra los mínimos del enunciado. | Consulta |

Usuarios de prueba: todos con contraseña `Clave123*` (admin, recep1, recep2, caja1, caja2, bodega1, bodega2, tecnico1…tecnico5).

## Objetos de `02_logica.sql`

**Índices (8):** IX_Orden_estado, IX_Orden_cliente, IX_Equipo_cliente, IX_Mov_repuesto_bodega, IX_Factura_fecha, IX_Pago_factura, IX_Diag_orden, IX_Historial_orden.

**Funciones (2):** `fn_SaldoFactura` (saldo pendiente), `fn_TotalOrden` (mano de obra + repuestos).

**Vistas (4)** — todas con uso real en la app (dashboard, órdenes, caja):
`vw_OrdenesActivas`, `vw_FacturasConSaldo`, `vw_InventarioBajoStock`, `vw_HistorialReparaciones`.

**Procedimientos (12)** — cada proceso del negocio, con TRY/CATCH + TRANSACTION + ROLLBACK + THROW:

| Procedimiento | Proceso | Reglas que garantiza | Endpoint |
|---|---|---|---|
| `usp_CrearOrdenServicio` | Recepción de una orden | equipo del cliente, historial inicial | `POST /ordenes` |
| `usp_CambiarEstadoOrden` | Cambio de estado | R05 (historial vía trigger); no ENTREGADO manual; REPARACION exige diagnóstico; LISTO exige reparación finalizada | `PUT /ordenes/{id}/estado` |
| `usp_RegistrarDiagnostico` | Registro de diagnóstico | R03 (técnico autorizado) | `POST /ordenes/{id}/diagnostico` |
| `usp_IniciarReparacion` | Inicio de reparación | **R04** (diagnóstico previo), R03 | `POST /ordenes/{id}/reparacion` |
| `usp_ConsumirRepuesto` | Consumo de repuestos | R06, R07, R10 (stock suficiente, salida + movimiento) | `POST /reparaciones/{id}/repuestos` |
| `usp_FinalizarReparacion` | Cierre de reparación | orden pasa a LISTO al cerrar la última | `PUT /reparaciones/{id}/finalizar` |
| `usp_GenerarFactura` | Facturación | R09, R11 (precios históricos, 1 factura por orden) | `POST /facturas` |
| `usp_RegistrarPago` | Pagos parciales/totales | R12, R13 (no exceder saldo) | `POST /facturas/pagos` |
| `usp_EntregarOrden` | Entrega y cierre | 2.7/2.8: LISTO + factura emitida + **saldo 0** | `POST /ordenes/{id}/entrega` |
| `usp_RegistrarCompra` | Registro de compra (encabezado + detalle) | varios repuestos, sin repetidos, costo histórico | `POST /compras` |
| `usp_RecibirCompra` | Recepción en inventario | R08 (entrada + movimiento en una transacción) | `POST /compras/{id}/recibir` |
| `usp_RegistrarCompraRepuesto` | Compra rápida de un repuesto | R08 | `POST /compras/repuesto` |

**Triggers (3):**
- `trg_Orden_AuditoriaEstado` — auditoría: registra cada cambio de estado en `HistorialEstadoOrden` (estado anterior, nuevo, fecha, usuario, observación). El usuario lo recibe por `SESSION_CONTEXT`, que fijan los procedimientos.
- `trg_Factura_ProtegerAnulacion` — protección: impide anular una factura con pagos.
- `trg_Reparacion_RequiereDiagnostico` — protección (R04/R16): rechaza una reparación sin diagnóstico previo **incluso si se inserta directo en SQL Server**.

## Reportes (`04`)

Los 12 reportes de la sección 5. Cumplen 5.1: sin `SELECT *`, alias legibles (la tabla Usuario aparece como `recep`, `tecnico`, `registra`…), sin `DISTINCT` (agregados con `APPLY`), filtros parametrizados, 5 reportes con `LEFT JOIN` justificado (1, 2, 9, 10, 12) y 9 que cruzan 6 o más tablas (1, 2, 3, 4, 5, 7, 8, 9, 12). El reporte 12 tiene dos modos: resumen de todas las órdenes y línea de tiempo de una orden.
