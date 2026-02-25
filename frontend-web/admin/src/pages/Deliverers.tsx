import { useState } from "react";
import { FaEye, FaSearch, FaCheck, FaTimes, FaPause } from "react-icons/fa";
import { StatusBadge } from "../components/StatusBadge";

const deliverers = [
  { id: "1", name: "Thomas Renard", email: "thomas.r@email.com", vehicleType: "Electric Bike", zone: "Paris Center", deliveries: 124, rating: 4.8, status: "active" },
  { id: "2", name: "Lucas Bernard", email: "lucas.b@email.com", vehicleType: "Scooter", zone: "Paris East", deliveries: 87, rating: 4.6, status: "active" },
  { id: "3", name: "Emma Petit", email: "emma.p@email.com", vehicleType: "Bicycle", zone: "Paris South", deliveries: 0, rating: null, status: "pending" },
];

export default function Deliverers() {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");
  const filtered = deliverers.filter(d =>
    (status === "all" || d.status === status) &&
    (search === "" || d.name.toLowerCase().includes(search.toLowerCase()) || d.email.toLowerCase().includes(search.toLowerCase()))
  );

  return (
    <div className="p-12 bg-[#f8f8f6] min-h-screen">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Admin Dashboard</h1>
        <p className="text-lg text-gray-400">Platform governance and supervision</p>
      </div>
        <div className="flex items-center justify-between mb-4">
    <h2 className="text-xl font-semibold">Delivery Partners Management</h2>
    <div className="flex items-center gap-4">
      <div className="relative">
        <input
          value={search}
          onChange={e => setSearch(e.target.value)}
          placeholder="Search deliverers..."
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
        <option value="active">Active</option>
        <option value="pending">Pending</option>
      </select>
    </div>
  </div>
      {/* Card containing table */}
      <div className="bg-white rounded-2xl border shadow p-6">
        <table className="w-full text-gray-800">
          <thead>
            <tr>
              <th className="py-3 text-left text-green-900 font-semibold">Deliverer</th>
              <th className="py-3 text-left text-green-900 font-semibold">Vehicle / Zone</th>
              <th className="py-3 text-left text-green-900 font-semibold">Deliveries</th>
              <th className="py-3 text-left text-green-900 font-semibold">Rating</th>
              <th className="py-3 text-left text-green-900 font-semibold">Status</th>
              <th className="py-3 text-left text-green-900 font-semibold">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map(d => (
              <tr key={d.id} className="border-b last:border-b-0 hover:bg-gray-50">
                <td className="py-3">
                  <div className="font-semibold">{d.name}</div>
                  <div className="text-xs text-gray-400">{d.email}</div>
                </td>
                <td className="py-3">
                  <div>{d.vehicleType}</div>
                  <div className="text-xs text-gray-400">{d.zone}</div>
                </td>
                <td className="py-3">{d.deliveries}</td>
                <td className="py-3">
                  {d.rating != null ? (
                    <span className="font-bold text-yellow-600">{d.rating} ★</span>
                  ) : (
                    <span className="text-gray-400">N/A</span>
                  )}
                </td>
                <td className="py-3"><StatusBadge status={d.status as "active" | "pending"} /></td>
               <td className="py-3">
  <div className="flex items-center gap-4 text-xl">
    <button title="View"><FaEye className="text-gray-700" /></button>
    {d.status === "pending" && (
      <>
        <button title="Approve"><FaCheck className="text-green-600" /></button>
        <button title="Reject"><FaTimes className="text-red-600" /></button>
      </>
    )}
    {d.status === "active" && (
      <button title="Suspend"><FaPause className="text-yellow-600" /></button>
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