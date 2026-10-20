"""
Repository de Usuarios. Trae el usuario con su rol para autenticar.
La tabla guarda password_hash (bcrypt), nunca texto plano.
"""
from sqlalchemy import text
from sqlalchemy.orm import Session


def obtener_por_nombre_usuario(db: Session, nombre_usuario: str) -> dict | None:
    sql = text("""
        SELECT u.id_usuario, u.nombre_usuario, u.password_hash,
               u.nombres, u.apellidos, u.activo, r.nombre AS rol
        FROM Usuario u
        INNER JOIN Rol r ON r.id_rol = u.id_rol
        WHERE u.nombre_usuario = :nombre_usuario;
    """)
    row = db.execute(sql, {"nombre_usuario": nombre_usuario}).mappings().first()
    return dict(row) if row else None
