// Modulo Inventario / Bodega: existencias, catalogo de repuestos, compras con
// encabezado + detalle (registro y recepcion por SP) y kardex de movimientos.
// El stock NO se edita a mano: solo cambia por compras recibidas o consumos (2.5).
import { useEffect, useState } from "react";
import { getExistencias, getMovimientos, getCompras, getCompra, registrarCompra, recibirCompra } from "../api/inventario";
import { getRepuestos, getProveedores, getBodegas } from "../api/catalogos";
import { Card, Field, Input, Select, Msg, DataTable, Tabs, useMsg, fmt, money } from "../components/ui";

export default function Inventario() {
  const [tab, setTab] = useState("exist");
  const msg = useMsg();
  const cambiar = (t) => { msg.clear(); setTab(t); };
  return (
    <div>
      <h2 className="page-title">Inventario / Bodega</h2>
      <Msg ok={msg.ok} err={msg.err} />
      <Tabs active={tab} onChange={cambiar} tabs={[
        { key: "exist", label: "Existencias" },
        { key: "cat", label: "Catalogo de repuestos" },
        { key: "nueva", label: "Registrar compra" },
        { key: "compras", label: "Compras" },
        { key: "mov", label: "Movimientos (kardex)" },
      ]} />
      {tab === "exist" && <Existencias />}
      {tab === "cat" && <CatalogoRepuestos />}
      {tab === "nueva" && <RegistrarCompra msg={msg} onHecho={() => setTab("compras")} />}
      {tab === "compras" && <Compras msg={msg} />}
      {tab === "mov" && <Movimientos />}
    </div>
  );
}

function Existencias() {
  const [rows, setRows] = useState(null);
  const [bodega, setBodega] = useState("");
  useEffect(() => { getExistencias().then(setRows).catch(() => setRows([])); }, []);
  const bodegas = [...new Set((rows || []).map((r) => r.bodega))];
  const filas = rows ? rows.filter((r) => !bodega || r.bodega === bodega) : null;
  return (
    <Card>
      <div className="toolbar">
        <Select value={bodega} onChange={(e) => setBodega(e.target.value)} placeholder="Todas las bodegas"
                options={bodegas.map((b) => ({ value: b, label: b }))} />
      </div>
      <DataTable rows={filas} columns={[
        { key: "codigo", label: "Codigo" }, { key: "repuesto", label: "Repuesto" },
        { key: "categoria", label: "Categoria" }, { key: "bodega", label: "Bodega" },
        { key: "existencia", label: "Existencia", render: (r) =>
            <span className={"pill " + (r.existencia === 0 ? "rojo" : r.existencia <= r.stock_minimo ? "warn" : "ok")}>
              {r.existencia}</span> },
        { key: "stock_minimo", label: "Minimo" },
      ]} />
    </Card>
  );
}

function CatalogoRepuestos() {
  const [rows, setRows] = useState(null);
  useEffect(() => { getRepuestos().then(setRows).catch(() => setRows([])); }, []);
  return (
    <Card>
      <p className="muted" style={{ marginTop: 0, fontSize: 13 }}>
        Catalogo con codigo unico, precio de compra de referencia y precio de venta.
        Se administra (crear/editar/desactivar) en el modulo Administracion.
      </p>
      <DataTable rows={rows} columns={[
        { key: "codigo", label: "Codigo" }, { key: "nombre", label: "Repuesto" },
        { key: "categoria", label: "Categoria" },
        { key: "precio_compra_ref", label: "Precio compra ref.", render: (r) => money(r.precio_compra_ref) },
        { key: "precio_venta", label: "Precio venta", render: (r) => money(r.precio_venta) },
        { key: "existencia_total", label: "Existencia total" },
      ]} />
    </Card>
  );
}

