import React, { useState, type ReactNode } from "react";
import { Routes, Route, Navigate } from "react-router-dom";

import AdminSidebar from "./components/AdminSidebar";
import Restaurants from "./pages/Restaurants";
import Clients from "./pages/Clients";
import Deliverers from "./pages/Deliverers";
import AdminLogin from "./pages/AdminLogin";

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

export default function App() {
  const [page, setPage] = useState("restaurants");
  return (
    <Routes>
      <Route path="/admin/login" element={<AdminLogin />} />
      <Route
        path="/admin/*"
        element={
          <RequireAdminAuth>
            <div className="flex">
              <AdminSidebar current={page} onNavigate={setPage} />
              <div className="flex-1">
                {page === "restaurants" && <Restaurants />}
                {page === "clients" && <Clients />}
                {page === "deliverers" && <Deliverers />}
              </div>
            </div>
          </RequireAdminAuth>
        }
      />
      <Route path="*" element={<Navigate to="/admin" />} />
    </Routes>
  );
}
