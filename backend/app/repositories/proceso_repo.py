"""
Repository de los procesos del flujo de una orden. Cada proceso es un
procedimiento almacenado que valida las reglas y hace su propia transaccion:
  - usp_RegistrarDiagnostico  (R03; pasa la orden a DIAGNOSTICO)
  - usp_IniciarReparacion     (R03 + R04: exige diagnostico previo)
  - usp_FinalizarReparacion   (cierra la reparacion; si no quedan abiertas, orden LISTO)
  - usp_EntregarOrden         (exige LISTO + factura emitida + saldo 0)
"""
from sqlalchemy.orm import Session

from app.db.sp import exec_sp, exec_sp_output


def registrar_diagnostico(db: Session, id_orden: int, id_tecnico: int, descripcion: str, costo: float) -> int:
    return exec_sp_output(db, "usp_RegistrarDiagnostico", {
        "id_orden": id_orden, "id_tecnico": id_tecnico,
        "descripcion": descripcion, "costo_mano_obra": costo,
    }, output_name="id_diagnostico")


def iniciar_reparacion(db: Session, id_orden: int, id_tecnico: int, descripcion: str | None, costo: float) -> int:
    return exec_sp_output(db, "usp_IniciarReparacion", {
        "id_orden": id_orden, "id_tecnico": id_tecnico,
        "descripcion": descripcion, "costo_mano_obra": costo,
    }, output_name="id_reparacion")


def finalizar_reparacion(db: Session, id_reparacion: int, id_usuario: int) -> None:
    exec_sp(db, "usp_FinalizarReparacion", {"id_reparacion": id_reparacion, "id_usuario": id_usuario})


def entregar_orden(db: Session, id_orden: int, id_usuario: int, recibe: str, obs: str | None) -> int:
    return exec_sp_output(db, "usp_EntregarOrden", {
        "id_orden": id_orden, "id_usuario": id_usuario,
        "recibe": recibe, "observaciones": obs,
    }, output_name="id_entrega")
