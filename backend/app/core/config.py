"""
Carga la configuracion desde variables de entorno (.env).
Mantener los datos sensibles de conexion FUERA del codigo fuente
es un requisito del proyecto (seccion 6.4).
"""
from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Base de datos
    DB_SERVER: str = "localhost"
    DB_PORT: int = 1433
    DB_NAME: str = "TechCareDB"
    DB_USER: str = "sa"
    DB_PASSWORD: str = ""
    DB_DRIVER: str = "ODBC Driver 18 for SQL Server"
    DB_TRUST_CERT: str = "yes"

    # Seguridad
    JWT_SECRET: str = "clave-insegura-cambiar"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 480

    # CORS
    FRONTEND_ORIGIN: str = "http://localhost:5173"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    @property
    def odbc_connection_string(self) -> str:
        """
        Cadena ODBC para pyodbc/SQLAlchemy.

        - Instancia nombrada (ej. 'PC\\SQLEXPRESS'): se usa tal cual, SIN puerto.
        - Instancia por defecto con puerto: 'SERVER=host,puerto'.
        - Autenticacion:
            * Si DB_USER tiene valor  -> login SQL (UID/PWD).
            * Si DB_USER esta vacio    -> autenticacion de Windows (Trusted_Connection).
        """
        if "\\" in self.DB_SERVER or not self.DB_PORT:
            server_part = self.DB_SERVER           # instancia nombrada o sin puerto
        else:
            server_part = f"{self.DB_SERVER},{self.DB_PORT}"

        if self.DB_USER:
            auth = f"UID={self.DB_USER};PWD={self.DB_PASSWORD};"
        else:
            auth = "Trusted_Connection=yes;"

        return (
            f"DRIVER={{{self.DB_DRIVER}}};"
            f"SERVER={server_part};"
            f"DATABASE={self.DB_NAME};"
            f"{auth}"
            f"TrustServerCertificate={self.DB_TRUST_CERT};"
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
