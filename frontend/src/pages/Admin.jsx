// Modulo Administracion (solo Administrador): selector de "que gestionar" y,
// para cada entidad, mantenimiento completo: tabla + crear + editar + activar/desactivar.
// "Eliminar" es desactivar: no se borra informacion (R14).
import { useEffect, useState } from "react";
import * as A from "../api/admin";
import { getCategorias } from "../api/catalogos";
import { useAuth } from "../context/AuthContext";
import { Card, Field, Input, Select, Msg, DataTable, useMsg, money } from "../components/ui";

// Configuracion de cada catalogo: campos del formulario y como mostrarlos
const CATALOGOS = {
  proveedores: { titulo: "Proveedores", campos: [
    { n: "nombre", l: "Nombre", req: true }, { n: "nit", l: "NIT", req: true },
    { n: "telefono", l: "Telefono" }, { n: "email", l: "Email" }, { n: "direccion", l: "Direccion" }] },
  repuestos: { titulo: "Repuestos", campos: [
    { n: "codigo", l: "Codigo (unico)", req: true }, { n: "nombre", l: "Nombre", req: true },
    { n: "id_categoria", l: "Categoria", t: "categoria", req: true }, { n: "descripcion", l: "Descripcion" },
    { n: "precio_compra_ref", l: "Precio compra ref.", t: "number", money: true },
    { n: "precio_venta", l: "Precio venta", t: "number", money: true }] },
  categorias: { titulo: "Categorias de repuesto", campos: [{ n: "nombre", l: "Nombre", req: true }] },
  bodegas: { titulo: "Bodegas", campos: [{ n: "nombre", l: "Nombre", req: true }, { n: "ubicacion", l: "Ubicacion" }] },
  "metodos-pago": { titulo: "Metodos de pago", campos: [{ n: "nombre", l: "Nombre", req: true }] },
  marcas: { titulo: "Marcas de equipo", campos: [{ n: "nombre", l: "Nombre", req: true }] },
  "tipos-equipo": { titulo: "Tipos de equipo", campos: [{ n: "nombre", l: "Nombre", req: true }] },
};

export default function Admin() {
  const [ent, setEnt] = useState("usuarios");
  return (
    <div>
      <h2 className="page-title">Administracion</h2>
      <div className="toolbar">
        <Field label="Gestionar">
          <Select value={ent} onChange={(e) => setEnt(e.target.value)} options={[
            { value: "usuarios", label: "Usuarios / empleados" },
            ...Object.entries(CATALOGOS).map(([k, v]) => ({ value: k, label: v.titulo })),
          ]} />
        </Field>
      </div>
      {ent === "usuarios" ? <Usuarios /> : <Catalogo key={ent} entidad={ent} cfg={CATALOGOS[ent]} />}
    </div>
  );
}

// ---------------- Usuarios ----------------
function Usuarios() {
  const { user } = useAuth();
  const [rows, setRows] = useState(null);
  const [roles, setRoles] = useState([]);
  const [filtroRol, setFiltroRol] = useState("");
  const [f, setF] = useState(null);   // {modo, ...}
  const msg = useMsg();
  const cargar = () => A.getUsuarios().then(setRows).catch(msg.showErr);
  useEffect(() => { cargar(); A.getRoles().then(setRoles); }, []);

  const guardar = async () => {
    try {
      if (f.modo === "editar") {
        await A.actualizarUsuario(f.id_usuario, { id_rol: f.id_rol, nombres: f.nombres, apellidos: f.apellidos,
                                                  password: f.password || null });
        msg.showOk("Usuario actualizado");
      } else {
        await A.crearUsuario({ id_rol: f.id_rol, nombre_usuario: f.nombre_usuario, password: f.password,
                               nombres: f.nombres, apellidos: f.apellidos });
        msg.showOk("Usuario creado (contrasena guardada con hash bcrypt)");
      }
      setF(null); cargar();
    } catch (e) { msg.showErr(e); }
  };
  const toggle = async (u) => {
    try { await A.estadoUsuario(u.id_usuario, !u.activo); cargar(); }
    catch (e) { msg.showErr(e); }
  };
  const set = (k) => (e) => setF({ ...f, [k]: e.target.value });
  const filas = rows ? rows.filter((u) => !filtroRol || String(u.id_rol) === filtroRol) : null;

  return (
    <Card>
      <Msg ok={msg.ok} err={msg.err} />
      <div className="toolbar">
        <b>Usuarios</b>
        <Select value={filtroRol} onChange={(e) => setFiltroRol(e.target.value)} placeholder="Todos los roles"
                options={roles.map((r) => ({ value: String(r.id_rol), label: r.nombre }))} />
        <div className="spacer" />
        <button className="btn btn-primary btn-sm" onClick={() => setF(f ? null : { modo: "nuevo" })}>
          {f ? "Cancelar" : "Nuevo usuario"}
        </button>
      </div>

      {f && (
        <div className="form-grid" style={{ marginBottom: 14 }}>
          <Field label="Rol">
            <Select value={f.id_rol || ""} onChange={(e) => setF({ ...f, id_rol: Number(e.target.value) })}
                    placeholder="Selecciona" options={roles.map((r) => ({ value: r.id_rol, label: r.nombre }))} />
          </Field>
          <Field label="Usuario">
            <Input value={f.nombre_usuario || ""} onChange={set("nombre_usuario")} disabled={f.modo === "editar"} />
          </Field>
          <Field label={f.modo === "editar" ? "Nueva contrasena (opcional)" : "Contrasena"}>
            <Input type="password" value={f.password || ""} onChange={set("password")} />
          </Field>
          <Field label="Nombres"><Input value={f.nombres || ""} onChange={set("nombres")} /></Field>
          <Field label="Apellidos"><Input value={f.apellidos || ""} onChange={set("apellidos")} /></Field>
          <div style={{ alignSelf: "end" }}>
            <button className="btn btn-primary" onClick={guardar}>{f.modo === "editar" ? "Guardar cambios" : "Crear usuario"}</button>
          </div>
        </div>
      )}

      <DataTable rows={filas} columns={[
        { key: "nombre_usuario", label: "Usuario" },
        { key: "nombre", label: "Nombre", render: (r) => `${r.nombres} ${r.apellidos}` },
        { key: "rol", label: "Rol" },
        { key: "activo", label: "Estado", render: (r) =>
            <span className={"pill " + (r.activo ? "ok" : "rojo")}>{r.activo ? "Activo" : "Inactivo"}</span> },
        { key: "acc", label: "", render: (r) => (
            <span className="acciones">
              <button className="btn btn-ghost btn-sm" onClick={() => setF({ modo: "editar", ...r, password: "" })}>Editar</button>
              {r.id_usuario !== user?.id_usuario && (
                <button className="btn btn-ghost btn-sm" onClick={() => toggle(r)}>{r.activo ? "Desactivar" : "Activar"}</button>
              )}
            </span>) },
      ]} />
    </Card>
  );
}

