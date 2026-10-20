# Guía de despliegue — TechCare Solutions

Cómo levantar el proyecto en tu propia computadora después de clonarlo de GitHub.
Es una aplicación de **tres capas**: base de datos (SQL Server) → backend (FastAPI)
→ frontend (React). Hay que preparar las tres, en ese orden.

---

## 0. Requisitos previos (instalar una sola vez)

Antes de empezar, cada quien debe tener instalado en su PC:

- **SQL Server** (Express o Developer, es gratis) y **SSMS** (SQL Server Management Studio).
- **ODBC Driver 18 for SQL Server** — es aparte de SQL Server. Para comprobarlo, en
  PowerShell: `Get-OdbcDriver | Select Name`. Si ves "ODBC Driver 18 for SQL Server",
  está. Si solo aparece el 17, anótalo (lo usarás en el `.env`). Si no hay ninguno,
  descárgalo del sitio de Microsoft ("Microsoft ODBC Driver for SQL Server").
- **Python 3.11 o superior** (marca "Add Python to PATH" al instalarlo).
- **Node.js 20 o superior**.

---

## 1. Después de clonar de GitHub

```bash
git clone <url-del-repositorio>
cd techcare
```

La estructura que verás:

```
techcare/
├── backend/     API en Python (FastAPI)
├── frontend/    Interfaz en React (Vite)
└── database/    Scripts SQL (la base de datos)
```

Hay que preparar cada carpeta. Sigue el orden: **base de datos → backend → frontend.**

---

## 2. Base de datos (carpeta `database/`)

### Qué contiene cada archivo

| Archivo | Qué hace |
|---------|----------|
| `01_creacion_tablas.sql` | Crea la base `TechCareDB` y sus 25 tablas con todas sus restricciones. **Si la base ya existe, la borra y la crea de nuevo.** |
| `02_logica.sql` | Crea los índices, funciones, vistas, procedimientos almacenados y triggers. |
| `03_datos_prueba.sql` | Llena la base con datos de prueba (usuarios, clientes, órdenes, inventario, etc.). |
| `04_consultas_reportes.sql` | Los 12 reportes en SQL (opcional, para consultarlos directo). |
| `05_pruebas_integridad.sql` | Pruebas funcionales y de integridad (opcional; **agrega registros**). |
| `99_verificacion.sql` | Verifica que todo se creó bien (opcional). |

### Orden para ejecutarlos

En **SSMS**, conéctate a tu servidor. Abre cada archivo (`Archivo → Abrir → Archivo…`)
y ejecútalo con **F5**, en este orden:

1. `01_creacion_tablas.sql`
2. `02_logica.sql`
3. `03_datos_prueba.sql`

> **Importante:** ejecútalos con la base **`master`** seleccionada en el desplegable
> de arriba (no `TechCareDB`), porque el `01` borra y recrea la base y no conviene
> estar "parado" dentro de ella.

Esos tres son obligatorios. Los archivos `04`, `05` y `99` son opcionales.

### Cómo verificar que se ejecutaron bien

Abre `99_verificacion.sql` y ejecútalo (F5). Debe mostrar una tabla donde **todas
las filas digan `CUMPLE`**, con estos números:

| Componente | Debe decir |
|------------|-----------|
| Tablas | 25 |
| Llaves primarias compuestas | 3 |
| Vistas | 4 |
| Procedimientos | 12 |
| Funciones | 2 |
| Triggers | 3 |
| Índices no agrupados | 8 |

Comprobación rápida de que hay datos: en una consulta nueva,
`USE TechCareDB; SELECT COUNT(*) FROM Usuario;` debe dar **12**.

### Si al conectar el backend da "Login failed" o "single-user mode"

Son los dos tropiezos más comunes al recargar la base:

- **"Login failed for user… Cannot open database"**: tu usuario de Windows no tiene
  acceso a la base. Si *tú* la creaste, ya eres el dueño (`dbo`) y no hace falta nada.
  Si otro compañero la creó, dale acceso a tu login desde SSMS (`CREATE USER … ;
  ALTER ROLE db_datareader/db_datawriter ADD MEMBER … ; GRANT EXECUTE …`).
- **"database is in single-user mode"**: el script `01` deja la base en modo de un
  solo usuario al recrearla. Sácala con:
  ```sql
  USE master;
  ALTER DATABASE TechCareDB SET MULTI_USER WITH ROLLBACK IMMEDIATE;
  ```
  (cierra antes cualquier otra pestaña de SSMS que esté usando `TechCareDB`).

---

## 3. Backend (carpeta `backend/`)

### 3.1. Crear el archivo `.env`

El backend lee su configuración de un archivo **`.env`** que **no viene en el
repositorio** (cada PC tiene el suyo, con su propia conexión). Hay una plantilla,
`backend/.env.example`. Créalo copiándola:

```bat
cd backend
copy .env.example .env
```

Luego abre `backend/.env` y ajústalo a tu máquina. Esta es la estructura y qué
poner en cada línea:

