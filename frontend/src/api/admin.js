import api from "./client";

// Usuarios
export const getUsuarios        = () => api.get("/admin/usuarios").then((r) => r.data);
export const crearUsuario       = (data) => api.post("/admin/usuarios", data).then((r) => r.data);
export const actualizarUsuario  = (id, data) => api.put(`/admin/usuarios/${id}`, data).then((r) => r.data);
export const estadoUsuario      = (id, activo) => api.put(`/admin/usuarios/${id}/estado`, { activo }).then((r) => r.data);
export const getRoles           = () => api.get("/admin/roles").then((r) => r.data);

// Mantenimiento generico de catalogos (listar / crear / editar / activar-desactivar)
export const listarCatalogo     = (ent) => api.get(`/admin/catalogos/${ent}`).then((r) => r.data);
export const crearEnCatalogo    = (ent, data) => api.post(`/admin/catalogos/${ent}`, data).then((r) => r.data);
export const actualizarCatalogo = (ent, id, data) => api.put(`/admin/catalogos/${ent}/${id}`, data).then((r) => r.data);
export const estadoCatalogo     = (ent, id, activo) =>
  api.put(`/admin/catalogos/${ent}/${id}/estado`, { activo }).then((r) => r.data);
