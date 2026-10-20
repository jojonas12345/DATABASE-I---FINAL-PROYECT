// Modulo Ordenes: lista + alta + detalle con pestanas que recorren el flujo
// (Datos / Historial / Diagnostico / Reparacion / Factura / Entrega).
// Cada accion invoca un procedimiento almacenado; las reglas (R04, saldo, etc.)
// las valida la base de datos y aqui solo se muestra el resultado.
import { useEffect, useState } from "react";
import { useAuth } from "../context/AuthContext";
import {
  getOrdenes, getOrdenDetalle, crearOrden, cambiarEstado,
  crearDiagnostico, crearReparacion, finalizarReparacion,
  consumirRepuesto, getRepuestosReparacion, crearEntrega,
} from "../api/ordenes";
import { generarFactura, getFactura } from "../api/facturas";
import { getClientes } from "../api/clientes";
import { getEquiposDeCliente, getRepuestos, getBodegas } from "../api/catalogos";
import { Card, Field, Input, Select, Msg, DataTable, Tabs, useMsg, fmt, money, EstadoPill } from "../components/ui";
import DetalleFactura from "../components/DetalleFactura";

const ESTADOS = ["RECIBIDO", "DIAGNOSTICO", "ESPERANDO_AUTORIZACION", "REPARACION", "LISTO", "ENTREGADO", "CANCELADO"];
// ENTREGADO no se elige a mano: se llega por el proceso de entrega (valida factura y saldo)
const ESTADOS_MANUALES = ESTADOS.filter((e) => e !== "ENTREGADO");

export default function Ordenes() {
  const { user } = useAuth();
  const rol = user?.rol;
  const esAdmin = rol === "Administrador";

  const [filtro, setFiltro] = useState("");
  const [ordenes, setOrdenes] = useState(null);
  const [detalle, setDetalle] = useState(null);
  const [tab, setTab] = useState("datos");
  const [nuevo, setNuevo] = useState(false);
  const msg = useMsg();

  const cargar = () => getOrdenes(filtro || undefined).then(setOrdenes).catch(msg.showErr);
  useEffect(() => { cargar(); }, [filtro]);

  const abrir = (o) => {
    setTab("datos"); setDetalle(null); msg.clear();
    getOrdenDetalle(o.id_orden).then(setDetalle).catch(msg.showErr);
  };
  // Tras cada accion se recarga el detalle y la lista (el estado puede haber cambiado)
  const refrescar = () => {
    if (detalle) getOrdenDetalle(detalle.id_orden).then(setDetalle);
    cargar();
  };
  const props = { d: detalle, rol, onChange: refrescar, onErr: msg.showErr, onOk: msg.showOk };

  return (
    <div>
      <h2 className="page-title">Ordenes de servicio</h2>
      <Msg ok={msg.ok} err={msg.err} />

      <div className="toolbar">
        <Field label="Filtrar por estado">
          <Select value={filtro} onChange={(e) => setFiltro(e.target.value)} placeholder="Todas"
                  options={ESTADOS.map((e) => ({ value: e, label: e }))} />
        </Field>
        <div className="spacer" />
        {(esAdmin || rol === "Recepcion") && (
          <button className="btn btn-primary" style={{ alignSelf: "end" }} onClick={() => setNuevo(!nuevo)}>
            {nuevo ? "Cancelar" : "Nueva orden"}
          </button>
        )}
      </div>

      {nuevo && <NuevaOrden onDone={() => { setNuevo(false); cargar(); msg.showOk("Orden creada en estado RECIBIDO"); }}
                            onErr={msg.showErr} />}

      <div className="two-col">
        <Card>
          <DataTable rows={ordenes} idKey="id_orden" selectedId={detalle?.id_orden} onRowClick={abrir}
            columns={[
              { key: "numero", label: "No." },
              { key: "cliente", label: "Cliente" },
              { key: "estado", label: "Estado", render: (r) => <EstadoPill estado={r.estado} /> },
              { key: "prioridad", label: "Prior." },
            ]} />
        </Card>

        <Card>
          {!detalle && <p className="muted">Selecciona una orden para ver su detalle.</p>}
          {detalle && (
            <>
              <div style={{ marginBottom: 8 }}>
                <b>{detalle.numero}</b> <EstadoPill estado={detalle.estado} />
                <div className="muted" style={{ fontSize: 13 }}>
                  {detalle.cliente} — {detalle.tipo_equipo} {detalle.marca} (serie {detalle.serie})
                </div>
              </div>
              <Tabs active={tab} onChange={setTab} tabs={[
                { key: "datos", label: "Datos" },
                { key: "hist", label: `Historial (${detalle.historial?.length || 0})` },
                { key: "diag", label: "Diagnostico" },
                { key: "rep", label: "Reparacion" },
                { key: "fact", label: "Factura" },
                { key: "entrega", label: "Entrega" },
              ]} />
              {tab === "datos" && <TabDatos {...props} />}
              {tab === "hist" && <TabHistorial {...props} />}
              {tab === "diag" && <TabDiagnostico {...props} />}
              {tab === "rep" && <TabReparacion {...props} />}
              {tab === "fact" && <TabFactura {...props} />}
              {tab === "entrega" && <TabEntrega {...props} />}
            </>
          )}
        </Card>
      </div>
    </div>
  );
}

