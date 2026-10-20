// Modulo Caja: facturas con saldo, detalle de cada factura (renglones a precio
// historico + pagos) y registro de pagos parciales o totales (SP usp_RegistrarPago).
import { useEffect, useState } from "react";
import { getFacturas, getFactura, registrarPago } from "../api/facturas";
import { getMetodosPago } from "../api/catalogos";
import { Card, Field, Input, Select, Msg, DataTable, useMsg, money } from "../components/ui";
import DetalleFactura from "../components/DetalleFactura";

export default function Caja() {
  const [facturas, setFacturas] = useState(null);
  const [soloPendientes, setSoloPendientes] = useState(true);
  const [metodos, setMetodos] = useState([]);
  const [sel, setSel] = useState(null);
  const [fac, setFac] = useState(null);
  const [pago, setPago] = useState({ monto: "" });
  const msg = useMsg();

  const cargar = () => getFacturas().then(setFacturas).catch(msg.showErr);
  useEffect(() => { cargar(); getMetodosPago().then(setMetodos); }, []);

  const abrir = (f) => {
    setSel(f); setFac(null); msg.clear();
    setPago({ monto: Number(f.saldo) > 0 ? String(f.saldo) : "" });
    getFactura(f.id_factura).then(setFac).catch(msg.showErr);
  };

  const cobrar = async () => {
    try {
      await registrarPago({
        id_factura: sel.id_factura, id_metodo: pago.id_metodo,
        monto: Number(pago.monto), referencia: pago.referencia || null,
      });
      msg.showOk("Pago registrado");
      const nueva = await getFactura(sel.id_factura);
      setFac(nueva);
      setSel({ ...sel, saldo: nueva.saldo });
      setPago({ monto: Number(nueva.saldo) > 0 ? String(nueva.saldo) : "" });
      cargar();
    } catch (e) { msg.showErr(e); }
  };

  const filas = (facturas || []).filter((f) => !soloPendientes || Number(f.saldo) > 0);
  const saldo = Number(sel?.saldo || 0);

  return (
    <div>
      <h2 className="page-title">Caja — Facturacion y pagos</h2>
      <Msg ok={msg.ok} err={msg.err} />

      <div className="two-col">
        <Card>
          <div className="toolbar">
            <b>Facturas</b>
            <div className="spacer" />
            <label className="check">
              <input type="checkbox" checked={soloPendientes} onChange={(e) => setSoloPendientes(e.target.checked)} />
              Solo con saldo pendiente
            </label>
          </div>
          <DataTable rows={facturas ? filas : null} idKey="id_factura" selectedId={sel?.id_factura} onRowClick={abrir}
            columns={[
              { key: "numero", label: "No." },
              { key: "numero_orden", label: "Orden" },
              { key: "nombre_facturacion", label: "Cliente" },
              { key: "total", label: "Total", render: (r) => money(r.total) },
              { key: "saldo", label: "Saldo", render: (r) =>
                  <span className={"pill " + (Number(r.saldo) > 0 ? "rojo" : "ok")}>{money(r.saldo)}</span> },
            ]} />
        </Card>

        <Card>
          {!sel && <p className="muted">Selecciona una factura para ver su detalle y registrar pagos.</p>}
          {sel && (
            <>
              <b>Registrar pago</b>
              {saldo <= 0 ? (
                <p className="muted">Esta factura ya esta saldada; no requiere pago.</p>
              ) : (
                <div className="form-grid" style={{ margin: "10px 0 16px" }}>
                  <Field label="Metodo de pago">
                    <Select value={pago.id_metodo || ""} onChange={(e) => setPago({ ...pago, id_metodo: Number(e.target.value) })}
                            placeholder="Selecciona" options={metodos.map((m) => ({ value: m.id_metodo, label: m.nombre }))} />
                  </Field>
                  <Field label={`Monto (saldo ${money(saldo)})`}>
                    <Input type="number" min="0" value={pago.monto} onChange={(e) => setPago({ ...pago, monto: e.target.value })} />
                  </Field>
                  <Field label="Referencia (opcional)">
                    <Input value={pago.referencia || ""} onChange={(e) => setPago({ ...pago, referencia: e.target.value })} />
                  </Field>
                  <div style={{ alignSelf: "end" }}>
                    <button className="btn btn-primary" disabled={!pago.id_metodo || !(Number(pago.monto) > 0)} onClick={cobrar}>
                      Registrar pago
                    </button>
                  </div>
                </div>
              )}
              <DetalleFactura fac={fac} />
            </>
          )}
        </Card>
      </div>
    </div>
  );
}
