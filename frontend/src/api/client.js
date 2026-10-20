// Cliente HTTP central. TODO el frontend habla con el backend a traves de aqui.
// Un interceptor adjunta el token JWT automaticamente en cada peticion.
import axios from "axios";

// La URL base del backend. En desarrollo apunta al puerto 8000.
// Se lee de una variable de entorno de Vite (VITE_API_URL) con un valor por defecto.
const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || "http://localhost:8000",
});

// Antes de cada peticion: si hay token guardado, lo manda en el header.
api.interceptors.request.use((config) => {
  const token = localStorage.getItem("token");
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Si el backend responde 401 (sesion expirada), limpia y manda a login.
api.interceptors.response.use(
  (res) => res,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem("token");
      window.location.href = "/login";
    }
    return Promise.reject(error);
  }
);

export default api;
