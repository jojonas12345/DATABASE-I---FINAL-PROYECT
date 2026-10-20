import api from "./client";

export const getFacturas    = () => api.get("/facturas").then((r) => r.data);
export const getFactura     = (id) => api.get(`/facturas/${id}`).then((r) => r.data);
export const generarFactura = (data) => api.post("/facturas", data).then((r) => r.data);
export const registrarPago  = (data) => api.post("/facturas/pagos", data).then((r) => r.data);
