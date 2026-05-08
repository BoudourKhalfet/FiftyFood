import { useEffect, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { FaArrowLeft } from "react-icons/fa";

type DelivererData = {
  delivererName: string;
  totalEarnings: number;
  orders: Array<{
    id: string;
    orderCode: string;
    restaurantName: string;
    customerName: string;
    date: string;
    amount: number;  // Order total
    delivererFee: number;  // Platform fee
    total: number;
    rating: number | null;
    status: string;
    deliveryAddress: string;
  }>;
};

export default function DelivererDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [data, setData] = useState<DelivererData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function fetchDelivererOrders() {
      setLoading(true);
      try {
        const token = localStorage.getItem("access_token");
        const resp = await fetch(`/admin/livreurs/${id}/orders`, {
          headers: {
            Authorization: "Bearer " + token,
          },
        });
        if (!resp.ok) {
          throw new Error(`Failed to fetch deliverer orders: ${resp.status}`);
        }
        const result = await resp.json();
        setData(result);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Failed to load data");
      } finally {
        setLoading(false);
      }
    }
    if (id) fetchDelivererOrders();
  }, [id]);

  if (loading) return <div className="p-8">Loading...</div>;
  if (error) return <div className="p-8 text-red-600">Error: {error}</div>;
  if (!data) return <div className="p-8">No data found</div>;

  // Calculate total earnings - should match backend (sum of all amounts)
  const totalRevenue = data.orders.reduce((sum, order) => {
    return sum + (order.amount || 0);
  }, 0);

  return (
    <div className="p-8 bg-gray-100 min-h-screen">
      <button
        onClick={() => navigate("/admin")}
        className="flex items-center gap-2 mb-6 text-blue-600 hover:text-blue-800"
      >
        <FaArrowLeft /> Back
      </button>

      <h1 className="text-3xl font-bold mb-6">{data.delivererName}</h1>

      {/* Total Earnings Card - SAME as mobile app */}
      <div className="bg-gradient-to-r from-green-500 to-green-600 rounded-2xl p-8 mb-8 text-white shadow-lg">
        <div className="text-sm font-semibold opacity-90">Total Revenue</div>
        <div className="text-4xl font-bold mt-2">€{totalRevenue.toFixed(2)}</div>
        <div className="text-sm opacity-90 mt-2">{data.orders.length} transaction{data.orders.length !== 1 ? 's' : ''}</div>
      </div>

      {/* Transaction Cards - SAME as mobile app */}
      <div className="space-y-4">
        {data.orders.map((order) => {
          const amount = order.amount || 0;  // Order total
          const fee = order.delivererFee || 0;  // Platform fee  
          const earnings = amount - fee;  // Deliverer earnings

          return (
            <div
              key={order.id}
              className="bg-white rounded-xl p-4 shadow-sm border border-gray-200 hover:shadow-md transition"
            >
              {/* Header Row - EXACT same as mobile */}
              <div className="flex justify-between items-start mb-3">
                <div>
                  <div className="font-bold text-gray-900">Order #{order.orderCode}</div>
                  <div className="text-sm text-gray-500 mt-1">
                    {new Date(order.date).toLocaleDateString()}
                  </div>
                </div>
                <div className="text-right">
                  <div className="font-bold text-lg text-green-600">
                    +€{earnings.toFixed(2)}
                  </div>
                </div>
              </div>

              {/* Restaurant & Client Info */}
              <div className="text-sm text-gray-600 space-y-1 mb-3">
                <div>Restaurant: {order.restaurantName}</div>
                <div>Client: {order.customerName}</div>
              </div>

              {/* Breakdown Section - EXACT same as mobile */}
              <div className="bg-gray-50 rounded-lg p-3 space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-gray-600">Total:</span>
                  <span className="font-semibold">€{amount.toFixed(2)}</span>
                </div>
                <div className="flex justify-between border-t border-gray-200 pt-2">
                  <span className="text-gray-600">Delivery fee:</span>
                  <span className="font-semibold">-€{fee.toFixed(2)}</span>
                </div>
                <div className="flex justify-between pt-1">
                  <span className="text-gray-600">Your amount:</span>
                  <span className="font-semibold text-green-600">€{earnings.toFixed(2)}</span>
                </div>
                <div className="flex justify-between pt-1">
                  <span className="text-gray-600">Status:</span>
                  <span>
                    <span className={`px-2 py-1 rounded-full text-xs font-semibold ${
                      order.status === 'DELIVERED' || order.status === 'PICKED_UP'
                        ? 'bg-green-100 text-green-800'
                        : 'bg-yellow-100 text-yellow-800'
                    }`}>
                      {order.status}
                    </span>
                  </span>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