```dotenv
DB_SERVER=localhost\SQLEXPRESS     # tu servidor EXACTO como aparece en SSMS ("Server name")
DB_PORT=1433                       # puerto; se ignora si usas instancia nombrada (el \SQLEXPRESS)
DB_NAME=TechCareDB                 # no cambiar
DB_USER=                           # VACIO = autenticacion de Windows (recomendado en Express)
DB_PASSWORD=                       # VACIO con autenticacion de Windows
DB_DRIVER=ODBC Driver 18 for SQL Server   # usa el 17 si es el que tienes instalado
DB_TRUST_CERT=yes
JWT_SECRET=una-clave-larga-y-aleatoria-de-32-o-mas-caracteres
JWT_ALGORITHM=HS256
JWT_EXPIRE_MINUTES=480
FRONTEND_ORIGIN=http://localhost:5173     # la URL donde corre el frontend
```

**Lo único que cada quien cambia según su máquina es `DB_SERVER`** (y, si no usa
Windows auth, `DB_USER`/`DB_PASSWORD`). Para saber tu `DB_SERVER` exacto: ábrelo en
SSMS y copia el campo **"Server name"** de la ventana de conexión.

> Si tu SSMS te conecta con "Windows Authentication" (sin escribir contraseña),
> deja `DB_USER` y `DB_PASSWORD` **vacíos**. Si usas el usuario `sa`, pon
> `DB_USER=sa` y su contraseña.

### 3.2. Instalar dependencias y levantar

Desde la carpeta `backend`, crea un entorno virtual, actívalo e instala:

```bat
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

> Si al activar da error de permisos en PowerShell, corre una vez:
> `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` y reintenta el `activate`.

Levanta el backend (siempre desde la carpeta `backend`, nunca desde `backend\app`):

```bat
uvicorn app.main:app --reload
```

Debe decir `Uvicorn running on http://127.0.0.1:8000`. Comprueba en el navegador:

- `http://localhost:8000/api/health` → `{"status":"ok", ...}`
- `http://localhost:8000/docs` → la documentación interactiva (Swagger).

### Puertos

El backend usa el **8000** por defecto. Si ese puerto está ocupado en tu máquina,
levántalo en otro, por ejemplo el 8001:

```bat
uvicorn app.main:app --reload --port 8001
```

Si lo cambias, **avísale al frontend**: edita `frontend/.env` y pon
`VITE_API_URL=http://localhost:8001`.

---

## 4. Frontend (carpeta `frontend/`)

### 4.1. Crear el archivo `.env`

Igual que el backend, el frontend lee su configuración de un `.env` que no viene en
el repositorio. Cópialo de la plantilla:

```bat
cd frontend
copy .env.example .env
```

Contenido de `frontend/.env`:

```dotenv
VITE_API_URL=http://localhost:8000
```

Solo cámbialo si levantaste el backend en otro puerto (ver sección anterior).

### 4.2. Instalar dependencias y levantar

```bat
npm install
npm run dev
```

Debe decir algo como `Local: http://localhost:5173/`. Ábrelo en el navegador.

### Puertos

El frontend usa el **5173** (Vite). Si está ocupado, Vite elige otro automáticamente
y lo muestra en la terminal. **Si cambia**, actualiza `FRONTEND_ORIGIN` en
`backend/.env` para que coincida (si no, el backend bloqueará las peticiones por CORS)
y reinicia el backend.

---

## 5. Resumen: puertos por defecto

| Servicio | Puerto | URL |
|----------|--------|-----|
| Frontend (React/Vite) | 5173 | http://localhost:5173 |
| Backend (FastAPI) | 8000 | http://localhost:8000 (docs en `/docs`) |
| SQL Server | 1433 | (no se abre en navegador) |

Dos variables deben "apuntarse" entre sí: `VITE_API_URL` (frontend) debe apuntar al
puerto del backend, y `FRONTEND_ORIGIN` (backend) debe apuntar al puerto del frontend.

---

## 6. Para usar la aplicación

Con el backend y el frontend corriendo a la vez, abre `http://localhost:5173` y
entra con cualquiera de los usuarios de prueba. **Todos tienen la contraseña
`Clave123*`**:

| Usuario | Rol |
|---------|-----|
| `admin` | Administrador (ve todo) |
| `recep1`, `recep2` | Recepción |
| `tecnico1` … `tecnico5` | Técnico |
| `bodega1`, `bodega2` | Bodega |
| `caja1`, `caja2` | Caja |

---

## 7. Problemas frecuentes

| Síntoma | Causa y solución |
|---------|------------------|
| Login da error 500 y en la consola del navegador sale "CORS" | El error real está en la **terminal de uvicorn**. Casi siempre es la conexión a SQL Server: revisa `DB_SERVER` en `backend/.env` y reinicia uvicorn. |
| `No module named 'fastapi'` | No instalaste dependencias o VS Code usa otro Python. Activa el `.venv` y corre `pip install -r requirements.txt`. |
| `Login failed for user…` | Permisos en SQL Server (ver sección 2). |
| `Attribute "main" not found` | Escribiste mal el comando. Es `uvicorn app.main:app` (la `app` del final es la variable, no el archivo). |
| El frontend carga pero no trae datos | El backend no está corriendo, o `VITE_API_URL` apunta al puerto equivocado. |