// ---------------- Catalogo generico ----------------
function Catalogo({ entidad, cfg }) {
  const [rows, setRows] = useState(null);
  const [cats, setCats] = useState([]);
  const [f, setF] = useState(null);   // {modo, id?, ...campos}
  const msg = useMsg();
  const usaCategoria = cfg.campos.some((c) => c.t === "categoria");

  const cargar = () => A.listarCatalogo(entidad).then(setRows).catch(msg.showErr);
  useEffect(() => { cargar(); if (usaCategoria) getCategorias().then(setCats); }, [entidad]);

  const nombreCat = (id) => cats.find((c) => c.id_categoria === id)?.nombre || id;

  const guardar = async () => {
    const datos = {};
    cfg.campos.forEach((c) => {
      let v = f[c.n];
      if (c.t === "number" || c.t === "categoria") v = v === "" || v === undefined || v === null ? null : Number(v);
      datos[c.n] = v ?? null;
    });
    try {
      if (f.modo === "editar") { await A.actualizarCatalogo(entidad, f.id, datos); msg.showOk("Registro actualizado"); }
      else { await A.crearEnCatalogo(entidad, datos); msg.showOk("Registro creado"); }
      setF(null); cargar();
    } catch (e) { msg.showErr(e); }
  };
  const toggle = async (r) => {
    try { await A.estadoCatalogo(entidad, r.id, !r.activo); msg.showOk(r.activo ? "Desactivado" : "Activado"); cargar(); }
    catch (e) { msg.showErr(e); }
  };

  const columnas = [
    ...cfg.campos.map((c) => ({
      key: c.n, label: c.l.replace(" (unico)", ""),
      render: c.t === "categoria" ? (r) => nombreCat(r[c.n]) : c.money ? (r) => money(r[c.n]) : undefined,
    })),
    { key: "activo", label: "Estado", render: (r) =>
        <span className={"pill " + (r.activo ? "ok" : "rojo")}>{r.activo ? "Activo" : "Inactivo"}</span> },
    { key: "acc", label: "", render: (r) => (
        <span className="acciones">
          <button className="btn btn-ghost btn-sm" onClick={() => setF({ modo: "editar", ...r })}>Editar</button>
          <button className="btn btn-ghost btn-sm" onClick={() => toggle(r)}>{r.activo ? "Desactivar" : "Activar"}</button>
        </span>) },
  ];

  return (
    <Card>
      <Msg ok={msg.ok} err={msg.err} />
      <div className="toolbar">
        <b>{cfg.titulo}</b>
        <div className="spacer" />
        <button className="btn btn-primary btn-sm" onClick={() => setF(f ? null : { modo: "nuevo" })}>
          {f ? "Cancelar" : "Nuevo registro"}
        </button>
      </div>

      {f && (
        <div className="form-grid" style={{ marginBottom: 14 }}>
          {cfg.campos.map((c) => (
            <Field key={c.n} label={c.l + (c.req ? " *" : "")}>
              {c.t === "categoria" ? (
                <Select value={f[c.n] ?? ""} onChange={(e) => setF({ ...f, [c.n]: e.target.value })}
                        placeholder="Selecciona" options={cats.map((x) => ({ value: x.id_categoria, label: x.nombre }))} />
              ) : (
                <Input type={c.t === "number" ? "number" : "text"} min={c.t === "number" ? "0" : undefined}
                       value={f[c.n] ?? ""} onChange={(e) => setF({ ...f, [c.n]: e.target.value })} />
              )}
            </Field>
          ))}
          <div style={{ alignSelf: "end" }}>
            <button className="btn btn-primary" onClick={guardar}>{f.modo === "editar" ? "Guardar cambios" : "Guardar"}</button>
          </div>
        </div>
      )}

      <DataTable rows={rows} idKey="id" columns={columnas} />
    </Card>
  );
}
