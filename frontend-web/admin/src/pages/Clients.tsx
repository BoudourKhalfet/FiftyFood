import { useEffect, useState } from "react";
import { FaEye, FaPause, FaPlay, FaSearch } from "react-icons/fa";
import { StatusBadge } from "../components/StatusBadge";
import { ClientModal } from "../components/UsersViewModals/ClientModal";
import { flattenClientForModal } from "../utils/flattenClientForModal.ts";

type ClientUser = {
  id: string;
  email: string;
  status: string;
  statusReason?: string;
  clientProfile?: {
    fullName: string;
    phone: string;
    address?: string;
    joinedAt?: string;
    lastActiveAt?: string;
    ordersCount?: number;
    totalSpent?: number;
    avgRating?: number;
    // Add any additional client profile fields you want to display!
  };
  accountHistory?: Array<{
    date: string;
    actor: string;
    action: string;
    description: string;
    actionType: string;
  }>;
};

export default function Clients() {
  const [clients, setClients] = useState<ClientUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");
  const [refresh, setRefresh] = useState(0);

  // Modal state
  const [modalOpen, setModalOpen] = useState(false);
  const [selectedClient, setSelectedClient] = useState<any | null>(null);

  useEffect(() => {
    async function fetchClients() {
      setLoading(true);
      try {
        const resp = await fetch("/admin/users?role=CLIENT", {
          headers: {
            Authorization: "Bearer " + localStorage.getItem("access_token"),
          },
        });
        const data = await resp.json();
        console.log("Fetched clients:", data);
        setClients(data);
      } catch {
        alert("Error fetching clients!");
      } finally {
        setLoading(false);
      }
    }
    fetchClients();
  }, [refresh]);

  async function handleSuspend(id: string) {
    const reason = prompt("Reason for suspension?");
    if (!reason) return;
    await fetch(`/admin/clients/${id}/suspend`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer " + localStorage.getItem("access_token"),
      },
      body: JSON.stringify({ reason }),
    });
    setRefresh((v) => v + 1);
  }

  async function handleReactivate(id: string) {
    await fetch(`/admin/clients/${id}/unsuspend`, {
      method: "POST",
      headers: {
        Authorization: "Bearer " + localStorage.getItem("access_token"),
      },
    });
    setRefresh((v) => v + 1);
  }

  // --- Filtering ---
  const filtered = clients.filter((u) => {
    const name = u.clientProfile?.fullName || "";
    const email = u.email || "";
    const normalizedStatus = u.status?.toLowerCase();
    const statusOk = status === "all" || normalizedStatus === status;
    const searchOk =
      search === "" ||
      name.toLowerCase().includes(search.toLowerCase()) ||
      email.toLowerCase().includes(search.toLowerCase());
    return statusOk && searchOk;
  });

  return (
    <div className="p-12 bg-[#f8f8f6] min-h-screen">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Admin Dashboard</h1>
        <p className="text-lg text-gray-400">
          Platform governance and supervision
        </p>
      </div>
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-semibold">Clients Management</h2>
        <div className="flex items-center gap-4">
          <div className="relative">
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search clients..."
              className="w-[210px] pl-10 pr-4 py-2 rounded-md border border-gray-200 bg-gray-50 text-sm focus:ring-1 focus:ring-green-400"
            />
            <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400">
              <FaSearch />
            </span>
          </div>
          <select
            value={status}
            onChange={(e) => setStatus(e.target.value)}
            className="w-[140px] px-4 py-2 rounded-md border border-gray-200 bg-gray-50 text-sm"
          >
            <option value="all">All Status</option>
            <option value="approved">Approved</option>
            <option value="suspended">Suspended</option>
          </select>
        </div>
      </div>
      <div className="bg-white rounded-2xl border shadow p-6">
        {loading ? (
          <div className="text-center text-gray-400 py-10">Loading...</div>
        ) : (
          <table className="w-full text-gray-800">
            <thead>
              <tr>
                <th className="py-3 text-left text-green-900 font-semibold">
                  User
                </th>
                <th className="py-3 text-left text-green-900 font-semibold">
                  Contact
                </th>
                <th className="py-3 text-left text-green-900 font-semibold">
                  Joined
                </th>
                <th className="py-3 text-left text-green-900 font-semibold">
                  Orders
                </th>
                <th className="py-3 text-left text-green-900 font-semibold">
                  Status
                </th>
                <th className="py-3 text-left text-green-900 font-semibold">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((u) => {
                const normalizedStatus = u.status?.toLowerCase();
                return (
                  <tr
                    key={u.id}
                    className="border-b last:border-b-0 hover:bg-gray-50"
                  >
                    <td className="py-3">
                      <div className="font-semibold">
                        {u.clientProfile?.fullName || "(no name)"}
                      </div>
                      <div className="text-xs text-gray-400">{u.email}</div>
                    </td>
                    <td className="py-3">{u.clientProfile?.phone}</td>
                    <td className="py-3">
                      {u.clientProfile?.joinedAt
                        ? new Date(
                            u.clientProfile.joinedAt,
                          ).toLocaleDateString()
                        : "-"}
                    </td>
                    <td className="py-3">
                      {u.clientProfile?.ordersCount != null
                        ? `${u.clientProfile.ordersCount} orders`
                        : "-"}
                    </td>
                    <td className="py-3">
                      <StatusBadge status={normalizedStatus as any} />
                      {u.statusReason ? (
                        <div className="text-[10px] text-gray-500 italic">
                          {u.statusReason}
                        </div>
                      ) : null}
                    </td>
                    <td className="py-3">
                      <div className="flex items-center gap-4 text-xl">
                        <button
                          title="View"
                          onClick={() => {
                            setSelectedClient(flattenClientForModal(u));
                            setModalOpen(true);
                          }}
                        >
                          <FaEye className="text-gray-700" />
                        </button>
                        {normalizedStatus === "approved" && (
                          <button
                            title="Suspend"
                            onClick={() => handleSuspend(u.id)}
                          >
                            <FaPause className="text-yellow-600" />
                          </button>
                        )}
                        {normalizedStatus === "suspended" && (
                          <button
                            title="Reactivate"
                            onClick={() => handleReactivate(u.id)}
                          >
                            <FaPlay className="text-green-600" />
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
              {filtered.length === 0 && (
                <tr>
                  <td colSpan={6} className="text-center text-gray-400 py-8">
                    No clients found.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        )}
      </div>

      {/* --- MODAL RENDER --- */}
      {selectedClient && (
        <ClientModal
          open={modalOpen}
          onClose={() => {
            setModalOpen(false);
            setSelectedClient(null);
          }}
          client={selectedClient}
        />
      )}
    </div>
  );
}
