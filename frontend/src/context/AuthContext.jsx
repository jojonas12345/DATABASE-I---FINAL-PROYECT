// Estado global de sesion: guarda id_usuario, rol y nombre.
// Ajustado al contrato real del backend: /auth/login devuelve
// { access_token, token_type, rol, id_usuario, nombre }.
import { createContext, useContext, useState } from "react";
import { login as apiLogin } from "../api/auth";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    try {
      const raw = localStorage.getItem("user");
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  });

  const login = async (nombreUsuario, password) => {
    const data = await apiLogin(nombreUsuario, password);
    const u = {
      id_usuario: data.id_usuario,
      rol: data.rol,
      nombre: data.nombre,
    };
    try {
      localStorage.setItem("token", data.access_token);
      localStorage.setItem("user", JSON.stringify(u));
    } catch {}
    setUser(u);
    return u;
  };

  const logout = () => {
    try {
      localStorage.removeItem("token");
      localStorage.removeItem("user");
    } catch {}
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
