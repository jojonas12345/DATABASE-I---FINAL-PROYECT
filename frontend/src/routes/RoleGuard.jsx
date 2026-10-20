// Guarda por rol a nivel de pagina: si el rol no esta permitido,
// muestra un aviso en lugar del contenido.
import { useAuth } from "../context/AuthContext";

export default function RoleGuard({ roles, children }) {
  const { user } = useAuth();
  if (roles && user && !roles.includes(user.rol)) {
    return (
      <div className="card">
        <h3 className="page-title">Sin permiso</h3>
        <p className="muted">Tu rol ({user.rol}) no tiene acceso a esta seccion.</p>
      </div>
    );
  }
  return children;
}
