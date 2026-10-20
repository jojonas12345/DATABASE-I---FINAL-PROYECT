"""Repository de Ordenes. Invoca usp_CrearOrdenServicio y usp_CambiarEstadoOrden;
las lecturas usan consultas parametrizadas con columnas explicitas."""
from datetime import date

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.db.sp import exec_sp, exec_sp_output

_CLIENTE = "CASE c.tipo WHEN 'INDIVIDUAL' THEN c.nombres + ' ' + c.apellidos ELSE c.razon_social END"


def _rows(db, sql, params=None):
    return [dict(r) for r in db.execute(text(sql), params or {}).mappings().all()]


def crear_orden(db: Session, id_cliente: int, id_equipo: int, id_usuario_recepcion: int,
                problema: str, prioridad: str, fecha_estimada: date | None) -> int:
    return exec_sp_output(db, "usp_CrearOrdenServicio", {
        "id_cliente": id_cliente, "id_equipo": id_equipo,
        "id_usuario_recepcion": id_usuario_recepcion, "problema": problema,
        "prioridad": prioridad, "fecha_estimada": fecha_estimada,
    }, output_name="id_orden")


def cambiar_estado(db: Session, id_orden: int, estado_nuevo: str, id_usuario: int,
                   observacion: str | None) -> None:
    exec_sp(db, "usp_CambiarEstadoOrden", {
        "id_orden": id_orden, "estado_nuevo": estado_nuevo,
        "id_usuario": id_usuario, "observacion": observacion,
    })


def listar_activas(db: Session) -> list[dict]:
    return _rows(db, """
        SELECT id_orden, numero, estado, prioridad, fecha_ingreso, fecha_estimada,
               cliente, tipo_equipo, marca, serie, recepcionista
        FROM vw_OrdenesActivas
        ORDER BY fecha_ingreso DESC;""")


def listar_todas(db: Session, estado: str | None = None) -> list[dict]:
    return _rows(db, f"""
        SELECT o.id_orden, o.numero, o.estado, o.prioridad, o.fecha_ingreso,
               {_CLIENTE} AS cliente, me.nombre AS marca, te.nombre AS tipo_equipo, e.serie
        FROM OrdenServicio o
        INNER JOIN Cliente     c  ON c.id_cliente = o.id_cliente
        INNER JOIN Equipo      e  ON e.id_equipo = o.id_equipo
        INNER JOIN MarcaEquipo me ON me.id_marca = e.id_marca
        INNER JOIN TipoEquipo  te ON te.id_tipo_equipo = e.id_tipo_equipo
        WHERE o.activo = 1 AND (:estado IS NULL OR o.estado = :estado)
        ORDER BY o.fecha_ingreso DESC;""", {"estado": estado})


def obtener_detalle(db: Session, id_orden: int) -> dict | None:
    cab = db.execute(text(f"""
        SELECT o.id_orden, o.numero, o.estado, o.prioridad, o.problema, o.observaciones,
               o.fecha_ingreso, o.fecha_estimada,
               c.id_cliente, {_CLIENTE} AS cliente, c.nit, c.telefono,
               e.id_equipo, e.serie, e.modelo, me.nombre AS marca, te.nombre AS tipo_equipo,
               recep.nombres + ' ' + recep.apellidos AS recepcionista
        FROM OrdenServicio o
        INNER JOIN Cliente     c     ON c.id_cliente = o.id_cliente
        INNER JOIN Equipo      e     ON e.id_equipo = o.id_equipo
        INNER JOIN MarcaEquipo me    ON me.id_marca = e.id_marca
        INNER JOIN TipoEquipo  te    ON te.id_tipo_equipo = e.id_tipo_equipo
        INNER JOIN Usuario     recep ON recep.id_usuario = o.id_usuario_recepcion
        WHERE o.id_orden = :id;"""), {"id": id_orden}).mappings().first()
    if not cab:
        return None
    detalle = dict(cab)
    p = {"id": id_orden}

    detalle["historial"] = _rows(db, """
        SELECT h.fecha, h.estado_anterior, h.estado_nuevo, h.observacion,
               u.nombres + ' ' + u.apellidos AS usuario
        FROM HistorialEstadoOrden h
        INNER JOIN Usuario u ON u.id_usuario = h.id_usuario
        WHERE h.id_orden = :id
        ORDER BY h.fecha, h.id_historial;""", p)

    detalle["diagnosticos"] = _rows(db, """
        SELECT d.id_diagnostico, d.fecha, d.descripcion, d.costo_mano_obra,
               u.nombres + ' ' + u.apellidos AS tecnico
        FROM Diagnostico d INNER JOIN Usuario u ON u.id_usuario = d.id_tecnico
        WHERE d.id_orden = :id AND d.activo = 1 ORDER BY d.fecha;""", p)

    detalle["reparaciones"] = _rows(db, """
        SELECT r.id_reparacion, r.estado, r.descripcion, r.fecha_inicio, r.fecha_fin,
               r.costo_mano_obra, u.nombres + ' ' + u.apellidos AS tecnico
        FROM Reparacion r INNER JOIN Usuario u ON u.id_usuario = r.id_tecnico
        WHERE r.id_orden = :id AND r.activo = 1 ORDER BY r.id_reparacion;""", p)

    fac = db.execute(text("""
        SELECT id_factura, numero, fecha, subtotal, impuesto, total, estado,
               dbo.fn_SaldoFactura(id_factura) AS saldo
        FROM Factura WHERE id_orden = :id AND activo = 1;"""), p).mappings().first()
    detalle["factura"] = dict(fac) if fac else None

    ent = db.execute(text("""
        SELECT en.recibe, en.fecha, en.observaciones,
               u.nombres + ' ' + u.apellidos AS entregado_por
        FROM Entrega en INNER JOIN Usuario u ON u.id_usuario = en.id_usuario_entrega
        WHERE en.id_orden = :id;"""), p).mappings().first()
    detalle["entrega"] = dict(ent) if ent else None

    detalle["total_orden"] = db.execute(text("SELECT dbo.fn_TotalOrden(:id);"), p).scalar()
    return detalle


def repuestos_de_reparacion(db: Session, id_reparacion: int) -> list[dict]:
    """Repuestos consumidos: precio historico (guardado al consumir) vs precio actual del catalogo."""
    return _rows(db, """
        SELECT rr.id_repuesto, rep.codigo, rep.nombre AS repuesto, rr.cantidad,
               rr.precio_historico, rep.precio_venta AS precio_actual,
               rr.cantidad * rr.precio_historico AS subtotal, b.nombre AS bodega
        FROM ReparacionRepuesto rr
        INNER JOIN Repuesto rep ON rep.id_repuesto = rr.id_repuesto
        INNER JOIN Bodega   b   ON b.id_bodega = rr.id_bodega
        WHERE rr.id_reparacion = :id AND rr.activo = 1;""", {"id": id_reparacion})
