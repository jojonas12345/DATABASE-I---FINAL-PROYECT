"""
Repository de Compras. Solo invoca procedimientos almacenados:
  - usp_RegistrarCompraRepuesto: compra de un repuesto, recibida al instante.
  - usp_RegistrarCompra: encabezado + detalle (varios repuestos), queda PENDIENTE.
  - usp_RecibirCompra: recibe una compra PENDIENTE -> inventario + movimientos.
Toda la validacion y la atomicidad viven dentro de los SP.
"""
import json

from sqlalchemy.orm import Session

from app.db.sp import exec_sp, exec_sp_output


def registrar_compra_repuesto(db: Session, id_proveedor: int, id_bodega: int, id_usuario: int,
                              id_repuesto: int, cantidad: int, costo_unitario: float) -> int:
    return exec_sp_output(db, "usp_RegistrarCompraRepuesto", {
        "id_proveedor": id_proveedor, "id_bodega": id_bodega, "id_usuario": id_usuario,
        "id_repuesto": id_repuesto, "cantidad": cantidad, "costo_unitario": costo_unitario,
    }, output_name="id_compra")


def registrar_compra(db: Session, id_proveedor: int, id_bodega: int, id_usuario: int,
                     detalle: list[dict]) -> int:
    # El detalle viaja como JSON en UN parametro; el SP lo lee con OPENJSON.
    return exec_sp_output(db, "usp_RegistrarCompra", {
        "id_proveedor": id_proveedor, "id_bodega": id_bodega, "id_usuario": id_usuario,
        "detalle": json.dumps(detalle),
    }, output_name="id_compra")


def recibir_compra(db: Session, id_compra: int, id_usuario: int) -> None:
    exec_sp(db, "usp_RecibirCompra", {"id_compra": id_compra, "id_usuario": id_usuario})
