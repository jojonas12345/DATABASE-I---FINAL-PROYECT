@echo off
REM Levanta backend y frontend en dos ventanas (modo desarrollo, con hot reload).
REM SQL Server ya corre como servicio de Windows, no hace falta arrancarlo aqui.
REM Requisito: haber creado los .env y los entornos (ver README).

echo Iniciando backend (FastAPI) en http://localhost:8000 ...
start "TechCare Backend" cmd /k "cd backend && .venv\Scripts\activate && uvicorn app.main:app --reload"

echo Iniciando frontend (Vite) en http://localhost:5173 ...
start "TechCare Frontend" cmd /k "cd frontend && npm run dev"

echo.
echo Backend:  http://localhost:8000/docs
echo Frontend: http://localhost:5173
