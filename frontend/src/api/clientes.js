import api from "./client";

export const getClientes = (incluirInactivos = false) =>
  api.get("/clientes", { params: { incluir_inactivos: incluirInactivos } }).then((r) => r.data);
export const getCliente         = (id) => api.get(`/clientes/${id}`).then((r) => r.data);
export const crearCliente       = (data) => api.post("/clientes", data).then((r) => r.data);
export const actualizarCliente  = (id, data) => api.put(`/clientes/${id}`, data).then((r) => r.data);
export const estadoCliente      = (id, activo) => api.put(`/clientes/${id}/estado`, { activo }).then((r) => r.data);

export const crearEquipo        = (data) => api.post("/equipos", data).then((r) => r.data);
export const actualizarEquipo   = (id, data) => api.put(`/equipos/${id}`, data).then((r) => r.data);
export const estadoEquipo       = (id, activo) => api.put(`/equipos/${id}/estado`, { activo }).then((r) => r.data);
