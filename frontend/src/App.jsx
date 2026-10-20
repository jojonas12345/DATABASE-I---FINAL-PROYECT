// Ruteo principal: /login publico, y el resto dentro del shell protegido.
// Cada modulo se protege por rol con RoleGuard.
import { BrowserRouter, Routes, Route } from "react-router-dom";
import { AuthProvider } from "./context/AuthContext";
import ProtectedRoute from "./routes/ProtectedRoute";
import RoleGuard from "./routes/RoleGuard";
import Layout from "./components/Layout";
import Login from "./pages/Login";
import Dashboard from "./pages/Dashboard";
import Ordenes from "./pages/Ordenes";
import ClientesEquipos from "./pages/ClientesEquipos";
import Inventario from "./pages/Inventario";
import Caja from "./pages/Caja";
import Reportes from "./pages/Reportes";
import Admin from "./pages/Admin";

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />

          <Route
            element={
              <ProtectedRoute>
                <Layout />
              </ProtectedRoute>
            }
          >
            <Route index element={<Dashboard />} />

            <Route path="ordenes" element={
              <RoleGuard roles={["Administrador", "Recepcion", "Tecnico", "Caja"]}>
                <Ordenes />
              </RoleGuard>} />

            <Route path="clientes" element={
              <RoleGuard roles={["Administrador", "Recepcion"]}>
                <ClientesEquipos />
              </RoleGuard>} />

            <Route path="inventario" element={
              <RoleGuard roles={["Administrador", "Bodega"]}>
                <Inventario />
              </RoleGuard>} />

            <Route path="caja" element={
              <RoleGuard roles={["Administrador", "Caja"]}>
                <Caja />
              </RoleGuard>} />

            <Route path="reportes" element={<Reportes />} />

            <Route path="admin" element={
              <RoleGuard roles={["Administrador"]}>
                <Admin />
              </RoleGuard>} />
          </Route>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}
