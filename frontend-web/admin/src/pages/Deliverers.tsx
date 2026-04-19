/* eslint-disable @typescript-eslint/no-explicit-any */
import { useEffect, useState } from "react";
import {
  FaEye,
  FaCheck,
  FaTimes,
  FaPause,
  FaPlay,
  FaSearch,
  FaTrash,
  FaPlus,
} from "react-icons/fa";
import { StatusBadge } from "../components/StatusBadge";
import { DelivererModal } from "../components/UsersViewModals/DelivererModal.tsx";
import { ConfirmActionModal } from "../components/ConfirmActionModal";
import { ReasonActionModal } from "../components/ReasonActionModal";
import { InfoModal } from "../components/InfoModal";
import { flattenDelivererForModal } from "../utils/flattenDelivererForModal";

type DelivererUser = {
  id: string;
  email: string;
  status: string;
  statusReason?: string;
  livreurProfile?: {
    fullName: string;
    phone: string;
    vehicleType: string;
    zone: string;
    photoUrl?: string | null;
    deliveries?: number;
    rating?: number;
    licensePhotoUrl?: string | null;
    vehicleOwnershipDocUrl?: string | null;
    vehiclePhotoUrl?: string | null;
  };
};

export default function Deliverers() {
  const [deliverers, setDeliverers] = useState<DelivererUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");
  const [refresh, setRefresh] = useState(0);
  const [modalOpen, setModalOpen] = useState(false);
  const [selectedDeliverer, setSelectedDeliverer] = useState<any | null>(null);

  // Add user modal state
  const [addUserModalOpen, setAddUserModalOpen] = useState(false);
  const [addUserFormData, setAddUserFormData] = useState({
    email: "",
    password: "",
  });
  const [deleteCandidateId, setDeleteCandidateId] = useState<string | null>(
    null,
  );
  const [reasonModal, setReasonModal] = useState<{
    action: "reject" | "suspend";
    targetId: string;
  } | null>(null);
  const [actionReason, setActionReason] = useState("");
  const [infoModal, setInfoModal] = useState<{
    title: string;
    message: string;
  } | null>(null);

  useEffect(() => {
    async function fetchDeliverers() {
      setLoading(true);
      try {
        const resp = await fetch("/admin/users?role=LIVREUR", {
          headers: {
            Authorization: "Bearer " + localStorage.getItem("access_token"),
          },
        });
        if (!resp.ok) throw new Error("Failed to fetch deliverers");
        const data = await resp.json();
        setDeliverers(data);
        console.log("Fetched deliverers from API:", data);
      } catch {
        setInfoModal({
          title: "Load Error",
          message: "Failed to fetch deliverers.",
        });
      } finally {
        setLoading(false);
      }
    }
    fetchDeliverers();
  }, [refresh]);

  async function handleApprove(id: string) {
    try {
      const resp = await fetch(`/admin/users/${id}/approve`, {
        method: "POST",
        headers: {
          Authorization: "Bearer " + localStorage.getItem("access_token"),
        },
      });
      if (!resp.ok) throw new Error("Failed to approve");
      setRefresh((v) => v + 1);
      setInfoModal({
        title: "Deliverer Approved",
        message: "Deliverer account approved successfully.",
      });
    } catch {
      setInfoModal({
        title: "Action Failed",
        message: "Unable to approve this deliverer.",
      });
    }
  }

  function handleReject(id: string) {
    setReasonModal({ action: "reject", targetId: id });
    setActionReason("");
  }

  function handleSuspend(id: string) {
    setReasonModal({ action: "suspend", targetId: id });
    setActionReason("");
  }

  async function submitReasonAction() {
    if (!reasonModal) return;
    if (!actionReason.trim()) {
      setInfoModal({
        title: "Missing Reason",
        message: "Please provide a reason before submitting.",
      });
      return;
    }

    try {
      const endpoint =
        reasonModal.action === "reject"
          ? `/admin/users/${reasonModal.targetId}/reject`
          : `/admin/livreurs/${reasonModal.targetId}/suspend`;

      const resp = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: "Bearer " + localStorage.getItem("access_token"),
        },
        body: JSON.stringify({ reason: actionReason.trim() }),
      });

      if (!resp.ok) throw new Error("Reason action failed");

      setRefresh((v) => v + 1);
      setInfoModal({
        title:
          reasonModal.action === "reject"
            ? "Deliverer Rejected"
            : "Deliverer Suspended",
        message:
          reasonModal.action === "reject"
            ? "Deliverer account was rejected."
            : "Deliverer account was suspended.",
      });
      setReasonModal(null);
      setActionReason("");
    } catch {
      setInfoModal({
        title: "Action Failed",
        message: "Unable to complete this action.",
      });
    }
  }

  async function handleReactivate(id: string) {
    try {
      const resp = await fetch(`/admin/livreurs/${id}/unsuspend`, {
        method: "POST",
        headers: {
          Authorization: "Bearer " + localStorage.getItem("access_token"),
        },
      });
      if (!resp.ok) throw new Error("Failed to reactivate");
      setRefresh((v) => v + 1);
      setInfoModal({
        title: "Deliverer Reactivated",
        message: "Deliverer account is active again.",
      });
    } catch {
      setInfoModal({
        title: "Action Failed",
        message: "Unable to reactivate this deliverer.",
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
      if (!resp.ok) throw new Error("Failed to delete");
      setRefresh((v) => v + 1);
      setInfoModal({
        title: "Deliverer Deleted",
        message: "Deliverer deleted successfully.",
      });
    } catch {
      setInfoModal({
        title: "Delete Failed",
        message: "Unable to delete this deliverer.",
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
          role: "LIVREUR",
        }),
      });
      if (!resp.ok) {
        const error = await resp.json();
        setInfoModal({
          title: "Create Failed",
          message: error.message || "Failed to create deliverer.",
        });
        return;
      }
      setInfoModal({
        title: "Deliverer Created",
        message: "Deliverer created successfully.",
      });
      setAddUserFormData({ email: "", password: "" });
      setAddUserModalOpen(false);
      setRefresh((v) => v + 1);
    } catch {
      setInfoModal({
        title: "Create Failed",
        message: "Unable to create deliverer.",
      });
    }
  }

  const filtered = deliverers.filter((d) => {
    const name = d.livreurProfile?.fullName || "";
    const email = d.email || "";
    const normalizedStatus = d.status?.toLowerCase();
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
        <h2 className="text-xl font-semibold">Deliverer Management</h2>
        <div className="flex items-center gap-4">
          <button
            onClick={() => setAddUserModalOpen(true)}
            className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 text-sm font-medium"
          >
            <FaPlus /> Add Deliverer
          </button>
          <div className="relative">
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search deliverers..."
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
            <option value="pending">Pending</option>
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
                  Deliverer
                </th>
                <th className="py-3 text-left text-green-900 font-semibold">
                  Vehicle / Zone
                </th>
                <th className="py-3 text-left text-green-900 font-semibold">
                  Deliveries
                </th>
                <th className="py-3 text-left text-green-900 font-semibold">
                  Rating
                </th>
                <th className="py-3 text-left text-green-900 font-semibold">
                  Documents
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
              {filtered.map((d) => {
                const normalizedStatus = d.status?.toLowerCase();
                return (
                  <tr
                    key={d.id}
                    className="border-b last:border-b-0 hover:bg-gray-50"
                  >
                    <td className="py-3">
                      <div className="font-semibold">
                        {d.livreurProfile?.fullName || "(no name)"}
                      </div>
                      <div className="text-xs text-gray-400">{d.email}</div>
                    </td>
                    <td className="py-3">
                      <div>{d.livreurProfile?.vehicleType}</div>
                      <div className="text-xs text-gray-400">
                        {d.livreurProfile?.zone}
                      </div>
                    </td>
                    <td className="py-3">
                      {d.livreurProfile?.deliveries ?? "-"}
                    </td>
                    <td className="py-3">
                      {d.livreurProfile?.rating != null ? (
                        <span className="font-bold text-yellow-600">
                          {d.livreurProfile.rating} ★
                        </span>
                      ) : (
                        <span className="text-gray-400">N/A</span>
                      )}
                    </td>
                    <td className="py-3">
                      {d.livreurProfile?.licensePhotoUrl && (
                        <a
                          href={d.livreurProfile.licensePhotoUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="bg-gray-100 rounded px-2 py-1 mr-1 text-xs font-semibold text-gray-500 underline hover:text-green-700"
                        >
                          License
                        </a>
                      )}
                      {d.livreurProfile?.vehicleOwnershipDocUrl && (
                        <a
                          href={d.livreurProfile.vehicleOwnershipDocUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="bg-gray-100 rounded px-2 py-1 mr-1 text-xs font-semibold text-gray-500 underline hover:text-green-700"
                        >
                          Vehicle Ownership
                        </a>
                      )}
                      {d.livreurProfile?.vehiclePhotoUrl && (
                        <a
                          href={d.livreurProfile.vehiclePhotoUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="bg-gray-100 rounded px-2 py-1 mr-1 text-xs font-semibold text-gray-500 underline hover:text-green-700"
                        >
                          Vehicle Photo
                        </a>
                      )}
                    </td>
                    <td className="py-3">
                      <StatusBadge status={normalizedStatus as any} />
                      {d.statusReason && (
                        <div className="text-[10px] text-gray-500 italic">
                          {d.statusReason}
                        </div>
                      )}
                    </td>
                    <td className="py-3">
                      <div className="flex items-center gap-4 text-xl">
                        <button
                          title="View"
                          onClick={() => {
                            setSelectedDeliverer(flattenDelivererForModal(d));
                            setModalOpen(true);
                          }}
                        >
                          <FaEye className="text-gray-700" />
                        </button>
                        {normalizedStatus === "pending" && (
                          <>
                            <button
                              title="Approve"
                              onClick={() => handleApprove(d.id)}
                            >
                              <FaCheck className="text-green-600" />
                            </button>
                            <button
                              title="Reject"
                              onClick={() => handleReject(d.id)}
                            >
                              <FaTimes className="text-red-600" />
                            </button>
                          </>
                        )}
                        {normalizedStatus === "approved" && (
                          <button
                            title="Suspend"
                            onClick={() => handleSuspend(d.id)}
                          >
                            <FaPause className="text-yellow-600" />
                          </button>
                        )}
                        {normalizedStatus === "suspended" && (
                          <button
                            title="Reactivate"
                            onClick={() => handleReactivate(d.id)}
                          >
                            <FaPlay className="text-green-600" />
                          </button>
                        )}
                        <button
                          title="Delete"
                          onClick={() => setDeleteCandidateId(d.id)}
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
                  <td colSpan={7} className="text-center text-gray-400 py-8">
                    No deliverers found.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        )}
      </div>
      {selectedDeliverer && (
        <DelivererModal
          open={modalOpen}
          onClose={() => {
            setModalOpen(false);
            setSelectedDeliverer(null);
          }}
          deliverer={selectedDeliverer}
        />
      )}

      {/* --- ADD USER MODAL --- */}
      {addUserModalOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-8 w-96">
            <h3 className="text-xl font-bold mb-6">Add New Deliverer</h3>
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
        title="Delete Deliverer"
        message="Are you sure you want to delete this deliverer? This action cannot be undone."
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
        open={reasonModal !== null}
        title={
          reasonModal?.action === "reject"
            ? "Reject Deliverer"
            : "Suspend Deliverer"
        }
        message={
          reasonModal?.action === "reject"
            ? "Provide a reason for rejecting this deliverer account."
            : "Provide a reason for suspending this deliverer account."
        }
        value={actionReason}
        placeholder="Reason"
        confirmText={reasonModal?.action === "reject" ? "Reject" : "Suspend"}
        onChange={setActionReason}
        onCancel={() => {
          setReasonModal(null);
          setActionReason("");
        }}
        onConfirm={() => {
          void submitReasonAction();
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
