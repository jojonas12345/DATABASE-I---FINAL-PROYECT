// Shell de la app: barra lateral con menu filtrado por rol + barra superior
// con el usuario y su rol, y el area de contenido (Outlet).
import { NavLink, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { menuParaRol, MENU } from "../config/menu";
import ErrorBoundary from "./ErrorBoundary";

export default function Layout() {
  const { user, logout } = useAuth();
  const location = useLocation();
  const items = menuParaRol(user?.rol || "");

  const actual = MENU.find((m) => m.path === location.pathname);
  const titulo = actual ? actual.label : "TechCare";
  const iniciales = (user?.nombre || "?")
    .split(" ")
    .map((p) => p[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">
          <span className="dot" />
          <div>
            <b>TechCare</b>
            <small>Servicio tecnico</small>
          </div>
        </div>

        <nav className="nav">
          {items.map((m) => (
            <NavLink key={m.path} to={m.path} end={m.path === "/"}>
              {m.label}
            </NavLink>
          ))}
        </nav>

        <div className="sidebar-foot">v1.0 - TechCare Solutions</div>
      </aside>

      <div className="main">
        <header className="topbar">
          <div className="title">{titulo}</div>
          <div className="userbox">
            <span className="badge">{user?.rol}</span>
            <div className="avatar">{iniciales}</div>
            <span className="muted" style={{ fontSize: 13 }}>{user?.nombre}</span>
            <button className="btn btn-ghost" onClick={logout}>Salir</button>
          </div>
        </header>

        <main className="content">
          <ErrorBoundary key={location.pathname}>
            <Outlet />
          </ErrorBoundary>
        </main>
      </div>
    </div>
  );
}
