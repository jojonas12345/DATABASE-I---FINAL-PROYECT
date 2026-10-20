// Modulo Reportes: los 12 reportes obligatorios (seccion 5). Cada uno se
// ejecuta con SQL real en la base (endpoint /reportes/{n}); aqui solo se
// eligen los filtros y se muestra el resultado, nada se arma en el frontend.
import { useEffect, useMemo, useState } from "react";
import { getReportes, ejecutarReporte } from "../api/reportes";
import { getClientes } from "../api/clientes";
import { getTecnicos, getBodegas, getCategorias, getProveedores } from "../api/catalogos";
import { Card, Field, Input, Select, Msg, DataTable, useMsg, money } from "../components/ui";

const ESTADOS_ACTIVOS = ["RECIBIDO", "DIAGNOSTICO", "ESPERANDO_AUTORIZACION", "REPARACION", "LISTO"];
const opts = (arr) => arr.map((v) => ({ value: v, label: v }));

// Definicion de filtros por reporte: {nombre, label, tipo, fuente|opciones, requerido}
const FILTROS = {
  1: [{ n: "estado", l: "Estado", t: "select", o: opts(ESTADOS_ACTIVOS) },
      { n: "prioridad", l: "Prioridad", t: "select", o: opts(["ALTA", "MEDIA", "BAJA"]) },
      { n: "id_tecnico", l: "Tecnico", t: "select", f: "tecnicos" }],
  2: [{ n: "id_cliente", l: "Cliente", t: "select", f: "clientes", req: true }],
  3: [{ n: "serie", l: "Numero de serie (o parte)", t: "text", req: true }],
  4: [{ n: "id_tecnico", l: "Tecnico", t: "select", f: "tecnicos" },
      { n: "desde", l: "Desde", t: "date" }, { n: "hasta", l: "Hasta", t: "date" }],
  5: [{ n: "numero_orden", l: "Numero de orden", t: "text" },
      { n: "id_tecnico", l: "Tecnico", t: "select", f: "tecnicos" },
      { n: "id_bodega", l: "Bodega", t: "select", f: "bodegas" }],
  6: [{ n: "id_bodega", l: "Bodega", t: "select", f: "bodegas" },
      { n: "id_categoria", l: "Categoria", t: "select", f: "categorias" }],
  7: [{ n: "id_bodega", l: "Bodega", t: "select", f: "bodegas" }],
  8: [{ n: "id_proveedor", l: "Proveedor", t: "select", f: "proveedores" },
      { n: "estado", l: "Estado", t: "select", o: opts(["PENDIENTE", "RECIBIDA", "ANULADA"]) },
      { n: "desde", l: "Desde", t: "date" }, { n: "hasta", l: "Hasta", t: "date" }],
  9: [{ n: "tipo", l: "Tipo", t: "select", o: opts(["ENTRADA", "SALIDA"]) },
      { n: "id_bodega", l: "Bodega", t: "select", f: "bodegas" },
      { n: "desde", l: "Desde", t: "date" }, { n: "hasta", l: "Hasta", t: "date" }],
  10: [{ n: "solo_pendientes", l: "Facturas", t: "select", sinTodos: true,
         o: [{ value: "1", label: "Solo con saldo pendiente" }, { value: "0", label: "Todas" }] },
       { n: "id_cliente", l: "Cliente", t: "select", f: "clientes" }],
  11: [{ n: "desde", l: "Desde", t: "date" }, { n: "hasta", l: "Hasta", t: "date" }],
  12: [{ n: "numero_orden", l: "Numero de orden (vacio = resumen de todas)", t: "text" }],
};
const INICIALES = { 10: { solo_pendientes: "1" }, 3: { serie: "SN100013" } };
// Columnas que se muestran como dinero
const MONTOS = /(total|saldo|monto|costo|precio|subtotal|impuesto|ingreso|valor|pagado|cobrado|mano_obra|pendiente_de_cobro)/;

