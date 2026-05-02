import { Navigate, Route, Routes } from "react-router-dom";
import Dashboard from "./components/Dashboard";
import Login from "./pages/Login";

function RequireAuth({ children }: { children: React.ReactNode }) {
  return localStorage.getItem("access_token") ? <>{children}</> : <Navigate to="/login" replace />;
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/" element={<RequireAuth><Dashboard /></RequireAuth>} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
