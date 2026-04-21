/* eslint-disable @typescript-eslint/no-explicit-any */
import { useEffect, useState } from "react";
import {
  FaEye,
  FaPause,
  FaPlay,
  FaSearch,
  FaTrash,
  FaPlus,
} from "react-icons/fa";
import { StatusBadge } from "../components/StatusBadge";
import { ClientModal } from "../components/UsersViewModals/ClientModal";
import { ConfirmActionModal } from "../components/ConfirmActionModal";
import { ReasonActionModal } from "../components/ReasonActionModal";
import { InfoModal } from "../components/InfoModal";
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

  // Add user modal state
  const [addUserModalOpen, setAddUserModalOpen] = useState(false);
  const [addUserFormData, setAddUserFormData] = useState({
    email: "",
    password: "",
  });
  const [deleteCandidateId, setDeleteCandidateId] = useState<string | null>(
    null,
  );
  const [suspendCandidateId, setSuspendCandidateId] = useState<string | null>(
    null,
  );
  const [suspendReason, setSuspendReason] = useState("");
  const [infoModal, setInfoModal] = useState<{
    title: string;
    message: string;
  } | null>(null);

  useEffect(() => {
    async function fetchClients() {
      setLoading(true);
      try {
        const token = localStorage.getItem("access_token");
        console.log("Bearer token exists:", !!token);
        const resp = await fetch("/admin/users?role=CLIENT", {
          headers: {
            Authorization: "Bearer " + token,
          },
        });
        console.log("Fetch response status:", resp.status);
        if (!resp.ok) {
          const errorData = await resp.json().catch(() => ({ error: "Unable to parse error" }));
          console.log("Error response:", errorData);
          throw new Error(`Failed to fetch clients: ${resp.status}`);
        }
        const data = await resp.json();
        console.log("Fetched clients:", data);
        setClients(data);
      } catch (error) {
        console.error("Fetch error:", error);
        setInfoModal({
          title: "Load Error",
          message: "Failed to fetch clients.",
        });
      } finally {
        setLoading(false);
      }
    }
    fetchClients();
  }, [refresh]);

  function handleSuspend(id: string) {
    setSuspendCandidateId(id);
    setSuspendReason("");
  }

  async function submitSuspend() {
    if (!suspendCandidateId) return;
    if (!suspendReason.trim()) {
      setInfoModal({
        title: "Missing Reason",
        message: "Please provide a suspension reason.",
      });
      return;
    }

    try {
      const resp = await fetch(`/admin/clients/${suspendCandidateId}/suspend`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: "Bearer " + localStorage.getItem("access_token"),
        },
        body: JSON.stringify({ reason: suspendReason.trim() }),
      });

      if (!resp.ok) throw new Error("Failed to suspend client");

      setInfoModal({
        title: "Client Suspended",
        message: "Client has been suspended successfully.",
      });
      setRefresh((v) => v + 1);
      setSuspendCandidateId(null);
      setSuspendReason("");
    } catch {
      setInfoModal({
        title: "Action Failed",
        message: "Unable to suspend this client.",
      });
    }
  }

  async function handleReactivate(id: string) {
    try {
      const resp = await fetch(`/admin/clients/${id}/unsuspend`, {
        method: "POST",
        headers: {
          Authorization: "Bearer " + localStorage.getItem("access_token"),
        },
      });
      if (!resp.ok) throw new Error("Failed to reactivate client");
      setRefresh((v) => v + 1);
      setInfoModal({
        title: "Client Reactivated",
        message: "Client account is active again.",
      });
    } catch {
      setInfoModal({
        title: "Action Failed",
        message: "Unable to reactivate this client.",
      });
    }
  }

  async function handleDelete(id: string) {
    try {
      const resp = await fetch(`/admin/users/${id}`, {
        method: "DELETE",
        headers: {
          Authorization: "Bearer " + localStorage.getItem("access_token"),
        },
      });
      if (!resp.ok) throw new Error("Failed to delete client");
      setRefresh((v) => v + 1);
      setInfoModal({
        title: "Client Deleted",
        message: "Client deleted successfully.",
      });
    } catch {
      setInfoModal({
        title: "Delete Failed",
        message: "Unable to delete this client.",
      });
    }
  }

  async function handleAddUser() {
    if (!addUserFormData.email || !addUserFormData.password) {
      setInfoModal({
        title: "Missing Fields",
        message: "Please fill in all fields.",
      });
      return;
    }
    try {
      const resp = await fetch("/admin/users", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: "Bearer " + localStorage.getItem("access_token"),
        },
        body: JSON.stringify({
          email: addUserFormData.email,
          password: addUserFormData.password,
          role: "CLIENT",
        }),
      });
      if (!resp.ok) {
        const error = await resp.json();
        setInfoModal({
          title: "Create Failed",
          message: error.message || "Failed to create client.",
        });
        return;
      }
      setInfoModal({
        title: "Client Created",
        message: "Client created successfully.",
      });
      setAddUserFormData({ email: "", password: "" });
      setAddUserModalOpen(false);
      setRefresh((v) => v + 1);
    } catch {
      setInfoModal({
        title: "Create Failed",
        message: "Unable to create client.",
      });
    }
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
          <button
            onClick={() => setAddUserModalOpen(true)}
            className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 text-sm font-medium"
          >
            <FaPlus /> Add Client
          </button>
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
                        <button
                          title="Delete"
                          onClick={() => setDeleteCandidateId(u.id)}
                        >
                          <FaTrash className="text-red-600" />
                        </button>
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

      {/* --- ADD USER MODAL --- */}
      {addUserModalOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-8 w-96">
            <h3 className="text-xl font-bold mb-6">Add New Client</h3>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-1">Email</label>
                <input
                  type="email"
                  value={addUserFormData.email}
                  onChange={(e) =>
                    setAddUserFormData({
                      ...addUserFormData,
                      email: e.target.value,
                    })
                  }
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-green-400"
                />
              </div>
              <div>
                <label className="block text-sm font-medium mb-1">
                  Password
                </label>
                <input
                  type="password"
                  value={addUserFormData.password}
                  onChange={(e) =>
                    setAddUserFormData({
                      ...addUserFormData,
                      password: e.target.value,
                    })
                  }
                  placeholder="Min 8 chars, 1 uppercase, 1 lowercase, 1 number, 1 special char"
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-green-400"
                />
              </div>
            </div>
            <div className="flex gap-2 mt-6">
              <button
                onClick={handleAddUser}
                className="flex-1 px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700"
              >
                Create
              </button>
              <button
                onClick={() => {
                  setAddUserModalOpen(false);
                  setAddUserFormData({ email: "", password: "" });
                }}
                className="flex-1 px-4 py-2 bg-gray-300 text-gray-800 rounded-md hover:bg-gray-400"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      <ConfirmActionModal
        open={deleteCandidateId !== null}
        title="Delete Client"
        message="Are you sure you want to delete this client? This action cannot be undone."
        confirmText="Delete"
        cancelText="Cancel"
        onCancel={() => setDeleteCandidateId(null)}
        onConfirm={() => {
          if (!deleteCandidateId) return;
          void handleDelete(deleteCandidateId);
          setDeleteCandidateId(null);
        }}
      />

      <ReasonActionModal
        open={suspendCandidateId !== null}
        title="Suspend Client"
        message="Provide a reason for suspending this client account."
        value={suspendReason}
        placeholder="Suspension reason"
        confirmText="Suspend"
        onChange={setSuspendReason}
        onCancel={() => {
          setSuspendCandidateId(null);
          setSuspendReason("");
        }}
        onConfirm={() => {
          void submitSuspend();
        }}
      />

      <InfoModal
        open={infoModal !== null}
        title={infoModal?.title || ""}
        message={infoModal?.message || ""}
        onClose={() => setInfoModal(null)}
      />
    </div>
  );
}
