import api from "./client";

// Catalogos activos (para selects y consultas)
export const getRepuestos   = () => api.get("/catalogos/repuestos").then((r) => r.data);
export const getProveedores = () => api.get("/catalogos/proveedores").then((r) => r.data);
export const getBodegas     = () => api.get("/catalogos/bodegas").then((r) => r.data);
export const getMetodosPago = () => api.get("/catalogos/metodos-pago").then((r) => r.data);
export const getMarcas      = () => api.get("/catalogos/marcas").then((r) => r.data);
export const getTipos       = () => api.get("/catalogos/tipos-equipo").then((r) => r.data);
export const getCategorias  = () => api.get("/catalogos/categorias").then((r) => r.data);
export const getTecnicos    = () => api.get("/catalogos/tecnicos").then((r) => r.data);
export const getEquiposDeCliente = (id) =>
  api.get(`/catalogos/clientes/${id}/equipos`).then((r) => r.data);