// ---------- Nueva orden ----------
function NuevaOrden({ onDone, onErr }) {
  const [clientes, setClientes] = useState([]);
  const [equipos, setEquipos] = useState([]);
  const [f, setF] = useState({ prioridad: "MEDIA" });
  useEffect(() => { getClientes().then(setClientes); }, []);
  const elegirCliente = (id) => {
    setF({ ...f, id_cliente: id, id_equipo: undefined });
    getEquiposDeCliente(id).then(setEquipos);
  };
  const nombre = (c) => (c.tipo === "INDIVIDUAL" ? `${c.nombres} ${c.apellidos}` : c.razon_social);
  const guardar = async () => {
    try { await crearOrden(f); onDone(); } catch (e) { onErr(e); }
  };
  return (
    <Card style={{ marginBottom: 16 }}>
      <div className="form-grid">
        <Field label="Cliente">
          <Select value={f.id_cliente || ""} onChange={(e) => elegirCliente(Number(e.target.value))}
                  placeholder="Selecciona" options={clientes.map((c) => ({ value: c.id_cliente, label: nombre(c) }))} />
        </Field>
        <Field label="Equipo">
          <Select value={f.id_equipo || ""} onChange={(e) => setF({ ...f, id_equipo: Number(e.target.value) })}
                  placeholder="Selecciona" options={equipos.map((x) => ({ value: x.id_equipo, label: `${x.tipo} ${x.marca} - ${x.serie}` }))} />
        </Field>
        <Field label="Prioridad">
          <Select value={f.prioridad} onChange={(e) => setF({ ...f, prioridad: e.target.value })}
                  options={["ALTA", "MEDIA", "BAJA"].map((p) => ({ value: p, label: p }))} />
        </Field>
        <Field label="Fecha estimada">
          <Input type="date" value={f.fecha_estimada || ""} onChange={(e) => setF({ ...f, fecha_estimada: e.target.value || null })} />
        </Field>
        <Field label="Problema reportado">
          <Input value={f.problema || ""} onChange={(e) => setF({ ...f, problema: e.target.value })} />
        </Field>
        <div style={{ alignSelf: "end" }}>
          <button className="btn btn-primary" onClick={guardar}>Crear orden</button>
        </div>
      </div>
    </Card>
  );
}

