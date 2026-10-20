"""Repository de Facturacion y Pagos. Invoca usp_GenerarFactura y usp_RegistrarPago;
las lecturas usan la vista vw_FacturasConSaldo y consultas con columnas explicitas."""
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.db.sp import exec_sp_output


def generar_factura(db: Session, id_orden: int, id_usuario: int) -> int:
    return exec_sp_output(db, "usp_GenerarFactura",
                          {"id_orden": id_orden, "id_usuario": id_usuario}, output_name="id_factura")


def registrar_pago(db: Session, id_factura: int, id_metodo: int, monto: float, referencia: str | None) -> int:
    return exec_sp_output(db, "usp_RegistrarPago", {
        "id_factura": id_factura, "id_metodo": id_metodo, "monto": monto, "referencia": referencia,
    }, output_name="id_pago")


def listar_con_saldo(db: Session) -> list[dict]:
    sql = text("""
        SELECT id_factura, numero, fecha, id_orden, numero_orden, nombre_facturacion,
               nit, total, pagado, saldo, estado
        FROM vw_FacturasConSaldo
        ORDER BY fecha DESC;""")
    return [dict(r) for r in db.execute(sql).mappings().all()]


def detalle(db: Session, id_factura: int) -> dict | None:
    cab = db.execute(text("""
        SELECT f.id_factura, f.numero, f.fecha, f.nit, f.nombre_facturacion,
               f.subtotal, f.impuesto, f.total, f.estado, o.numero AS numero_orden,
               dbo.fn_SaldoFactura(f.id_factura) AS saldo
        FROM Factura f INNER JOIN OrdenServicio o ON o.id_orden = f.id_orden
        WHERE f.id_factura = :id;"""), {"id": id_factura}).mappings().first()
    if not cab:
        return None
    det = dict(cab)
    # precio_historico: el precio con que se facturo (no cambia aunque cambie el catalogo)
    det["lineas"] = [dict(r) for r in db.execute(text("""
        SELECT tipo, descripcion, cantidad, precio_historico, subtotal
        FROM DetalleFactura WHERE id_factura = :id AND activo = 1
        ORDER BY CASE tipo WHEN 'MANO_OBRA' THEN 1 ELSE 2 END, id_detalle;"""),
        {"id": id_factura}).mappings().all()]
    det["pagos"] = [dict(r) for r in db.execute(text("""
        SELECT p.fecha, mp.nombre AS metodo, p.monto, p.referencia
        FROM Pago p INNER JOIN MetodoPago mp ON mp.id_metodo = p.id_metodo
        WHERE p.id_factura = :id AND p.activo = 1 ORDER BY p.fecha;"""),
        {"id": id_factura}).mappings().all()]
    return det
