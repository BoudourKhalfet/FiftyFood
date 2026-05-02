import { useEffect, useState } from "react";
import { FaStore, FaShippingFast, FaBan, FaEye } from "react-icons/fa";

type ComplaintCategory = {
  reason: string;
  count: number;
};

type RestaurantStat = {
  id: string;
  restaurantName: string;
  email: string;
  status: string;
  suspendedAt: string | null;
  totalOrders: number;
  totalComplaints: number;
  avgRating: number;
  reportRate?: number;
  complaintCategories: ComplaintCategory[];
};

type DelivererStat = {
  id: string;
  delivererName: string;
  email: string;
  status: string;
  suspendedAt: string | null;
  totalOrders: number;
  totalComplaints: number;
  avgRating: number;
  reportRate?: number;
  complaintCategories: ComplaintCategory[];
};

// Type guard
function isRestaurant(item: RestaurantStat | DelivererStat): item is RestaurantStat {
  return "restaurantName" in item;
}

type GlobalComplaintCategory = {
  reason: string;
  count: number;
  targetType: string;
};

type Complaint = {
  id: string;
  reason: string;
  description: string | null;
  createdAt: string;
  restaurantId: string | null;
  delivererId: string | null;
  orderId: string | null;
  orderReference: string | null;
  orderCode: string | null;
  complainantEmail: string | null;
  complainantName: string | null;
  restaurantName: string | null;
  delivererName: string | null;
};

type ReportData = {
  complaints: Complaint[];
  restaurantStats: RestaurantStat[];
  delivererStats: DelivererStat[];
  complaintCategories: GlobalComplaintCategory[];
};