// ---------- Tab Datos ----------
function TabDatos({ d, rol, onChange, onErr, onOk }) {
  const [estado, setEstado] = useState("");
  const [obs, setObs] = useState("");
  const puede = ["Administrador", "Recepcion", "Tecnico"].includes(rol);
  const cambiar = async () => {
    try {
      await cambiarEstado(d.id_orden, { estado_nuevo: estado, observacion: obs || null });
      onOk(`Estado cambiado a ${estado} (queda registrado en el historial)`);
      setEstado(""); setObs(""); onChange();
    } catch (e) { onErr(e); }
  };
  return (
    <div>
      <div className="info-grid">
        <div><span className="muted">Recepcionista</span><b>{d.recepcionista}</b></div>
        <div><span className="muted">Fecha de ingreso</span><b>{fmt(d.fecha_ingreso)}</b></div>
        <div><span className="muted">Fecha estimada</span><b>{fmt(d.fecha_estimada)}</b></div>
        <div><span className="muted">Prioridad</span><b>{d.prioridad}</b></div>
        <div><span className="muted">Cliente / NIT</span><b>{d.cliente} — {d.nit}</b></div>
        <div><span className="muted">Total de la orden</span><b>{money(d.total_orden)}</b></div>
      </div>
      <p><b>Problema:</b> {d.problema}</p>
      {puede && !["ENTREGADO", "CANCELADO"].includes(d.estado) && (
        <div className="form-row">
          <Field label="Cambiar estado a">
            <Select value={estado} onChange={(e) => setEstado(e.target.value)} placeholder="Selecciona"
                    options={ESTADOS_MANUALES.filter((e) => e !== d.estado).map((e) => ({ value: e, label: e }))} />
          </Field>
          <Field label="Observacion">
            <Input value={obs} onChange={(e) => setObs(e.target.value)} />
          </Field>
          <button className="btn btn-primary" disabled={!estado} onClick={cambiar}>Aplicar</button>
        </div>
      )}
      <p className="muted" style={{ fontSize: 12 }}>
        La entrega se registra en la pestana Entrega (exige factura saldada). Pasar a REPARACION exige
        diagnostico previo y a LISTO una reparacion finalizada; lo valida la base de datos.
      </p>
    </div>
  );
}

// ---------- Tab Historial (R05) ----------
function TabHistorial({ d }) {
  return (
    <div>
      <p className="muted" style={{ fontSize: 13 }}>
        Cada cambio de estado lo registra el trigger <b>trg_Orden_AuditoriaEstado</b> en la tabla
        HistorialEstadoOrden (R05).
      </p>
      <DataTable rows={d.historial} columns={[
        { key: "fecha", label: "Fecha" },
        { key: "estado_anterior", label: "Estado anterior", render: (r) => r.estado_anterior || "(inicio)" },
        { key: "estado_nuevo", label: "Estado nuevo", render: (r) => <EstadoPill estado={r.estado_nuevo} /> },
        { key: "usuario", label: "Usuario responsable" },
        { key: "observacion", label: "Observacion" },
      ]} />
    </div>
  );
}

// ---------- Tab Diagnostico ----------
function TabDiagnostico({ d, rol, onChange, onErr, onOk }) {
  const puede = (rol === "Administrador" || rol === "Tecnico") && !["LISTO", "ENTREGADO", "CANCELADO"].includes(d.estado);
  const [f, setF] = useState({ descripcion: "", costo_mano_obra: "" });
  const guardar = async () => {
    try {
      await crearDiagnostico(d.id_orden, { descripcion: f.descripcion, costo_mano_obra: Number(f.costo_mano_obra) || 0 });
      onOk("Diagnostico registrado"); setF({ descripcion: "", costo_mano_obra: "" }); onChange();
    } catch (e) { onErr(e); }
  };
  return (
    <div>
      <DataTable rows={d.diagnosticos} columns={[
        { key: "fecha", label: "Fecha" }, { key: "tecnico", label: "Tecnico" },
        { key: "descripcion", label: "Descripcion" },
        { key: "costo_mano_obra", label: "Costo estimado", render: (r) => money(r.costo_mano_obra) },
      ]} />
      {puede && (
        <div className="form-row" style={{ marginTop: 12 }}>
          <Field label="Descripcion"><Input value={f.descripcion} onChange={(e) => setF({ ...f, descripcion: e.target.value })} /></Field>
          <Field label="Costo estimado mano de obra">
            <Input type="number" min="0" value={f.costo_mano_obra} onChange={(e) => setF({ ...f, costo_mano_obra: e.target.value })} />
          </Field>
          <button className="btn btn-primary" onClick={guardar}>Registrar diagnostico</button>
        </div>
      )}
    </div>
  );
}