function RegistrarCompra({ msg, onHecho }) {
  const [repuestos, setRepuestos] = useState([]);
  const [proveedores, setProveedores] = useState([]);
  const [bodegas, setBodegas] = useState([]);
  const [cab, setCab] = useState({});
  const [lineas, setLineas] = useState([{ cantidad: "1", costo: "" }]);
  const [enviando, setEnviando] = useState(false);

  useEffect(() => {
    getRepuestos().then(setRepuestos); getProveedores().then(setProveedores); getBodegas().then(setBodegas);
  }, []);

  const setLinea = (i, campo, valor) => setLineas(lineas.map((l, k) => (k === i ? { ...l, [campo]: valor } : l)));
  const elegirRepuesto = (i, id) => {
    const rep = repuestos.find((r) => r.id_repuesto === id);
    setLineas(lineas.map((l, k) => (k === i ? { ...l, id_repuesto: id, costo: l.costo || String(rep?.precio_compra_ref ?? "") } : l)));
  };
  const total = lineas.reduce((s, l) => s + (Number(l.cantidad) || 0) * (Number(l.costo) || 0), 0);

  const guardar = async (recibir) => {
    setEnviando(true);
    try {
      const r = await registrarCompra({
        id_proveedor: cab.id_proveedor, id_bodega: cab.id_bodega, recibir,
        detalle: lineas.map((l) => ({ id_repuesto: l.id_repuesto, cantidad: Number(l.cantidad), costo: Number(l.costo) })),
      });
      msg.showOk(`${r.mensaje} (compra #${r.id_compra})`);
      setCab({}); setLineas([{ cantidad: "1", costo: "" }]);
      onHecho();
    } catch (e) { msg.showErr(e); } finally { setEnviando(false); }
  };

  return (
    <Card>
      <p className="muted" style={{ marginTop: 0, fontSize: 13 }}>
        Encabezado + detalle. <b>Registrar</b> deja la compra PENDIENTE (usp_RegistrarCompra);
        <b> Registrar y recibir</b> ademas la ingresa al inventario con sus movimientos de entrada (usp_RecibirCompra).
      </p>
      <div className="form-grid">
        <Field label="Proveedor">
          <Select value={cab.id_proveedor || ""} onChange={(e) => setCab({ ...cab, id_proveedor: Number(e.target.value) })}
                  placeholder="Selecciona" options={proveedores.map((p) => ({ value: p.id_proveedor, label: p.nombre }))} />
        </Field>
        <Field label="Bodega destino">
          <Select value={cab.id_bodega || ""} onChange={(e) => setCab({ ...cab, id_bodega: Number(e.target.value) })}
                  placeholder="Selecciona" options={bodegas.map((b) => ({ value: b.id_bodega, label: b.nombre }))} />
        </Field>
      </div>

      <h4 style={{ margin: "16px 0 6px" }}>Detalle</h4>
      {lineas.map((l, i) => (
        <div className="form-row" key={i} style={{ marginBottom: 6 }}>
          <div style={{ flex: 2, minWidth: 200 }}>
            <Select value={l.id_repuesto || ""} onChange={(e) => elegirRepuesto(i, Number(e.target.value))}
                    placeholder="Repuesto" options={repuestos.map((r) => ({ value: r.id_repuesto, label: `${r.codigo} - ${r.nombre}` }))} />
          </div>
          <div style={{ width: 110 }}>
            <Input type="number" min="1" placeholder="Cantidad" value={l.cantidad} onChange={(e) => setLinea(i, "cantidad", e.target.value)} />
          </div>
          <div style={{ width: 140 }}>
            <Input type="number" min="0" placeholder="Costo unitario" value={l.costo} onChange={(e) => setLinea(i, "costo", e.target.value)} />
          </div>
          <span className="muted" style={{ width: 110 }}>{money((Number(l.cantidad) || 0) * (Number(l.costo) || 0))}</span>
          <button className="btn btn-ghost btn-sm" disabled={lineas.length === 1}
                  onClick={() => setLineas(lineas.filter((_, k) => k !== i))}>Quitar</button>
        </div>
      ))}
      <div className="toolbar" style={{ marginTop: 10 }}>
        <button className="btn btn-ghost btn-sm" onClick={() => setLineas([...lineas, { cantidad: "1", costo: "" }])}>+ Agregar repuesto</button>
        <div className="spacer" />
        <b>Total: {money(total)}</b>
      </div>
      <div className="toolbar">
        <button className="btn btn-ghost" disabled={enviando} onClick={() => guardar(false)}>Registrar (pendiente)</button>
        <button className="btn btn-primary" disabled={enviando} onClick={() => guardar(true)}>Registrar y recibir</button>
      </div>
    </Card>
  );
}

