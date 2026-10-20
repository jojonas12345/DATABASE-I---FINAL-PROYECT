# TechCare Solutions — Sistema Integral de Servicio Técnico, Inventario y Facturación

**Proyecto Final — Base de Datos I.** Sistema empresarial para una empresa de
servicio técnico: cubre el ciclo completo de una reparación (cliente → equipo →
orden → diagnóstico → reparación → repuestos → factura → pago → entrega) y el
abastecimiento (proveedor → compra → inventario → movimientos).

La **base de datos es el núcleo** del proyecto: la integridad y la lógica
transaccional viven en SQL Server (restricciones, procedimientos almacenados,
funciones y triggers), no en la interfaz.

> **Para instalar y levantar el proyecto paso a paso, lee [`DESPLIEGUE.md`](DESPLIEGUE.md).**
> Este README describe *qué es* el proyecto y *cómo está construido*.

---

## Arquitectura de tres capas

```
React (Vite)  --HTTP/JSON-->  FastAPI (Python)  --pyodbc/SQLAlchemy-->  SQL Server
  [Frontend]                     [Backend / API]                        [Base de datos]
```

- **Frontend (React):** solo presenta datos y captura acciones. **Nunca** toca SQL
  Server; todo lo pide a la API.
- **Backend (FastAPI):** guardián y orquestador. Valida el rol (JWT) y los datos,
  **invoca el procedimiento almacenado** (en los procesos de negocio) y traduce el
  resultado o el error a una respuesta HTTP. No contiene la lógica transaccional.
- **Base de datos (SQL Server):** fuente de la verdad y última barrera de integridad.
  Las reglas se cumplen aquí **aunque se intente insertar datos directamente por SQL.**

---

## Estructura del repositorio

```
techcare/
├── DESPLIEGUE.md          guía de instalación paso a paso (empieza por aquí)
├── README.md              este archivo
├── database/              scripts SQL de la base de datos (ver database/README.md)
│   ├── 01_creacion_tablas.sql     base + 25 tablas con restricciones
│   ├── 02_logica.sql              índices, funciones, vistas, procedimientos, triggers
│   ├── 03_datos_prueba.sql        datos de prueba
│   ├── 04_consultas_reportes.sql  los 12 reportes en SQL
│   ├── 05_pruebas_integridad.sql  pruebas funcionales y de integridad
│   └── 99_verificacion.sql        verifica los mínimos del enunciado
├── backend/               API FastAPI
│   ├── .env.example       plantilla de configuración (copiar a .env)
│   ├── requirements.txt
│   └── app/
│       ├── core/          config (.env) y security (hash bcrypt + JWT)
│       ├── db/            conexión a SQL Server y helper para llamar procedimientos
│       ├── schemas/       validación Pydantic (DTOs de entrada/salida)
│       ├── repositories/  ÚNICA capa que habla con la BD / invoca los procedimientos
│       ├── services/      reglas de negocio y orquestación
│       ├── routers/       endpoints agrupados por módulo
│       └── dependencies.py  usuario actual y control de rol (require_roles)
└── frontend/              React + Vite
    ├── .env.example
    └── src/
        ├── api/           único punto que llama al backend (axios + token)
        ├── context/       sesión y rol del usuario
        ├── components/    UI reutilizable (tabla, tabs, formularios…)
        ├── pages/         una pantalla por módulo
        └── routes/        protección de rutas por sesión y por rol
```

---

## Requisitos

- **SQL Server** (Express o Developer) + **SSMS**
- **ODBC Driver 18 for SQL Server** (o el 17)
- **Python 3.11+**
- **Node.js 20+**

Puertos por defecto: frontend **5173**, backend **8000**, SQL Server **1433**.

---

## Módulos y roles

El menú y las acciones se habilitan según el rol del usuario (restringido también
en el backend). Usuarios de prueba: todos con contraseña `Clave123*`.

| Módulo | Administrador | Recepción | Técnico | Bodega | Caja |
|--------|:--:|:--:|:--:|:--:|:--:|
| Dashboard | ✓ | ✓ | ✓ | ✓ | ✓ |
| Órdenes (flujo completo con pestañas) | ✓ | ✓ | ✓ | – | ✓ (facturar) |
| Clientes y Equipos | ✓ | ✓ | – | – | – |
| Inventario / Bodega | ✓ | – | – | ✓ | – |
| Caja (facturación y pagos) | ✓ | – | – | – | ✓ |
| Reportes (los 12) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Administración (usuarios + catálogos) | ✓ | – | – | – | – |

---

## La base de datos (resumen)

