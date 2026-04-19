/* eslint-disable @typescript-eslint/no-explicit-any */
import { useEffect, useState } from "react";
import {
  FaSearch,
  FaCheck,
  FaTimes,
  FaEye,
  FaFileAlt,
  FaPause,
  FaPlay,
  FaTrash,
  FaPlus,
} from "react-icons/fa";
import { StatusBadge } from "../components/StatusBadge";
import { RestaurantModal } from "../components/UsersViewModals/RestaurantModal";
import { ConfirmActionModal } from "../components/ConfirmActionModal";
import { ReasonActionModal } from "../components/ReasonActionModal";
import { InfoModal } from "../components/InfoModal";
import { flattenRestaurantForModal } from "../utils/flattenRestaurantForModal";

type RestaurantUser = {
  id: string;
  email: string;
  status: string;
  statusReason?: string;
  restaurantProfile?: {
    restaurantName: string;
    submittedAt: string;
    businessRegistrationDocumentUrl?: string | null;
    hygieneCertificateUrl?: string | null;
    proofOfOwnershipOrLeaseUrl?: string | null;
    // Extend as needed (docs, trustScore, etc.)
  };
  legalAgreements?: {
    type: string;
    acceptedAt: string;
    signerName: string;
  }[];
};

export default function Restaurants() {
  const [restaurants, setRestaurants] = useState<RestaurantUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");
  const [refresh, setRefresh] = useState(0);
  const [modalOpen, setModalOpen] = useState(false);
  const [selectedRestaurant, setSelectedRestaurant] = useState<any | null>(
    null,
  );

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
    async function fetchRestaurants() {
      setLoading(true);
      try {
        console.log("Bearer token", localStorage.getItem("access_token"));
        const resp = await fetch("/admin/users?role=RESTAURANT", {
          headers: {
            Authorization: "Bearer " + localStorage.getItem("access_token"),
          },
        });
        if (!resp.ok) throw new Error("Failed to fetch restaurants");
        const data = await resp.json();
        setRestaurants(data);
        console.log("Fetched restaurants from API:", data);
      } catch {
        setInfoModal({
          title: "Load Error",
          message: "Failed to fetch restaurants.",
        });
      } finally {
        setLoading(false);
      }
    }
    fetchRestaurants();
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
        title: "Restaurant Approved",
        message: "Restaurant account approved successfully.",
      });
    } catch {
      setInfoModal({
        title: "Action Failed",
        message: "Unable to approve this restaurant.",
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
          : `/admin/restaurants/${reasonModal.targetId}/suspend`;

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
            ? "Restaurant Rejected"
            : "Restaurant Suspended",
        message:
          reasonModal.action === "reject"
            ? "Restaurant account was rejected."
            : "Restaurant account was suspended.",
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
      const resp = await fetch(`/admin/restaurants/${id}/unsuspend`, {
        method: "POST",
        headers: {
          Authorization: "Bearer " + localStorage.getItem("access_token"),
        },
      });
      if (!resp.ok) throw new Error("Failed to reactivate");
      setRefresh((v) => v + 1);
      setInfoModal({
        title: "Restaurant Reactivated",
        message: "Restaurant account is active again.",
      });
    } catch {
      setInfoModal({
        title: "Action Failed",
        message: "Unable to reactivate this restaurant.",
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
        title: "Restaurant Deleted",
        message: "Restaurant deleted successfully.",
      });
    } catch {
      setInfoModal({
        title: "Delete Failed",
        message: "Unable to delete this restaurant.",
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
          role: "RESTAURANT",
        }),
      });
      if (!resp.ok) {
        const error = await resp.json();
        setInfoModal({
          title: "Create Failed",
          message: error.message || "Failed to create restaurant.",
        });
        return;
      }
      setInfoModal({
        title: "Restaurant Created",
        message: "Restaurant created successfully.",
      });
      setAddUserFormData({ email: "", password: "" });
      setAddUserModalOpen(false);
      setRefresh((v) => v + 1);
    } catch {
      setInfoModal({
        title: "Create Failed",
        message: "Unable to create restaurant.",
      });
    }
  }

  // --- Filtering ---
  const filtered = restaurants.filter((r) => {
    const name = r.restaurantProfile?.restaurantName || "";
    const email = r.email || "";
    const normalizedStatus = r.status?.toLowerCase();
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
        <h2 className="text-xl font-semibold">Restaurant Management</h2>
        <div className="flex items-center gap-4">
          <button
            onClick={() => setAddUserModalOpen(true)}
            className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 text-sm font-medium"
          >
            <FaPlus /> Add Restaurant
          </button>
          <div className="relative">
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search..."
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
            <option value="rejected">Rejected</option>
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
                  Restaurant
                </th>
                <th className="py-3 text-left text-green-900 font-semibold">
                  Submitted
                </th>
                <th className="py-3 text-left text-green-900 font-semibold">
                  Docs
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
              {filtered.map((r) => {
                const normalizedStatus = r.status?.toLowerCase();
                return (
                  <tr
                    key={r.id}
                    className="border-b last:border-b-0 hover:bg-gray-50"
                  >
                    <td className="py-3">
                      <div className="font-semibold">
                        {r.restaurantProfile?.restaurantName || "(no name)"}
                      </div>
                      <div className="text-xs text-gray-400">{r.email}</div>
                    </td>
                    <td className="py-3">
                      {r.restaurantProfile?.submittedAt?.slice(0, 10) || "-"}
                    </td>
                    <td className="py-3">
                      {r.restaurantProfile?.businessRegistrationDocumentUrl && (
                        <a
                          href={
                            r.restaurantProfile.businessRegistrationDocumentUrl
                          }
                          target="_blank"
                          rel="noopener noreferrer"
                          className="bg-gray-100 rounded px-2 py-1 mr-1 text-xs font-semibold text-gray-500 underline hover:text-green-700"
                        >
                          Registration
                        </a>
                      )}
                      {r.restaurantProfile?.hygieneCertificateUrl && (
                        <a
                          href={r.restaurantProfile.hygieneCertificateUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="bg-gray-100 rounded px-2 py-1 mr-1 text-xs font-semibold text-gray-500 underline hover:text-green-700"
                        >
                          Hygiene
                        </a>
                      )}
                      {r.restaurantProfile?.proofOfOwnershipOrLeaseUrl && (
                        <a
                          href={r.restaurantProfile.proofOfOwnershipOrLeaseUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="bg-gray-100 rounded px-2 py-1 mr-1 text-xs font-semibold text-gray-500 underline hover:text-green-700"
                        >
                          Ownership/Lease
                        </a>
                      )}
                    </td>
                    <td className="py-3">
                      <StatusBadge status={normalizedStatus as any} />
                      {r.statusReason ? (
                        <div className="text-[10px] text-gray-500 italic">
                          {r.statusReason}
                        </div>
                      ) : null}
                    </td>
                    <td className="py-3">
                      <div className="flex items-center gap-4 text-xl">
                        <button
                          title="View"
                          onClick={() => {
                            const flatRestaurant = flattenRestaurantForModal(r);
                            setSelectedRestaurant(flatRestaurant);
                            setModalOpen(true);
                            console.log("Modal will receive:", flatRestaurant); // DEBUG - remove after
                          }}
                        >
                          <FaEye className="text-gray-700" />
                        </button>
                        <button title="Docs">
                          <FaFileAlt className="text-gray-700" />
                        </button>
                        {normalizedStatus === "pending" && (
                          <>
                            <button
                              title="Approve"
                              onClick={() => handleApprove(r.id)}
                            >
                              <FaCheck className="text-green-600" />
                            </button>
                            <button
                              title="Reject"
                              onClick={() => handleReject(r.id)}
                            >
                              <FaTimes className="text-red-600" />
                            </button>
                          </>
                        )}
                        {normalizedStatus === "approved" && (
                          <button
                            title="Suspend"
                            onClick={() => handleSuspend(r.id)}
                          >
                            <FaPause className="text-yellow-600" />
                          </button>
                        )}
                        {normalizedStatus === "suspended" && (
                          <button
                            title="Reactivate"
                            onClick={() => handleReactivate(r.id)}
                          >
                            <FaPlay className="text-green-600" />
                          </button>
                        )}
                        <button
                          title="Delete"
                          onClick={() => setDeleteCandidateId(r.id)}
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
                  <td colSpan={5} className="text-center text-gray-400 py-8">
                    No restaurants found.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        )}
      </div>
      {selectedRestaurant && (
        <RestaurantModal
          open={modalOpen}
          onClose={() => {
            setModalOpen(false);
            setSelectedRestaurant(null);
          }}
          restaurant={selectedRestaurant}
        />
      )}

      {/* --- ADD USER MODAL --- */}
      {addUserModalOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-8 w-96">
            <h3 className="text-xl font-bold mb-6">Add New Restaurant</h3>
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
        title="Delete Restaurant"
        message="Are you sure you want to delete this restaurant? This action cannot be undone."
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
            ? "Reject Restaurant"
            : "Suspend Restaurant"
        }
        message={
          reasonModal?.action === "reject"
            ? "Provide a reason for rejecting this restaurant account."
            : "Provide a reason for suspending this restaurant account."
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
