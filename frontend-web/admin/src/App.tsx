import { useState } from "react";
import AdminSidebar from "./components/AdminSidebar";
import Restaurants from "./pages/Restaurants";
import Clients from "./pages/Clients";
import Deliverers from "./pages/Deliverers";

export default function App() {
  const [page, setPage] = useState("restaurants");
  return (
    <div className="flex">
      <AdminSidebar current={page} onNavigate={setPage} />
      <div className="flex-1">
        {page === "restaurants" && <Restaurants />}
        {page === "clients" && <Clients />}
        {page === "deliverers" && <Deliverers />}
        {/* add: clients/deliverers/etc */}
      </div>
    </div>
  );
}