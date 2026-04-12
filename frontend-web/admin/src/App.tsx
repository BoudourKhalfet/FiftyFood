import { useState, type ReactNode } from "react";
import { Routes, Route, Navigate } from "react-router-dom";

import AdminSidebar from "./components/AdminSidebar";
import Restaurants from "./pages/Restaurants";
import Clients from "./pages/Clients";
import Deliverers from "./pages/Deliverers";
import AdminLogin from "./pages/AdminLogin";
import Orders from "./pages/Orders";
import VerifiedEmail from "./pages/VerifiedEmail";
import Dashboard from "./pages/Dashboard";

// Helper to check if admin is logged in (token exists in localStorage)
function isAdminAuthenticated() {
  return !!localStorage.getItem("access_token");
}

// Props type for RequireAdminAuth
interface RequireAdminAuthProps {
  children: ReactNode;
}

// Component to protect admin pages
function RequireAdminAuth({ children }: RequireAdminAuthProps) {
  return isAdminAuthenticated() ? (
    <>{children}</>
  ) : (
    <Navigate to="/admin/login" />
  );
}

// Admin panel component to avoid code duplication
function AdminPanel({ page, setPage }: { page: string; setPage: (page: string) => void }) {
  return (
    <RequireAdminAuth>
      <div className="flex">
        <AdminSidebar current={page} onNavigate={setPage} />
        <div className="flex-1">
          {page === "dashboard" && <Dashboard />}
          {page === "restaurants" && <Restaurants />}
          {page === "clients" && <Clients />}
          {page === "deliverers" && <Deliverers />}
          {page === "orders" && <Orders />}
        </div>
      </div>
    </RequireAdminAuth>
  );
}

export default function App() {
  const [page, setPage] = useState("dashboard");
  return (
    <Routes>
      <Route path="/verified" element={<VerifiedEmail />} />
      <Route path="/admin/login" element={<AdminLogin />} />
      <Route path="/admin" element={<AdminPanel page={page} setPage={setPage} />} />
      <Route path="/admin/*" element={<AdminPanel page={page} setPage={setPage} />} />
      <Route path="/" element={<Navigate to="/admin" />} />
      <Route path="*" element={<Navigate to="/admin" />} />
    </Routes>
  );
}