export default function Reportes() {
  const [catalogo, setCatalogo] = useState([]);
  const [numero, setNumero] = useState(1);
  const [filtros, setFiltros] = useState({});
  const [res, setRes] = useState(null);
  const [cargando, setCargando] = useState(false);
  const [fuentes, setFuentes] = useState({ clientes: [], tecnicos: [], bodegas: [], categorias: [], proveedores: [] });
  const msg = useMsg();

  useEffect(() => {
    getReportes().then(setCatalogo).catch(msg.showErr);
    Promise.all([getClientes(), getTecnicos(), getBodegas(), getCategorias(), getProveedores()])
      .then(([cl, te, bo, ca, pr]) => setFuentes({
        clientes: cl.map((c) => ({ value: c.id_cliente, label: c.tipo === "INDIVIDUAL" ? `${c.nombres} ${c.apellidos}` : c.razon_social })),
        tecnicos: te.map((t) => ({ value: t.id_usuario, label: t.nombre })),
        bodegas: bo.map((b) => ({ value: b.id_bodega, label: b.nombre })),
        categorias: ca.map((c) => ({ value: c.id_categoria, label: c.nombre })),
        proveedores: pr.map((p) => ({ value: p.id_proveedor, label: p.nombre })),
      })).catch(() => {});
  }, []);

  const elegir = (n) => { setNumero(n); setFiltros(INICIALES[n] || {}); setRes(null); msg.clear(); };
  useEffect(() => { elegir(1); }, []);

  const defs = FILTROS[numero] || [];
  const faltaRequerido = defs.some((d) => d.req && !filtros[d.n]);

  const consultar = async () => {
    setCargando(true); msg.clear();
    try { setRes(await ejecutarReporte(numero, filtros)); }
    catch (e) { msg.showErr(e); setRes(null); }
    finally { setCargando(false); }
  };

  const columnas = useMemo(() => {
    const filas = res?.filas || [];
    if (!filas.length) return null;
    return Object.keys(filas[0]).map((k) => ({
      key: k,
      label: k.replace(/_/g, " ").replace(/^./, (c) => c.toUpperCase()),
      render: MONTOS.test(k) && !/^(id_|numero)/.test(k) ? (r) => money(r[k]) : undefined,
    }));
  }, [res]);

  return (
    <div>
      <h2 className="page-title">Reportes</h2>
      <Msg ok={msg.ok} err={msg.err} />

      <Card style={{ marginBottom: 16 }}>
        <Field label="Reporte">
          <Select value={numero} onChange={(e) => elegir(Number(e.target.value))}
                  options={catalogo.map((r) => ({ value: r.numero, label: `${r.numero}. ${r.titulo}` }))} />
        </Field>
        <div className="form-grid" style={{ marginTop: 10 }}>
          {defs.map((d) => (
            <Field key={d.n} label={d.l + (d.req ? " *" : "")}>
              {d.t === "select" ? (
                <Select value={filtros[d.n] ?? ""} onChange={(e) => setFiltros({ ...filtros, [d.n]: e.target.value })}
                        placeholder={d.sinTodos ? undefined : "Todos"} options={d.o || fuentes[d.f] || []} />
              ) : (
                <Input type={d.t} value={filtros[d.n] ?? ""} onChange={(e) => setFiltros({ ...filtros, [d.n]: e.target.value })} />
              )}
            </Field>
          ))}
          <div style={{ alignSelf: "end" }}>
            <button className="btn btn-primary" disabled={cargando || faltaRequerido} onClick={consultar}>
              {cargando ? "Consultando..." : "Consultar"}
            </button>
          </div>
        </div>
      </Card>

      {res && (
        <Card>
          <div className="toolbar">
            <b>{res.numero}. {res.titulo}</b>
            {res.numero === 12 && <span className="pill">{res.modo === "detalle" ? "Linea de tiempo" : "Resumen"}</span>}
            <div className="spacer" />
            <span className="muted">{res.filas.length} filas</span>
          </div>
          <DataTable rows={res.filas} columns={columnas} />
        </Card>
      )}
    </div>
  );
}
