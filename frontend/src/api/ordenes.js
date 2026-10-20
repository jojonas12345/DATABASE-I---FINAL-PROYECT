import api from "./client";

export const getOrdenes = (estado) =>
  api.get("/ordenes", { params: estado ? { estado } : {} }).then((r) => r.data);
export const getOrdenDetalle = (id) => api.get(`/ordenes/${id}`).then((r) => r.data);
export const crearOrden = (data) => api.post("/ordenes", data).then((r) => r.data);
export const cambiarEstado = (id, data) => api.put(`/ordenes/${id}/estado`, data).then((r) => r.data);

export const crearDiagnostico = (idOrden, data) =>
  api.post(`/ordenes/${idOrden}/diagnostico`, data).then((r) => r.data);
export const crearReparacion = (idOrden, data) =>
  api.post(`/ordenes/${idOrden}/reparacion`, data).then((r) => r.data);
export const finalizarReparacion = (idRep) =>
  api.put(`/reparaciones/${idRep}/finalizar`).then((r) => r.data);
export const consumirRepuesto = (idRep, data) =>
  api.post(`/reparaciones/${idRep}/repuestos`, data).then((r) => r.data);
export const getRepuestosReparacion = (idRep) =>
  api.get(`/reparaciones/${idRep}/repuestos`).then((r) => r.data);
export const crearEntrega = (idOrden, data) =>
  api.post(`/ordenes/${idOrden}/entrega`, data).then((r) => r.data);