// ---------- Tab Reparacion ----------
function TabReparacion({ d, rol, onChange, onErr, onOk }) {
  const puede = (rol === "Administrador" || rol === "Tecnico") && !["LISTO", "ENTREGADO", "CANCELADO"].includes(d.estado);
  const [f, setF] = useState({ descripcion: "", costo_mano_obra: "" });
  const sinDiagnostico = (d.diagnosticos || []).length === 0;
  const crear = async () => {
    try {
      await crearReparacion(d.id_orden, { descripcion: f.descripcion, costo_mano_obra: Number(f.costo_mano_obra) || 0 });
      onOk("Reparacion iniciada"); setF({ descripcion: "", costo_mano_obra: "" }); onChange();
    } catch (e) { onErr(e); }
  };
  return (
    <div>
      {(d.reparaciones || []).length === 0 && <p className="muted">Sin reparaciones registradas.</p>}
      {(d.reparaciones || []).map((r) => (
        <Reparacion key={r.id_reparacion} r={r} rol={rol} onErr={onErr} onOk={onOk} onChange={onChange} />
      ))}
      {puede && (
        <>
          {sinDiagnostico && (
            <div className="msg err">Esta orden no tiene diagnostico: la base rechazara la reparacion (R04).</div>
          )}
          <div className="form-row" style={{ marginTop: 12 }}>
            <Field label="Descripcion del trabajo"><Input value={f.descripcion} onChange={(e) => setF({ ...f, descripcion: e.target.value })} /></Field>
            <Field label="Costo mano de obra">
              <Input type="number" min="0" value={f.costo_mano_obra} onChange={(e) => setF({ ...f, costo_mano_obra: e.target.value })} />
            </Field>
            <button className="btn btn-primary" onClick={crear}>Iniciar reparacion</button>
          </div>
        </>
      )}
    </div>
  );
}

function Reparacion({ r, rol, onErr, onOk, onChange }) {
  const puede = rol === "Administrador" || rol === "Tecnico";
  const abierta = ["PENDIENTE", "EN_PROCESO"].includes(r.estado);
  const [reps, setReps] = useState(null);
  const [repuestos, setRepuestos] = useState([]);
  const [bodegas, setBodegas] = useState([]);
  const [c, setC] = useState({ cantidad: "1" });
  const cargar = () => getRepuestosReparacion(r.id_reparacion).then(setReps).catch(() => setReps([]));
  useEffect(() => { cargar(); getRepuestos().then(setRepuestos); getBodegas().then(setBodegas); }, [r.id_reparacion]);

  const consumir = async () => {
    try {
      await consumirRepuesto(r.id_reparacion, { id_repuesto: c.id_repuesto, id_bodega: c.id_bodega, cantidad: Number(c.cantidad) });
      onOk("Repuesto consumido: inventario descontado y movimiento de salida registrado");
      setC({ cantidad: "1" }); cargar(); onChange();
    } catch (e) { onErr(e); }
  };
  const finalizar = async () => {
    try { await finalizarReparacion(r.id_reparacion); onOk("Reparacion finalizada"); onChange(); }
    catch (e) { onErr(e); }
  };

  return (
    <div className="card" style={{ marginBottom: 10 }}>
      <div className="toolbar">
        <b>Reparacion #{r.id_reparacion}</b>
        <span className={"pill " + (r.estado === "FINALIZADA" ? "ok" : "warn")}>{r.estado}</span>
        <span className="muted">{r.tecnico} · mano de obra {money(r.costo_mano_obra)}</span>
        <div className="spacer" />
        {puede && abierta && <button className="btn btn-ghost btn-sm" onClick={finalizar}>Finalizar</button>}
      </div>
      {r.descripcion && <p className="muted" style={{ marginTop: 0 }}>{r.descripcion}</p>}
      <DataTable rows={reps} columns={[
        { key: "repuesto", label: "Repuesto" },
        { key: "bodega", label: "Bodega" },
        { key: "cantidad", label: "Cant." },
        { key: "precio_historico", label: "Precio historico", render: (x) => money(x.precio_historico) },
        { key: "precio_actual", label: "Precio actual", render: (x) => (
            <span className={Number(x.precio_actual) !== Number(x.precio_historico) ? "pill warn" : ""}>
              {money(x.precio_actual)}
            </span>) },
        { key: "subtotal", label: "Subtotal", render: (x) => money(x.subtotal) },
      ]} />
      {puede && abierta && (
        <div className="form-row" style={{ marginTop: 10 }}>
          <Field label="Repuesto">
            <Select value={c.id_repuesto || ""} onChange={(e) => setC({ ...c, id_repuesto: Number(e.target.value) })}
                    placeholder="Selecciona" options={repuestos.map((x) => ({ value: x.id_repuesto, label: `${x.codigo} - ${x.nombre}` }))} />
          </Field>
          <Field label="Bodega">
            <Select value={c.id_bodega || ""} onChange={(e) => setC({ ...c, id_bodega: Number(e.target.value) })}
                    placeholder="Selecciona" options={bodegas.map((b) => ({ value: b.id_bodega, label: b.nombre }))} />
          </Field>
          <Field label="Cantidad">
            <Input type="number" min="1" value={c.cantidad} onChange={(e) => setC({ ...c, cantidad: e.target.value })} />
          </Field>
          <button className="btn btn-primary btn-sm" onClick={consumir}>Consumir</button>
        </div>
      )}
    </div>
  );
}