function Compras({ msg }) {
  const [rows, setRows] = useState(null);
  const [sel, setSel] = useState(null);
  const [det, setDet] = useState(null);
  const cargar = () => getCompras().then(setRows).catch(() => setRows([]));
  useEffect(() => { cargar(); }, []);

  const abrir = (c) => { setSel(c); setDet(null); getCompra(c.id_compra).then(setDet).catch(msg.showErr); };
  const recibir = async () => {
    try {
      await recibirCompra(sel.id_compra);
      msg.showOk(`Compra ${sel.numero} recibida: inventario y movimientos actualizados`);
      cargar(); getCompra(sel.id_compra).then(setDet);
    } catch (e) { msg.showErr(e); }
  };

  return (
    <div className="two-col">
      <Card>
        <DataTable rows={rows} idKey="id_compra" selectedId={sel?.id_compra} onRowClick={abrir} columns={[
          { key: "numero", label: "No." }, { key: "fecha", label: "Fecha" },
          { key: "proveedor", label: "Proveedor" },
          { key: "estado", label: "Estado", render: (r) =>
              <span className={"pill " + (r.estado === "RECIBIDA" ? "ok" : r.estado === "PENDIENTE" ? "warn" : "rojo")}>{r.estado}</span> },
          { key: "renglones", label: "Reng." },
          { key: "total", label: "Total", render: (r) => money(r.total) },
        ]} />
      </Card>
      <Card>
        {!sel && <p className="muted">Selecciona una compra para ver su detalle.</p>}
        {sel && !det && <p className="muted">Cargando...</p>}
        {det && (
          <>
            <div className="toolbar">
              <b>Compra {det.numero}</b>
              <span className="pill">{det.estado}</span>
              <div className="spacer" />
              {det.estado === "PENDIENTE" && <button className="btn btn-primary btn-sm" onClick={recibir}>Recibir en inventario</button>}
            </div>
            <div className="info-grid">
              <div><span className="muted">Proveedor</span><b>{det.proveedor} — {det.nit_proveedor}</b></div>
              <div><span className="muted">Bodega</span><b>{det.bodega}</b></div>
              <div><span className="muted">Fecha</span><b>{fmt(det.fecha)}</b></div>
              <div><span className="muted">Registrada por</span><b>{det.registrada_por}</b></div>
            </div>
            <DataTable rows={det.lineas} columns={[
              { key: "codigo", label: "Codigo" }, { key: "repuesto", label: "Repuesto" },
              { key: "cantidad", label: "Cant." },
              { key: "costo_historico", label: "Costo historico", render: (x) => money(x.costo_historico) },
              { key: "costo_actual", label: "Costo ref. actual", render: (x) => (
                  <span className={Number(x.costo_actual) !== Number(x.costo_historico) ? "pill warn" : ""}>{money(x.costo_actual)}</span>) },
              { key: "subtotal", label: "Subtotal", render: (x) => money(x.subtotal) },
            ]} />
            <div className="totales"><span>Total <b>{money(det.total)}</b></span></div>
          </>
        )}
      </Card>
    </div>
  );
}

function Movimientos() {
  const [rows, setRows] = useState(null);
  useEffect(() => { getMovimientos().then(setRows).catch(() => setRows([])); }, []);
  return (
    <Card>
      <DataTable rows={rows} columns={[
        { key: "fecha", label: "Fecha" }, { key: "repuesto", label: "Repuesto" },
        { key: "bodega", label: "Bodega" },
        { key: "tipo", label: "Tipo", render: (r) => <span className={"pill " + (r.tipo === "ENTRADA" ? "ok" : "warn")}>{r.tipo}</span> },
        { key: "cantidad", label: "Cant." },
        { key: "doc_tipo", label: "Origen", render: (r) => `${r.doc_tipo} #${r.doc_referencia}` },
        { key: "existencia_resultante", label: "Saldo" },
        { key: "usuario", label: "Usuario" },
      ]} />
    </Card>
  );
}
