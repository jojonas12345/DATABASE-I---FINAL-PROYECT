import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

export default function Login() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [usuario, setUsuario] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [cargando, setCargando] = useState(false);

  const onSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setCargando(true);
    try {
      await login(usuario, password);
      navigate("/");
    } catch (err) {
      setError(err.response?.data?.detail || "No se pudo iniciar sesion");
    } finally {
      setCargando(false);
    }
  };

  return (
    <div className="login-wrap">
      <form className="login-card" onSubmit={onSubmit}>
        <div className="login-logo">
          <span className="dot" />
          <div>
            <h1>TechCare</h1>
            <span>Sistema de servicio tecnico</span>
          </div>
        </div>

        <label className="field" htmlFor="u">Usuario</label>
        <input id="u" className="input" value={usuario}
               onChange={(e) => setUsuario(e.target.value)} autoFocus />

        <label className="field" htmlFor="p">Contrasena</label>
        <input id="p" type="password" className="input" value={password}
               onChange={(e) => setPassword(e.target.value)} />

        {error && <div className="error">{error}</div>}

        <button className="btn btn-primary btn-block" style={{ marginTop: 18 }} disabled={cargando}>
          {cargando ? "Ingresando..." : "Entrar"}
        </button>
      </form>
    </div>
  );
}
