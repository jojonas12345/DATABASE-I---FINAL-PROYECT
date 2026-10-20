// Dashboard (seccion 6.3): todo se calcula en la base de datos (endpoint /dashboard,
// que consulta las vistas del proyecto). Incluye actividad reciente.
import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { getDashboard } from "../api/dashboard";
import { useAuth } from "../context/AuthContext";
import { Card, DataTable, EstadoPill, money } from "../components/ui";

function Stat({ label, value, hint, rojo, onClick }) {
  return (
    <div className={"card stat" + (onClick ? " clickable" : "")} onClick={onClick}>
      <div className="label">{label}</div>
      <div className={"value" + (rojo ? " rojo" : "")}>{value ?? "..."}</div>
      {hint && <div className="hint">{hint}</div>}
    </div>
  );
}

export default function Dashboard() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [d, setD] = useState(null);
  const [error, setError] = useState("");

  useEffect(() => {
    getDashboard().then(setD).catch(() => setError("No se pudo cargar el dashboard"));
  }, []);

  const i = d?.indicadores || {};
  const a = d?.actividad || {};
  const ir = (ruta) => () => navigate(ruta);

  return (
    <div>
      <h2 className="page-title">Hola, {user?.nombre?.split(" ")[0]}</h2>
      <p className="muted" style={{ marginTop: -8 }}>Resumen del taller — rol <b>{user?.rol}</b></p>
      {error && <div className="msg err">{error}</div>}

      <div className="grid cards" style={{ marginTop: 16 }}>
        <Stat label="Ordenes abiertas" value={i.ordenes_abiertas} hint="En taller (no entregadas ni canceladas)" onClick={ir("/ordenes")} />
        <Stat label="En diagnostico" value={i.ordenes_en_diagnostico}
              hint={`+ ${i.ordenes_esperando_autorizacion ?? 0} esperando autorizacion`} />
        <Stat label="En reparacion" value={i.ordenes_en_reparacion} hint="Trabajo en proceso" />
        <Stat label="Listas para entregar" value={i.ordenes_listas_para_entregar} hint="Estado LISTO" />
        <Stat label="Facturas con saldo" value={i.facturas_con_saldo} rojo
              hint={`Por cobrar: ${money(i.saldo_por_cobrar)}`} />
        <Stat label="Repuestos bajo minimo" value={i.repuestos_bajo_minimo} rojo
              hint={`${i.compras_pendientes ?? 0} compras pendientes de recibir`} />
      </div>

      <h3 style={{ margin: "24px 0 10px" }}>Actividad reciente</h3>
      <div className="two-col">
        <Card>
          <b>Ultimos movimientos de inventario</b>
          <DataTable rows={a.movimientos} columns={[
            { key: "fecha", label: "Fecha" },
            { key: "tipo", label: "Tipo", render: (r) =>
                <span className={"pill " + (r.tipo === "ENTRADA" ? "ok" : "warn")}>{r.tipo}</span> },
            { key: "repuesto", label: "Repuesto" },
            { key: "cantidad", label: "Cant." },
            { key: "doc_tipo", label: "Origen" },
            { key: "usuario", label: "Usuario" },
          ]} />
        </Card>
        <Card>
          <b>Ultimos cambios de estado</b>
          <DataTable rows={a.cambios_estado} columns={[
            { key: "fecha", label: "Fecha" },
            { key: "numero_orden", label: "Orden" },
            { key: "cambio", label: "Cambio", render: (r) =>
                <>{r.estado_anterior || "(inicio)"} → <EstadoPill estado={r.estado_nuevo} /></> },
            { key: "usuario", label: "Usuario" },
          ]} />
        </Card>
      </div>

      <div className="two-col" style={{ marginTop: 16 }}>
        <Card>
          <b>Reparaciones recientes</b>
          <DataTable rows={a.reparaciones} columns={[
            { key: "numero_orden", label: "Orden" },
            { key: "estado_reparacion", label: "Estado" },
            { key: "tecnico", label: "Tecnico" },
            { key: "equipo", label: "Equipo", render: (r) => `${r.tipo_equipo} ${r.marca}` },
            { key: "total_orden", label: "Total orden", render: (r) => money(r.total_orden) },
          ]} />
        </Card>
        <Card>
          <b>Repuestos en o bajo el minimo</b>
          <DataTable rows={a.bajo_stock} columns={[
            { key: "codigo", label: "Codigo" },
            { key: "repuesto", label: "Repuesto" },
            { key: "bodega", label: "Bodega" },
            { key: "existencia", label: "Exist.", render: (r) => <span className="pill rojo">{r.existencia}</span> },
            { key: "stock_minimo", label: "Min." },
          ]} />
        </Card>
      </div>
    </div>
  );
}
