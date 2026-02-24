import { useEffect, useState } from "react";
import { StatusBadge } from "../components/StatusBadge";

type Deliverer = {
  id: string;
  email: string;
  livreurProfile: {
    fullName: string;
    vehicleType: string | null;
    zone: string | null;
    deliveriesCount?: number;
    rating?: number | null;
  };
  status: string;
};

export default function Deliverers() {
  const [deliverers, setDeliverers] = useState<Deliverer[]>([]);

  useEffect(() => {
    fetch("/admin/deliverers", {
      headers: { Authorization: "Bearer " + localStorage.getItem("access_token") }
    })
      .then(res => res.json()).then(setDeliverers);
  }, []);

  return (
    <div className="p-8">
      <h2 className="text-2xl font-bold mb-6">Delivery Partners Management</h2>
      <table className="w-full">
        <thead>
          <tr>
            <th>Name</th><th>Email</th><th>Vehicle/Zone</th><th>Deliveries</th>
            <th>Rating</th><th>Status</th>
          </tr>
        </thead>
        <tbody>
          {deliverers.map(d =>
            <tr key={d.id}>
              <td>{d.livreurProfile?.fullName ?? "—"}</td>
              <td>{d.email}</td>
              <td>
                {d.livreurProfile?.vehicleType ?? "—"} / {d.livreurProfile?.zone ?? "—"}
              </td>
              <td>{d.livreurProfile?.deliveriesCount ?? "N/A"}</td>
              <td>{d.livreurProfile?.rating ?? "N/A"}</td>
              <td><StatusBadge status={d.status as "pending" | "approved" | "suspended" | "active"} /></td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
}