Verificado con `99_verificacion.sql` — todos los componentes **CUMPLEN**:

| Componente | Cantidad | Mínimo |
|------------|:--:|:--:|
| Tablas | 25 | 18 |
| Relaciones N:M (Inventario, DetalleCompra, ReparacionRepuesto) | 3 | 3 |
| Llaves primarias compuestas | 3 | 2 |
| UNIQUE / DEFAULT / CHECK | 16 / 49 / 33 | 5 / 5 / 4 |
| Vistas | 4 | 4 |
| Procedimientos almacenados | 12 | 6 |
| Funciones | 2 | 2 |
| Triggers | 3 | 2 |
| Índices no agrupados | 8 | 6 |
| Reportes con JOIN | 12 (+variantes) | 12 |

El detalle de cada procedimiento, trigger y reporte está en
[`database/README.md`](database/README.md).

---

## Endpoints de la API

Los **procesos del negocio** invocan un procedimiento almacenado (que hace la
transacción y valida las reglas); los **mantenimientos** y **lecturas** usan
consultas parametrizadas o vistas. Los `repositories` son la única capa que llama a la BD.

| Método | Ruta | Qué ejecuta | Rol |
|--------|------|-------------|-----|
| POST | `/auth/login` | consulta Usuario + bcrypt → JWT | público |
| GET  | `/dashboard` | indicadores (vistas) + actividad reciente | autenticado |
| POST | `/ordenes` | `usp_CrearOrdenServicio` | Admin, Recepción |
| PUT  | `/ordenes/{id}/estado` | `usp_CambiarEstadoOrden` (+ trigger de historial) | Admin, Recepción, Técnico |
| GET  | `/ordenes`, `/ordenes/{id}` | lista y detalle (historial, recepcionista, factura…) | autenticado |
| POST | `/ordenes/{id}/diagnostico` | `usp_RegistrarDiagnostico` | Admin, Técnico |
| POST | `/ordenes/{id}/reparacion` | `usp_IniciarReparacion` (R04: exige diagnóstico) | Admin, Técnico |
| POST | `/reparaciones/{id}/repuestos` | `usp_ConsumirRepuesto` | Admin, Técnico |
| PUT  | `/reparaciones/{id}/finalizar` | `usp_FinalizarReparacion` | Admin, Técnico |
| POST | `/ordenes/{id}/entrega` | `usp_EntregarOrden` (exige saldo 0) | Admin, Recepción |
| POST | `/facturas` | `usp_GenerarFactura` | Admin, Caja |
| POST | `/facturas/pagos` | `usp_RegistrarPago` | Admin, Caja |
| GET  | `/facturas`, `/facturas/{id}` | vista `vw_FacturasConSaldo` / detalle con pagos | autenticado |
| POST | `/compras` | `usp_RegistrarCompra` (+ `usp_RecibirCompra` si `recibir=true`) | Admin, Bodega |
| POST | `/compras/{id}/recibir` | `usp_RecibirCompra` | Admin, Bodega |
| GET  | `/inventario`, `/inventario/compras`, `/inventario/movimientos` | existencias, compras, kardex | Admin, Bodega |
| GET  | `/reportes`, `/reportes/{1..12}` | los 12 reportes con filtros | autenticado |
| GET/POST/PUT | `/clientes`, `/equipos` | mantenimiento (crear, editar, activar/desactivar) | Admin, Recepción |
| GET/POST/PUT | `/admin/usuarios`, `/admin/catalogos/{entidad}` | mantenimiento de usuarios y catálogos | Admin |
| GET  | `/catalogos/*` | catálogos activos para selects | autenticado |

Swagger (`http://localhost:8000/docs`) permite probar cada endpoint con el botón **Authorize**.

---

## Seguridad y calidad (requisitos del proyecto)

- Contraseñas con **hash bcrypt**, nunca en texto plano.
- Consultas **parametrizadas** y procedimientos almacenados; nunca se concatena
  entrada del usuario en el SQL (sin inyección).
- **JWT** con rol; cada endpoint se restringe por rol (`require_roles`), de modo que
  la restricción no vive solo en la interfaz.
- Validación en **interfaz y backend**; los errores de la base se traducen a mensajes
  comprensibles.
- Cadena de conexión y secretos en **`.env`**, fuera del código y sin versionar.
- La aplicación arranca con **datos de prueba** suficientes para demostrar todos los
  procesos y escenarios.

---

## Diseño de la interfaz

Tema oscuro (negro / gris / rojo), acorde a un taller de servicio técnico. El rojo
se usa como color de acento para acciones y alertas.