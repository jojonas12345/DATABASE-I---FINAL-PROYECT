// Guarda de sesion: si no hay usuario, redirige a /login.
// Renderiza children (el Layout) cuando hay sesion.
import { Navigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

export default function ProtectedRoute({ children }) {
  const { user } = useAuth();
  if (!user) return <Navigate to="/login" replace />;
  return children;
}
