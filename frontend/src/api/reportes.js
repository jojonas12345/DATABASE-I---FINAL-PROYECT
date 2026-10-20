import api from "./client";

// Catalogo de los 12 reportes y ejecucion con filtros (query params)
export const getReportes = () => api.get("/reportes").then((r) => r.data);
export const ejecutarReporte = (numero, filtros) => {
  const params = Object.fromEntries(
    Object.entries(filtros || {}).filter(([, v]) => v !== "" && v !== null && v !== undefined)
  );
  return api.get(`/reportes/${numero}`, { params }).then((r) => r.data);
};
