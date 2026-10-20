// Detalle de una factura: renglones a precio historico, totales, saldo y pagos.
import { DataTable, fmt, money } from "./ui";

export default function DetalleFactura({ fac }) {
  if (!fac) return <p className="muted">Cargando factura...</p>;
  return (
    <div>
      <div className="info-grid">
        <div><span className="muted">Factura</span><b>{fac.numero}</b></div>
        <div><span className="muted">Fecha</span><b>{fmt(fac.fecha)}</b></div>
        <div><span className="muted">Facturado a</span><b>{fac.nombre_facturacion} — {fac.nit}</b></div>
        <div><span className="muted">Estado</span><b>{fac.estado}</b></div>
      </div>
      <b>Detalle (precios historicos)</b>
      <DataTable rows={fac.lineas} columns={[
        { key: "tipo", label: "Tipo" },
        { key: "descripcion", label: "Descripcion" },
        { key: "cantidad", label: "Cant." },
        { key: "precio_historico", label: "Precio historico", render: (x) => money(x.precio_historico) },
        { key: "subtotal", label: "Subtotal", render: (x) => money(x.subtotal) },
      ]} />
      <div className="totales">
        <span>Subtotal <b>{money(fac.subtotal)}</b></span>
        <span>Impuesto (12%) <b>{money(fac.impuesto)}</b></span>
        <span>Total <b>{money(fac.total)}</b></span>
        <span>Saldo <b className={Number(fac.saldo) > 0 ? "rojo" : "verde"}>{money(fac.saldo)}</b></span>
      </div>
      <b>Pagos recibidos</b>
      <DataTable rows={fac.pagos} columns={[
        { key: "fecha", label: "Fecha" },
        { key: "metodo", label: "Metodo" },
        { key: "monto", label: "Monto", render: (x) => money(x.monto) },
        { key: "referencia", label: "Referencia" },
      ]} />
      <p className="muted" style={{ fontSize: 12 }}>
        Los precios quedan guardados al momento de la operacion: si el catalogo cambia, esta factura no se altera.
      </p>
    </div>
  );
}
