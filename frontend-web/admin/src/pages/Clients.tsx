import { useState } from "react";
import { FaEye, FaPause, FaPlay, FaSearch } from "react-icons/fa";
import { StatusBadge } from "../components/StatusBadge";

const users = [
  { id: "1", name: "Marie Lambert", email: "marie.l@email.com", phone: "+33 6 12 34 56 78", status: "active", joinedAt: "2024-01-10", ordersCount: 15 },
  { id: "2", name: "Pierre Dupont", email: "pierre.d@email.com", phone: "+33 6 23 45 67 89", status: "active", joinedAt: "2024-01-08", ordersCount: 8 },
  { id: "3", name: "Sophie Martin", email: "sophie.m@email.com", phone: "+33 6 34 56 78 90", status: "suspended", joinedAt: "2023-12-20", ordersCount: 42 },
];

export default function Clients() {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");
  const filtered = users.filter(u =>
    (status === "all" || u.status === status) &&
    (search === "" || u.name.toLowerCase().includes(search.toLowerCase()) || u.email.toLowerCase().includes(search.toLowerCase()))
  );

  return (
    <div className="p-12 bg-[#f8f8f6] min-h-screen">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Admin Dashboard</h1>
        <p className="text-lg text-gray-400">Platform governance and supervision</p>
      </div>

      {/* Controls OUTSIDE card */}
     <div className="flex items-center justify-between mb-4">
    <h2 className="text-xl font-semibold">Clients Management</h2>
    <div className="flex items-center gap-4">
      <div className="relative">
        <input
          value={search}
          onChange={e => setSearch(e.target.value)}
          placeholder="Search users..."
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
        <option value="suspended">Suspended</option>
      </select>
    </div>
  </div>

      {/* Card containing table */}
      <div className="bg-white rounded-2xl border shadow p-6">
        <table className="w-full text-gray-800">
          <thead>
            <tr>
              <th className="py-3 text-left text-green-900 font-semibold">User</th>
              <th className="py-3 text-left text-green-900 font-semibold">Contact</th>
              <th className="py-3 text-left text-green-900 font-semibold">Joined</th>
              <th className="py-3 text-left text-green-900 font-semibold">Orders</th>
              <th className="py-3 text-left text-green-900 font-semibold">Status</th>
              <th className="py-3 text-left text-green-900 font-semibold">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map(u => (
              <tr key={u.id} className="border-b last:border-b-0 hover:bg-gray-50">
                <td className="py-3">
                  <div className="font-semibold">{u.name}</div>
                  <div className="text-xs text-gray-400">{u.email}</div>
                </td>
                <td className="py-3">{u.phone}</td>
                <td className="py-3">{u.joinedAt}</td>
                <td className="py-3">{u.ordersCount} orders</td>
                <td className="py-3"><StatusBadge status={u.status as "active" | "suspended"} /></td>
                <td className="py-3">
  <div className="flex items-center gap-4 text-xl">
    <button title="View"><FaEye className="text-gray-700" /></button>
    {u.status === "active" && <button title="Suspend"><FaPause className="text-yellow-600" /></button>}
    {u.status === "suspended" && <button title="Reactivate"><FaPlay className="text-green-600" /></button>}
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