// ---------- Tab Factura ----------
function TabFactura({ d, rol, onChange, onErr, onOk }) {
  const puede = rol === "Administrador" || rol === "Caja";
  const [fac, setFac] = useState(null);
  useEffect(() => {
    if (d.factura) getFactura(d.factura.id_factura).then(setFac).catch(onErr);
    else setFac(null);
  }, [d.factura?.id_factura]);

  const generar = async () => {
    try { await generarFactura({ id_orden: d.id_orden }); onOk("Factura generada"); onChange(); }
    catch (e) { onErr(e); }
  };

  if (!d.factura) {
    return (
      <div>
        <p className="muted">Esta orden aun no tiene factura. Solo se factura una orden en estado LISTO.</p>
        {puede && <button className="btn btn-primary" disabled={d.estado !== "LISTO"} onClick={generar}>Generar factura</button>}
      </div>
    );
  }
  return <DetalleFactura fac={fac} />;
}

// ---------- Tab Entrega ----------
function TabEntrega({ d, rol, onChange, onErr, onOk }) {
  const puede = rol === "Administrador" || rol === "Recepcion";
  const [f, setF] = useState({ recibe: "", observaciones: "" });
  const entregar = async () => {
    try {
      await crearEntrega(d.id_orden, { recibe: f.recibe, observaciones: f.observaciones || null });
      onOk("Orden entregada y cerrada"); onChange();
    } catch (e) { onErr(e); }
  };
  if (d.entrega) {
    return (
      <div className="info-grid">
        <div><span className="muted">Recibio</span><b>{d.entrega.recibe}</b></div>
        <div><span className="muted">Entrego</span><b>{d.entrega.entregado_por}</b></div>
        <div><span className="muted">Fecha</span><b>{fmt(d.entrega.fecha)}</b></div>
        <div><span className="muted">Observaciones</span><b>{fmt(d.entrega.observaciones)}</b></div>
      </div>
    );
  }
  const saldo = d.factura ? Number(d.factura.saldo) : null;
  return (
    <div>
      <p className="muted" style={{ fontSize: 13 }}>
        Requisitos para entregar: orden en estado LISTO, factura emitida y saldo en cero.
        {d.factura ? ` Saldo actual: ${money(saldo)}.` : " Aun no hay factura."}
      </p>
      {!puede && <p className="muted">Solo Recepcion o Administrador registran la entrega.</p>}
      {puede && (
        <div className="form-row">
          <Field label="Recibe"><Input value={f.recibe} onChange={(e) => setF({ ...f, recibe: e.target.value })} /></Field>
          <Field label="Observaciones"><Input value={f.observaciones} onChange={(e) => setF({ ...f, observaciones: e.target.value })} /></Field>
          <button className="btn btn-primary" onClick={entregar}>Registrar entrega</button>
        </div>
      )}
    </div>
  );
}
