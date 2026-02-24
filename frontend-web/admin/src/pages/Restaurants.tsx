import { useEffect, useState } from "react";
import { StatusBadge } from "../components/StatusBadge";
import { FaCheck, FaTimes, FaEye, FaExclamation } from "react-icons/fa";
import { fetchPendingRestaurants, approveRestaurant, rejectRestaurant, requireChangesRestaurant } from "../api/admin";

interface Restaurant {
  id: string;
  restaurantName: string;
  email: string;
  submittedAt: string;
  documents: string[];
  trustScore: number;
  status: "pending" | "approved" | "suspended";
}
export default function Restaurants() {
  const [restaurants, setRestaurants] = useState<Restaurant[]>([]);
  useEffect(() => {
    fetchPendingRestaurants().then(setRestaurants);
  }, []);

  return (
    <div className="p-10 flex-1">
      <h2 className="text-2xl mb-6 font-bold">Restaurant Applications</h2>
      <table className="w-full bg-white shadow rounded-lg">
        <thead>
          <tr className="border-b">
            <th className="p-3 text-left">Restaurant</th>
            <th className="p-3 text-left">Submitted</th>
            <th className="p-3 text-left">Documents</th>
            <th className="p-3 text-left">Trust Score</th>
            <th className="p-3 text-left">Status</th>
            <th className="p-3 text-left">Actions</th>
          </tr>
        </thead>
        <tbody>
          {restaurants.map(r => (
            <tr key={r.id} className="border-b hover:bg-gray-50">
              <td className="p-3">
                <div className="font-semibold">{r.restaurantName}</div>
                <div className="text-xs text-gray-400">{r.email}</div>
              </td>
              <td className="p-3">{r.submittedAt}</td>
              <td className="p-3">{r.documents.map(d => <span key={d} className="bg-gray-100 rounded px-2 py-1 mr-1 text-xs">{d}</span>)}</td>
              <td className="p-3">
                <span className={`px-2 py-1 text-sm font-bold rounded ${r.trustScore >= 80 ? "bg-green-100 text-green-700" : r.trustScore >= 60 ? "bg-yellow-100 text-yellow-700" : "bg-red-100 text-red-700"}`}>{r.trustScore}</span>
              </td>
              <td className="p-3"><StatusBadge status={r.status} /></td>
              <td className="p-3 flex gap-2">
                <button title="Approve" onClick={() => approveRestaurant(r.id)}><FaCheck className="text-green-600" /></button>
                <button title="Reject" onClick={() => rejectRestaurant(r.id)}><FaTimes className="text-red-600" /></button>
                <button title="Require changes" onClick={() => requireChangesRestaurant(r.id)}><FaExclamation className="text-yellow-600" /></button>
                <button title="View"><FaEye /></button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}