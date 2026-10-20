// Componentes de UI reutilizables para las pantallas.
import { useState } from "react";

export function Card({ children, style }) {
  return <div className="card" style={style}>{children}</div>;
}

export function Field({ label, children }) {
  return (
    <div>
      <label className="field">{label}</label>
      {children}
    </div>
  );
}

export function Input(props) {
  return <input className="input" {...props} />;
}

export function Select({ value, onChange, options, placeholder }) {
  // options: [{value, label}]
  return (
    <select className="input" value={value} onChange={onChange}>
      {placeholder && <option value="">{placeholder}</option>}
      {options.map((o) => (
        <option key={o.value} value={o.value}>{o.label}</option>
      ))}
    </select>
  );
}

export function Msg({ ok, err }) {
  if (ok) return <div className="msg ok">{ok}</div>;
  if (err) return <div className="msg err">{err}</div>;
  return null;
}

// Tabla generica: infiere columnas de las llaves de la primera fila,
// o recibe columns=[{key,label,render?}].
export function DataTable({ rows, columns, onRowClick, selectedId, idKey }) {
  if (!rows) return <p className="muted">Cargando...</p>;
  if (rows.length === 0) return <p className="muted">Sin registros.</p>;
  const cols = columns || Object.keys(rows[0]).map((k) => ({ key: k, label: labelize(k) }));
  return (
    <div style={{ overflowX: "auto" }}>
      <table className="table">
        <thead>
          <tr>{cols.map((c) => <th key={c.key}>{c.label}</th>)}</tr>
        </thead>
        <tbody>
          {rows.map((r, i) => {
            const id = idKey ? r[idKey] : i;
            const cls = (onRowClick ? "click " : "") + (selectedId === id ? "sel" : "");
            return (
              <tr key={id} className={cls} onClick={onRowClick ? () => onRowClick(r) : undefined}>
                {cols.map((c) => (
                  <td key={c.key} className={esFecha(r[c.key]) ? "nowrap" : undefined}>
                    {c.render ? c.render(r) : fmt(r[c.key])}
                  </td>
                ))}
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

const esFecha = (v) => typeof v === "string" && /^\d{4}-\d{2}-\d{2}/.test(v);

export function fmt(v) {
  if (v === null || v === undefined || v === "") return "-";
  if (typeof v === "boolean") return v ? "Si" : "No";
  if (typeof v === "string" && /^\d{4}-\d{2}-\d{2}T/.test(v)) return v.slice(0, 16).replace("T", " ");
  return String(v);
}

// "numero_orden" -> "Numero orden"
export function labelize(k) {
  const s = String(k).replace(/_/g, " ");
  return s.charAt(0).toUpperCase() + s.slice(1);
}

// Monto con 2 decimales (Q)
export function money(v) {
  if (v === null || v === undefined || v === "") return "-";
  // espacio no separable para que "Q 1,234.00" no se parta en dos lineas
  return "Q " + Number(v).toLocaleString("es-GT", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

// Pill de estado de orden con color segun etapa
export function EstadoPill({ estado }) {
  const cls = { ENTREGADO: "ok", LISTO: "ok", CANCELADO: "rojo", REPARACION: "warn",
                DIAGNOSTICO: "warn", ESPERANDO_AUTORIZACION: "warn" }[estado] || "";
  return <span className={"pill " + cls}>{estado}</span>;
}

export function Tabs({ tabs, active, onChange }) {
  return (
    <div className="tabs">
      {tabs.map((t) => (
        <button key={t.key} className={"tab" + (active === t.key ? " active" : "")}
                onClick={() => onChange(t.key)}>
          {t.label}
        </button>
      ))}
    </div>
  );
}

// Normaliza el detalle de error del backend a un string legible.
// FastAPI/Pydantic devuelven 'detail' como string (reglas de negocio) o como
// lista de objetos (errores de validacion 422). Aqui lo aplanamos siempre a texto.
export function mensajeError(e) {
  const d = e?.response?.data?.detail;
  if (!d) return e?.message || "Ocurrio un error";
  if (typeof d === "string") return d;
  if (Array.isArray(d)) return d.map((x) => x?.msg || JSON.stringify(x)).join("; ");
  if (typeof d === "object") return d.msg || JSON.stringify(d);
  return String(d);
}

// Hook simple para mensajes de ok/error.
export function useMsg() {
  const [ok, setOk] = useState("");
  const [err, setErr] = useState("");
  const clear = () => { setOk(""); setErr(""); };
  const showOk = (m) => { setErr(""); setOk(m); };
  const showErr = (e) => { setOk(""); setErr(mensajeError(e)); };
  return { ok, err, clear, showOk, showErr };
}
