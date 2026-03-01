import { useEffect, useState } from "react";
import {
  FaEye,
  FaCheck,
  FaTimes,
  FaPause,
  FaPlay,
  FaSearch,
} from "react-icons/fa";
import { StatusBadge } from "../components/StatusBadge";
import { DelivererModal } from "../components/UsersViewModals/DelivererModal.tsx";
import { flattenDelivererForModal } from "../utils/flattenDelivererForModal";
import { data } from "react-router-dom";

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

  useEffect(() => {
    async function fetchDeliverers() {
      setLoading(true);
      try {
        const resp = await fetch("/admin/users?role=LIVREUR", {
          headers: {
            Authorization: "Bearer " + localStorage.getItem("access_token"),
          },
        });
        setDeliverers(await resp.json());
        console.log("Fetched delivers from API:", data);
      } catch {
        alert("Error fetching deliverers!");
      } finally {
        setLoading(false);
      }
    }
    fetchDeliverers();
  }, [refresh]);

  async function handleApprove(id: string) {
    await fetch(`/admin/users/${id}/approve`, {
      method: "POST",
      headers: {
        Authorization: "Bearer " + localStorage.getItem("access_token"),
      },
    });
    setRefresh((v) => v + 1);
  }

  async function handleReject(id: string) {
    const reason = prompt("Reason for rejection?");
    if (!reason) return;
    await fetch(`/admin/users/${id}/reject`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer " + localStorage.getItem("access_token"),
      },
      body: JSON.stringify({ reason }),
    });
    setRefresh((v) => v + 1);
  }

  async function handleSuspend(id: string) {
    const reason = prompt("Reason for suspension?");
    if (!reason) return;
    await fetch(`/admin/livreurs/${id}/suspend`, {
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
    await fetch(`/admin/livreurs/${id}/unsuspend`, {
      method: "POST",
      headers: {
        Authorization: "Bearer " + localStorage.getItem("access_token"),
      },
    });
    setRefresh((v) => v + 1);
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
    </div>
  );
}
