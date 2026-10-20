// Modulo Clientes y Equipos (mantenimiento): listar, crear, editar y
// activar/desactivar clientes; ver, agregar y editar sus equipos.
// (Roles: Administrador, Recepcion)
import { useEffect, useState } from "react";
import { getClientes, crearCliente, actualizarCliente, estadoCliente,
         crearEquipo, actualizarEquipo, estadoEquipo } from "../api/clientes";
import { getEquiposDeCliente, getMarcas, getTipos } from "../api/catalogos";
import { Card, Field, Input, Select, Msg, DataTable, useMsg } from "../components/ui";

const ESTADOS_EQUIPO = ["OPERATIVO", "DANADO", "EN_REPARACION", "DESCONTINUADO"];
const nombreCliente = (c) => (c.tipo === "INDIVIDUAL" ? `${c.nombres} ${c.apellidos}` : c.razon_social);

export default function ClientesEquipos() {
  const [clientes, setClientes] = useState(null);
  const [inactivos, setInactivos] = useState(false);
  const [sel, setSel] = useState(null);
  const [equipos, setEquipos] = useState(null);
  const [marcas, setMarcas] = useState([]);
  const [tipos, setTipos] = useState([]);
  const [formC, setFormC] = useState(null);   // {modo:'nuevo'|'editar', ...datos}
  const [formE, setFormE] = useState(null);
  const msg = useMsg();

  const cargar = () => getClientes(inactivos).then(setClientes).catch(msg.showErr);
  useEffect(() => { cargar(); }, [inactivos]);
  useEffect(() => { getMarcas().then(setMarcas); getTipos().then(setTipos); }, []);

  const cargarEquipos = (c) => getEquiposDeCliente(c.id_cliente).then(setEquipos).catch(msg.showErr);
  const elegir = (c) => { setSel(c); setFormE(null); setEquipos(null); cargarEquipos(c); };

  const guardarCliente = async () => {
    const { modo, id_cliente, activo, ...datos } = formC;
    // Un cliente individual no lleva razon social y uno empresarial no lleva nombres (CK_Cliente_identidad)
    if (datos.tipo === "INDIVIDUAL") datos.razon_social = null;
    else { datos.nombres = null; datos.apellidos = null; }
    try {
      if (modo === "editar") {
        const act = await actualizarCliente(id_cliente, datos);
        msg.showOk("Cliente actualizado"); setSel(act);
      } else {
        await crearCliente(datos); msg.showOk("Cliente creado");
      }
      setFormC(null); cargar();
    } catch (e) { msg.showErr(e); }
  };

  const toggleCliente = async (c) => {
    try { await estadoCliente(c.id_cliente, !c.activo); msg.showOk(c.activo ? "Cliente desactivado" : "Cliente activado"); cargar(); }
    catch (e) { msg.showErr(e); }
  };

  const guardarEquipo = async () => {
    const { modo, id_equipo, ...datos } = formE;
    try {
      if (modo === "editar") { await actualizarEquipo(id_equipo, datos); msg.showOk("Equipo actualizado"); }
      else { await crearEquipo({ ...datos, id_cliente: sel.id_cliente }); msg.showOk("Equipo agregado"); }
      setFormE(null); cargarEquipos(sel);
    } catch (e) { msg.showErr(e); }
  };

  const quitarEquipo = async (eq) => {
    try { await estadoEquipo(eq.id_equipo, false); msg.showOk("Equipo desactivado"); cargarEquipos(sel); }
    catch (e) { msg.showErr(e); }
  };

  const set = (setter, obj) => (campo) => (e) => setter({ ...obj, [campo]: e.target.value });
  const fc = formC ? set(setFormC, formC) : null;
  const fe = formE ? set(setFormE, formE) : null;

  return (
    <div>
      <h2 className="page-title">Clientes y Equipos</h2>
      <Msg ok={msg.ok} err={msg.err} />

      <div className="two-col">
        {/* ---- Clientes ---- */}
        <Card>
          <div className="toolbar">
            <b>Clientes</b>
            <label className="check">
              <input type="checkbox" checked={inactivos} onChange={(e) => setInactivos(e.target.checked)} /> Mostrar inactivos
            </label>
            <div className="spacer" />
            <button className="btn btn-primary btn-sm"
                    onClick={() => setFormC(formC ? null : { modo: "nuevo", tipo: "INDIVIDUAL" })}>
              {formC ? "Cancelar" : "Nuevo cliente"}
            </button>
          </div>

          {formC && (
            <div className="form-grid" style={{ marginBottom: 14 }}>
              <Field label="Tipo">
                <Select value={formC.tipo} onChange={fc("tipo")}
                        options={[{ value: "INDIVIDUAL", label: "Individual" }, { value: "EMPRESARIAL", label: "Empresarial" }]} />
              </Field>
              {formC.tipo === "INDIVIDUAL" ? (
                <>
                  <Field label="Nombres"><Input value={formC.nombres || ""} onChange={fc("nombres")} /></Field>
                  <Field label="Apellidos"><Input value={formC.apellidos || ""} onChange={fc("apellidos")} /></Field>
                </>
              ) : (
                <Field label="Razon social"><Input value={formC.razon_social || ""} onChange={fc("razon_social")} /></Field>
              )}
              <Field label="NIT"><Input value={formC.nit || ""} onChange={fc("nit")} /></Field>
              <Field label="Telefono"><Input value={formC.telefono || ""} onChange={fc("telefono")} /></Field>
              <Field label="Email"><Input value={formC.email || ""} onChange={fc("email")} /></Field>
              <Field label="Direccion"><Input value={formC.direccion || ""} onChange={fc("direccion")} /></Field>
              <div style={{ alignSelf: "end" }}>
                <button className="btn btn-primary" onClick={guardarCliente}>
                  {formC.modo === "editar" ? "Guardar cambios" : "Guardar"}
                </button>
              </div>
            </div>
          )}

          <DataTable rows={clientes} idKey="id_cliente" selectedId={sel?.id_cliente} onRowClick={elegir}
            columns={[
              { key: "cliente", label: "Cliente", render: nombreCliente },
              { key: "tipo", label: "Tipo" },
              { key: "nit", label: "NIT" },
              { key: "telefono", label: "Telefono", render: (r) => r.telefono || "-" },
              { key: "activo", label: "Estado", render: (r) =>
                  <span className={"pill " + (r.activo ? "ok" : "rojo")}>{r.activo ? "Activo" : "Inactivo"}</span> },
              { key: "acc", label: "", render: (r) => (
                  <span className="acciones" onClick={(e) => e.stopPropagation()}>
                    <button className="btn btn-ghost btn-sm" onClick={() => setFormC({ modo: "editar", ...r })}>Editar</button>
                    <button className="btn btn-ghost btn-sm" onClick={() => toggleCliente(r)}>{r.activo ? "Desactivar" : "Activar"}</button>
                  </span>) },
            ]} />
        </Card>

        {/* ---- Equipos del cliente ---- */}
        <Card>
          <div className="toolbar">
            <b>Equipos {sel ? `de ${nombreCliente(sel)}` : ""}</b>
            <div className="spacer" />
            {sel && (
              <button className="btn btn-primary btn-sm" onClick={() => setFormE(formE ? null : { modo: "nuevo", estado: "OPERATIVO" })}>
                {formE ? "Cancelar" : "Nuevo equipo"}
              </button>
            )}
          </div>

          {!sel && <p className="muted">Selecciona un cliente para ver sus equipos.</p>}

          {sel && formE && (
            <div className="form-grid" style={{ marginBottom: 14 }}>
              <Field label="Tipo de equipo">
                <Select value={formE.id_tipo_equipo || ""} onChange={(e) => setFormE({ ...formE, id_tipo_equipo: Number(e.target.value) })}
                        placeholder="Selecciona" options={tipos.map((t) => ({ value: t.id_tipo_equipo, label: t.nombre }))} />
              </Field>
              <Field label="Marca">
                <Select value={formE.id_marca || ""} onChange={(e) => setFormE({ ...formE, id_marca: Number(e.target.value) })}
                        placeholder="Selecciona" options={marcas.map((m) => ({ value: m.id_marca, label: m.nombre }))} />
              </Field>
              <Field label="Numero de serie"><Input value={formE.serie || ""} onChange={fe("serie")} /></Field>
              <Field label="Modelo"><Input value={formE.modelo || ""} onChange={fe("modelo")} /></Field>
              <Field label="Descripcion"><Input value={formE.descripcion || ""} onChange={fe("descripcion")} /></Field>
              {formE.modo === "editar" && (
                <Field label="Estado del equipo">
                  <Select value={formE.estado} onChange={fe("estado")} options={ESTADOS_EQUIPO.map((s) => ({ value: s, label: s }))} />
                </Field>
              )}
              <div style={{ alignSelf: "end" }}>
                <button className="btn btn-primary" onClick={guardarEquipo}>
                  {formE.modo === "editar" ? "Guardar cambios" : "Guardar"}
                </button>
              </div>
            </div>
          )}

          {sel && (
            <DataTable rows={equipos} columns={[
              { key: "serie", label: "Serie" },
              { key: "equipo", label: "Equipo", render: (r) => `${r.tipo} ${r.marca}${r.modelo ? " " + r.modelo : ""}` },
              { key: "estado", label: "Estado" },
              { key: "ordenes", label: "Ordenes" },
              { key: "acc", label: "", render: (r) => (
                  <span className="acciones">
                    <button className="btn btn-ghost btn-sm" onClick={() => setFormE({
                      modo: "editar", id_equipo: r.id_equipo, id_tipo_equipo: r.id_tipo_equipo, id_marca: r.id_marca,
                      serie: r.serie, modelo: r.modelo || "", descripcion: r.descripcion || "", estado: r.estado })}>Editar</button>
                    <button className="btn btn-ghost btn-sm" onClick={() => quitarEquipo(r)}>Desactivar</button>
                  </span>) },
            ]} />
          )}
        </Card>
      </div>
    </div>
  );
}
