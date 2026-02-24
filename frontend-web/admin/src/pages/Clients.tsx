import { useEffect, useState } from "react";
import { StatusBadge } from "../components/StatusBadge";

type Client = {
  id: string;
  email: string;
  clientProfile: { fullName: string; phone: string | null };
  createdAt: string;
  status: string;
  ordersCount?: number; // Optional (if you add this feature in backend)
};

export default function Clients() {
  const [clients, setClients] = useState<Client[]>([]);

  useEffect(() => {
    fetch("/admin/clients", {
      headers: { Authorization: "Bearer " + localStorage.getItem("access_token") }
    })
      .then(res => res.json()).then(setClients);
  }, []);

  return (
    <div className="p-8">
      <h2 className="text-2xl font-bold mb-6">User Management</h2>
      <table className="w-full">
        <thead>
          <tr>
            <th>Name</th><th>Email</th><th>Contact</th>
            <th>Joined</th><th>Status</th>
            {/* <th>Orders</th> add if you want */}
          </tr>
        </thead>
        <tbody>
          {clients.map(c =>
            <tr key={c.id}>
              <td>{c.clientProfile?.fullName ?? "—"}</td>
              <td>{c.email}</td>
              <td>{c.clientProfile?.phone ?? "—"}</td>
              <td>{c.createdAt?.slice(0, 10)}</td>
              <td><StatusBadge status={c.status as "pending" | "approved" | "suspended" | "active"} /></td>
              {/* <td>{c.ordersCount ?? "-"}</td> */}
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
}