import api from "./client";

export const getExistencias = () => api.get("/inventario").then((r) => r.data);
export const getMovimientos = () => api.get("/inventario/movimientos").then((r) => r.data);
export const getCompras     = () => api.get("/inventario/compras").then((r) => r.data);
export const getCompra      = (id) => api.get(`/inventario/compras/${id}`).then((r) => r.data);

// Compra con encabezado + varios renglones (SP usp_RegistrarCompra)
export const registrarCompra = (data) => api.post("/compras", data).then((r) => r.data);
// Recepcion de una compra pendiente (SP usp_RecibirCompra)
export const recibirCompra   = (id) => api.post(`/compras/${id}/recibir`).then((r) => r.data);
