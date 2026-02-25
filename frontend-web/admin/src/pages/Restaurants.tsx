import { useState } from "react";
import { FaSearch, FaCheck, FaTimes, FaEye, FaFileAlt, FaPause, FaPlay } from "react-icons/fa";
import { StatusBadge } from "../components/StatusBadge";

const restaurants = [
  { id: "1", name: "Bistro du Coin", email: "contact@bistroducoin.fr", submittedAt: "2024-01-15", documents: ["registration", "hygiene", "ownership"], trustScore: 85, status: "pending" },
  { id: "2", name: "Pizza Palace", email: "info@pizzapalace.fr", submittedAt: "2024-01-14", documents: ["registration", "hygiene"], trustScore: 72, status: "pending" },
  { id: "3", name: "Le Petit Café", email: "hello@lepetitcafe.fr", submittedAt: "2024-01-10", documents: ["registration", "hygiene", "ownership"], trustScore: 92, status: "approved" },
  { id: "4", name: "Sushi Express", email: "contact@sushiexpress.fr", submittedAt: "2024-01-05", documents: ["registration", "hygiene", "ownership"], trustScore: 45, status: "suspended" },
];

export default function Restaurants() {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");
  const filtered = restaurants.filter(r =>
    (status === "all" || r.status === status) &&
    (search === "" || r.name.toLowerCase().includes(search.toLowerCase()) || r.email.toLowerCase().includes(search.toLowerCase()))
  );

  return (
    <div className="p-12 bg-[#f8f8f6] min-h-screen">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Admin Dashboard</h1>
        <p className="text-lg text-gray-400">Platform governance and supervision</p>
      </div>
         <div className="flex items-center justify-between mb-4">
        {/* Section title left */}
        <h2 className="text-xl font-semibold">Restaurant Management</h2>
        
        {/* Controls right */}
        <div className="flex items-center gap-4">
          <div className="relative">
            <input
              value={search}
              onChange={e => setSearch(e.target.value)}
              placeholder="Search..."
              className="w-[210px] pl-10 pr-4 py-2 rounded-md border border-gray-200 bg-gray-50 text-sm focus:ring-1 focus:ring-green-400"
            />
            <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400">
              <FaSearch />
            </span>
          </div>
          <select
            value={status}
            onChange={e => setStatus(e.target.value)}
            className="w-[140px] px-4 py-2 rounded-md border border-gray-200 bg-gray-50 text-sm"
          >
            <option value="all">All Status</option>
            <option value="pending">Pending</option>
            <option value="approved">Approved</option>
            <option value="suspended">Suspended</option>
          </select>
        </div>
      </div>

      {/* Card containing table */}
      <div className="bg-white rounded-2xl border shadow p-6">
        <table className="w-full text-gray-800">
          <thead>
            <tr>
              <th className="py-3 text-left text-green-900 font-semibold">Restaurant</th>
              <th className="py-3 text-left text-green-900 font-semibold">Submitted</th>
              <th className="py-3 text-left text-green-900 font-semibold">Documents</th>
              <th className="py-3 text-left text-green-900 font-semibold">Trust Score</th>
              <th className="py-3 text-left text-green-900 font-semibold">Status</th>
              <th className="py-3 text-left text-green-900 font-semibold">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map(r => (
              <tr key={r.id} className="border-b last:border-b-0 hover:bg-gray-50">
                <td className="py-3">
                  <div className="font-semibold">{r.name}</div>
                  <div className="text-xs text-gray-400">{r.email}</div>
                </td>
                <td className="py-3">{r.submittedAt}</td>
                <td className="py-3">
                  {r.documents.map(d => (
                    <span key={d} className="bg-gray-100 rounded px-2 py-1 mr-1 text-xs font-semibold text-gray-500">{d}</span>
                  ))}
                </td>
                <td className="py-3">
                  <span className={
                    `px-3 py-1 text-sm font-bold rounded-full ${r.trustScore >= 80
                      ? "bg-green-100 text-green-700"
                      : r.trustScore >= 60
                        ? "bg-yellow-100 text-yellow-700"
                        : "bg-red-100 text-red-700"
                    }`
                  }>{r.trustScore}</span>
                </td>
                <td className="py-3"><StatusBadge status={r.status as "pending" | "approved" | "suspended" | "active"} /></td>
                <td className="py-3">
                   <div className="flex items-center gap-4 text-xl">
    <button title="View"><FaEye className="text-gray-700" /></button>
                  <button title="Docs"><FaFileAlt className="text-gray-700" /></button>
                  {r.status === "pending" && (
                    <>
                      <button title="Approve"><FaCheck className="text-green-600" /></button>
                      <button title="Reject"><FaTimes className="text-red-600" /></button>
                    </>
                  )}
                  {r.status === "approved" && (
                    <button title="Suspend"><FaPause className="text-yellow-600" /></button>
                  )}
                  {r.status === "suspended" && (
                    <button title="Reactivate"><FaPlay className="text-green-600" /></button>
                  )}
  </div>
                  
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}