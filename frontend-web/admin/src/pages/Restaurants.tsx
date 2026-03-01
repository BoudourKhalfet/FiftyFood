import { useEffect, useState } from "react";
import {
  FaSearch,
  FaCheck,
  FaTimes,
  FaEye,
  FaFileAlt,
  FaPause,
  FaPlay,
} from "react-icons/fa";
import { StatusBadge } from "../components/StatusBadge";
import { RestaurantModal } from "../components/UsersViewModals/RestaurantModal";
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

  useEffect(() => {
    async function fetchRestaurants() {
      setLoading(true);
      try {
        const resp = await fetch("/admin/users?role=RESTAURANT", {
          headers: {
            Authorization: "Bearer " + localStorage.getItem("access_token"),
          },
        });
        const data = await resp.json();
        setRestaurants(data);
        console.log("Fetched restaurants from API:", data);
      } catch {
        alert("Error fetching restaurants!");
      } finally {
        setLoading(false);
      }
    }
    fetchRestaurants();
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
    await fetch(`/admin/restaurants/${id}/suspend`, {
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
    await fetch(`/admin/restaurants/${id}/unsuspend`, {
      method: "POST",
      headers: {
        Authorization: "Bearer " + localStorage.getItem("access_token"),
      },
    });
    setRefresh((v) => v + 1);
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
    </div>
  );
}