export default function Reports() {
  const [data, setData] = useState<ReportData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<"restaurants" | "deliverers">("restaurants");
  const [selectedItem, setSelectedItem] = useState<RestaurantStat | DelivererStat | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);

  useEffect(() => {
    async function fetchReports() {
      try {
        const token = localStorage.getItem("access_token");
        const resp = await fetch("/admin/complaints/report", {
          headers: {
            Authorization: "Bearer " + token,
          },
        });

        if (!resp.ok) {
          throw new Error(`Failed to fetch: ${resp.status}`);
        }

        const result = await resp.json();
        setData(result);
      } catch (e: any) {
        setError(e.message);
      } finally {
        setLoading(false);
      }
    }

    fetchReports();
  }, []);

  const handleBan = async (id: string, type: "restaurant" | "deliverer") => {
    const token = localStorage.getItem("access_token");
    const endpoint = type === "restaurant" 
      ? `/admin/restaurants/${id}/suspend`
      : `/admin/livreurs/${id}/suspend`;
    
    try {
      const resp = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: "Bearer " + token,
        },
        body: JSON.stringify({ reason: "High complaint rate" }),
      });

      if (resp.ok) {
        // Refresh data
        window.location.reload();
      }
    } catch (e) {
      console.error("Failed to ban:", e);
    }
  };

  // Risk Score (0-100) - Aggressive flagging for high complaint rates
  const calculateRiskScore = (complaints: number, orders: number, avgRating: number): number => {
    // No orders and no complaints = healthy
    if (orders === 0 && complaints === 0) {
      return 0;
    }
    
    // No orders but has complaints = high risk
    if (orders === 0) {
      return Math.min(90, 50 + complaints * 20);
    }
    
    // Calculate complaint rate
    const complaintRate = (complaints / orders) * 100;
    
    // CRITICAL: High complaint rates (>50%) should always be flagged as HIGH RISK
    // regardless of sample size - this is an emergency signal
    if (complaintRate >= 50) {
      // 50% complaints = 60 score, 75% = 75 score, 100% = 90 score
      const baseScore = 60 + ((complaintRate - 50) / 50) * 30;
      // Add rating penalty
      const ratingPenalty = avgRating < 3.0 ? 10 : avgRating < 4.0 ? 5 : 0;
      return Math.round(Math.min(95, baseScore + ratingPenalty));
    }
    
    // MODERATE: 30-50% complaint rate
    if (complaintRate >= 30) {
      const baseScore = 40 + ((complaintRate - 30) / 20) * 20; // 30% = 40, 50% = 60
      const ratingPenalty = avgRating < 3.0 ? 10 : avgRating < 4.0 ? 5 : 0;
      return Math.round(Math.min(70, baseScore + ratingPenalty));
    }
    
    // LOWER: <30% complaint rate - use confidence scaling
    const confidence = Math.min(1, 0.5 + (orders / 50)); // 5 orders = 60%, 25 = 100%
    const complaintScore = complaintRate * confidence;
    
    // Rating component for lower complaint rates
    let ratingPenalty = 0;
    if (avgRating >= 4.5) ratingPenalty = 0;
    else if (avgRating >= 4.0) ratingPenalty = 5;
    else if (avgRating >= 3.0) ratingPenalty = 15;
    else if (avgRating >= 2.0) ratingPenalty = 35;
    else ratingPenalty = 60;
    
    const finalScore = (complaintScore * 0.8) + (ratingPenalty * 0.2);
    return Math.round(Math.min(finalScore, 100));
  };

  // Severity Levels with Actions
  type SeverityLevel = {
    label: string;
    color: string;
    bgColor: string;
    action: string;
    banRecommended: boolean;
  };

  const getSeverityLevel = (score: number): SeverityLevel => {
    if (score >= 85) {
      return { 
        label: "CRITICAL", 
        color: "#7C2D12", 
        bgColor: "#FEF2F2", 
        action: "BAN IMMEDIATELY",
        banRecommended: true 
      };
    }
    if (score >= 60) {
      return { 
        label: "HIGH RISK", 
        color: "#DC2626", 
        bgColor: "#FEF2F2", 
        action: "Ban Recommended",
        banRecommended: true 
      };
    }
    if (score >= 35) {
      return { 
        label: "MODERATE RISK", 
        color: "#EA580C", 
        bgColor: "#FFF7ED", 
        action: "Monitor Closely",
        banRecommended: false 
      };
    }
    if (score >= 15) {
      return { 
        label: "LOW RISK", 
        color: "#CA8A04", 
        bgColor: "#FEFCE8", 
        action: "Watch",
        banRecommended: false 
      };
    }
    return { 
      label: "HEALTHY", 
      color: "#16A34A", 
      bgColor: "#F0FDF4", 
      action: "No Action Needed",
      banRecommended: false 
    };
  };

  // Get complaint categories for a specific restaurant/deliverer
  const getCategories = (item: RestaurantStat | DelivererStat): ComplaintCategory[] => {
    return item.complaintCategories?.slice(0, 4) || [];
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-gray-500">Loading reports...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-red-500">Error: {error}</div>
      </div>
    );
  }

  const restaurantList = (data?.restaurantStats || [])
    .map((r) => ({
      ...r,
      riskScore: calculateRiskScore(r.totalComplaints, r.totalOrders, r.avgRating || 0),
    }))
    .sort((a, b) => b.riskScore - a.riskScore);

  const delivererList = (data?.delivererStats || [])
    .map((d) => ({
      ...d,
      riskScore: calculateRiskScore(d.totalComplaints, d.totalOrders, d.avgRating || 0),
    }))
    .sort((a, b) => b.riskScore - a.riskScore);

  const currentList = activeTab === "restaurants" ? restaurantList : delivererList;

  return (
    <div className="p-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-gray-900 mb-2">Risk Assessment Dashboard</h1>
        <p className="text-gray-600">
          {activeTab === "restaurants" 
            ? "Restaurants" 
            : "Deliverers"} ranked by composite risk score (complaints + rating impact)
        </p>
      </div>

      {/* Tabs */}
      <div className="flex gap-4 mb-6">
        <button
          onClick={() => setActiveTab("restaurants")}
          className={`flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-colors ${
            activeTab === "restaurants"
              ? "bg-red-50 text-red-600 border border-red-200"
              : "bg-white text-gray-600 border border-gray-200 hover:bg-gray-50"
          }`}
        >
          <FaStore />
          Restaurants
        </button>
        <button
          onClick={() => setActiveTab("deliverers")}
          className={`flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-colors ${
            activeTab === "deliverers"
              ? "bg-orange-50 text-orange-600 border border-orange-200"
              : "bg-white text-gray-600 border border-gray-200 hover:bg-gray-50"
          }`}
        >
          <FaShippingFast />
          Deliverers
        </button>
      </div>

      {/* Stats Summary */}
      <div className="grid grid-cols-3 gap-4 mb-6">
        <div className="bg-white p-4 rounded-xl border border-gray-200">
          <div className="text-sm text-gray-500 mb-1">Total {activeTab === "restaurants" ? "Restaurants" : "Deliverers"}</div>
          <div className="text-2xl font-bold text-gray-900">{currentList.length}</div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-gray-200">
          <div className="text-sm text-gray-500 mb-1">High Risk (Score ≥60)</div>
          <div className="text-2xl font-bold text-red-600">
            {currentList.filter((i) => i.riskScore >= 60).length}
          </div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-gray-200">
          <div className="text-sm text-gray-500 mb-1">Total Complaints</div>
          <div className="text-2xl font-bold text-gray-900">
            {currentList.reduce((sum, i) => sum + i.totalComplaints, 0)}
          </div>
        </div>
      </div>

      {/* Report List */}
      <div className="space-y-4">
        {currentList.map((item) => {
          const name = isRestaurant(item) ? item.restaurantName : (item as any).delivererName;
          const riskScore = item.riskScore || 0;
          const severity = getSeverityLevel(riskScore);
          const suspended = !!item.suspendedAt;
          const categories = getCategories(item);
          const reportRate = item.totalOrders > 0 ? (item.totalComplaints / item.totalOrders) * 100 : 0;

          return (
            <div
              key={item.id}
              className="bg-white rounded-xl border border-gray-200 p-5 shadow-sm"
            >
              {/* Top Row */}
              <div className="flex items-start justify-between mb-3">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-lg bg-teal-50 flex items-center justify-center">
                    {isRestaurant(item) ? (
                      <FaStore className="text-lg text-teal-600" />
                    ) : (
                      <FaShippingFast className="text-lg text-teal-600" />
                    )}
                  </div>
                  <div>
                    <h3 className="font-semibold text-gray-900">{name || "Unknown"}</h3>
                    <p className="text-sm text-gray-500">
                      <span className="text-gray-700 font-medium">{item.totalComplaints}</span> reports / {" "}
                      <span className="text-gray-700 font-medium">{item.totalOrders}</span> orders{" "}
                      {item.avgRating > 0 && (
                        <span className="ml-1">
                          <span className="text-amber-500">★{item.avgRating.toFixed(1)}</span>
                        </span>
                      )}
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-3">
                  <div className="text-right">
                    <div className="text-2xl font-bold text-gray-700">
                      {Math.round(riskScore)}<span className="text-sm text-gray-400 font-normal">/100</span>
                    </div>
                    <span
                      className="text-xs font-semibold px-2 py-0.5 rounded-full"
                      style={{
                        backgroundColor: suspended ? '#F3F4F6' : severity.bgColor,
                        color: suspended ? '#6B7280' : severity.color,
                      }}
                    >
                      {suspended ? 'BANNED' : severity.label}
                    </span>
                  </div>
                </div>
              </div>

              {/* Progress Bar - Shows actual risk score components */}
              <div className="flex items-center gap-2 mb-2">
                <div className="flex-1 h-2 rounded-full overflow-hidden flex bg-gray-100">
                  {/* Actual risk score fill - color based on severity, no fill for 0 score */}
                  {riskScore > 0 && (
                    <div
                      className="h-full transition-all"
                      style={{
                        width: `${Math.min(riskScore, 100)}%`,
                        backgroundColor: riskScore < 15 ? '#10b981' : riskScore < 35 ? '#f59e0b' : riskScore < 60 ? '#f97316' : '#ef4444',
                      }}
                    />
                  )}
                </div>
              </div>

              {/* Legend - simplified */}
              <div className="flex items-center gap-4 text-xs text-gray-500 mb-3">
                <span>
                  Reports: <span className="text-emerald-600 font-medium">+{item.totalComplaints}</span>
                  <span className="text-gray-400"> ({reportRate.toFixed(1)}%)</span>
                </span>
                {item.avgRating > 0 && (
                  <span>
                    Rating: <span className="text-amber-500">★{item.avgRating.toFixed(1)}</span>
                  </span>
                )}
              </div>

              {/* Bottom Row: Categories + Actions */}
              <div className="flex items-center justify-between">
                {/* Category Tags */}
                <div className="flex flex-wrap gap-2">
                  {categories.length > 0 ? (
                    categories.map((cat) => (
                      <span
                        key={cat.reason}
                        className="text-xs px-3 py-1.5 bg-gray-50 border border-gray-200 rounded-full text-gray-600"
                      >
                        {cat.reason} ({cat.count})
                      </span>
                    ))
                  ) : (
                    <span className="text-xs text-gray-400 italic">No complaints</span>
                  )}
                </div>

                {/* Action Buttons */}
                <div className="flex items-center gap-2">
                  {severity.banRecommended && !suspended && (
                    <button
                      onClick={() => handleBan(item.id, activeTab === "restaurants" ? "restaurant" : "deliverer")}
                      className="flex items-center gap-2 px-3 py-1.5 bg-red-600 text-white text-sm rounded-lg font-medium hover:bg-red-700 transition-colors"
                    >
                      <FaBan />
                      Ban
                    </button>
                  )}
                  <button
                    onClick={() => {
                      setSelectedItem(item);
                      setIsModalOpen(true);
                    }}
                    className="flex items-center gap-2 px-3 py-1.5 border border-teal-600 text-teal-600 text-sm rounded-lg font-medium hover:bg-teal-50 transition-colors"
                  >
                    <FaEye />
                    View reclamations
                  </button>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {currentList.length === 0 && (
        <div className="text-center py-12 text-gray-500">
          <div className="text-4xl mb-3">📊</div>
          <p>No reports found</p>
        </div>
      )}

      {/* Reclamations Modal */}
      {isModalOpen && selectedItem && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl w-full max-w-2xl max-h-[80vh] overflow-hidden shadow-xl">
            {/* Modal Header */}
            <div className="flex items-center justify-between p-5 border-b border-gray-100">
              <div>
                <h2 className="text-xl font-semibold text-gray-900 flex items-center gap-2">
                  <span className="text-red-500">
                    <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                    </svg>
                  </span>
                  Reclamations — {isRestaurant(selectedItem) ? selectedItem.restaurantName : (selectedItem as any).delivererName}
                </h2>
                <p className="text-sm text-gray-500 mt-1">
                  {selectedItem.totalComplaints} reclamation{selectedItem.totalComplaints !== 1 ? 's' : ''} filed by clients. Optional descriptions are shown when provided.
                </p>
              </div>
              <button
                onClick={() => setIsModalOpen(false)}
                className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <svg className="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            {/* Modal Body */}
            <div className="p-5 overflow-y-auto max-h-[60vh] space-y-4">
              {(() => {
                const itemComplaints = data?.complaints?.filter((c) => {
                  if (isRestaurant(selectedItem)) {
                    return c.restaurantId === selectedItem.id;
                  } else {
                    return c.delivererId === selectedItem.id;
                  }
                }) || [];

                if (itemComplaints.length === 0) {
                  return (
                    <div className="text-center py-8 text-gray-500">
                      <p>No reclamations found for this {activeTab === "restaurants" ? "restaurant" : "deliverer"}.</p>
                    </div>
                  );
                }

                return itemComplaints.map((complaint) => (
                  <div key={complaint.id} className="bg-gray-50 rounded-xl p-4 border border-gray-100">
                    {/* Header Row */}
                    <div className="flex items-start justify-between mb-3">
                      <div className="flex items-center gap-3">
                        <h4 className="font-semibold text-gray-900">{complaint.reason}</h4>
                      </div>
                      <span className="text-sm text-gray-500 flex items-center gap-1">
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                        </svg>
                        {new Date(complaint.createdAt).toISOString().split('T')[0]}
                      </span>
                    </div>

                    {/* Description */}
                    {complaint.description ? (
                      <div className="flex gap-3 mb-3 pl-4 border-l-2 border-teal-200">
                        <svg className="w-5 h-5 text-gray-400 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z" />
                        </svg>
                        <p className="text-gray-600 italic">"{complaint.description}"</p>
                      </div>
                    ) : (
                      <p className="text-gray-400 italic mb-3 pl-4">No description provided by the client.</p>
                    )}

                    {/* Footer Row */}
                    <div className="flex items-center justify-between text-sm pt-2 border-t border-gray-200">
                      <div className="flex items-center gap-2 text-gray-600">
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                        </svg>
                        {complaint.complainantName || complaint.complainantEmail || "Anonymous"}
                      </div>
                      {complaint.orderCode || complaint.orderReference ? (
                        <span className="text-gray-500">
                          Order #{complaint.orderCode || complaint.orderReference}
                        </span>
                      ) : null}
                    </div>
                  </div>
                ));
              })()}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
