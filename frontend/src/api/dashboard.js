import api from "./client";

// Indicadores calculados en la base + actividad reciente
export const getDashboard = () => api.get("/dashboard").then((r) => r.data);
