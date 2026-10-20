// Pagina de ejemplo: lista clientes consumiendo la API via la capa api/.
import { useEffect, useState } from "react";
import { getClientes } from "../api/clientes";

export default function Clientes() {
  const [clientes, setClientes] = useState([]);
  const [error, setError] = useState("");

  useEffect(() => {
    getClientes()
      .then(setClientes)
      .catch((e) => setError(e.response?.data?.detail || "Error al cargar"));
  }, []);

  return (
    <div style={{ padding: 24, fontFamily: "system-ui" }}>
      <h2>Clientes</h2>
      {error && <p style={{ color: "crimson" }}>{error}</p>}
      <table border="1" cellPadding="6" style={{ borderCollapse: "collapse" }}>
        <thead>
          <tr>
            <th>NIT</th><th>Nombre</th><th>Tipo</th><th>Estado</th>
          </tr>
        </thead>
        <tbody>
          {clientes.map((c) => (
            <tr key={c.id_cliente}>
              <td>{c.nit}</td>
              <td>{c.nombre}</td>
              <td>{c.tipo}</td>
              <td>{c.estado}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
