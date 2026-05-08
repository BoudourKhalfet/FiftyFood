import { useEffect, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { FaArrowLeft } from "react-icons/fa";

type RestaurantData = {
  restaurantName: string;
  totalRevenue: number;
  orders: Array<{
    id: string;
    orderCode: string;
    total: number;
    deliveryFee: number;
    status: string;
    createdAt: string;
    customerName: string;
    rating: number | null;
  }>;
};

export default function RestaurantDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [data, setData] = useState<RestaurantData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function fetchRestaurantOrders() {
      setLoading(true);
      try {
        const token = localStorage.getItem("access_token");
        const resp = await fetch(`/admin/restaurants/${id}/orders`, {
          headers: {
            Authorization: "Bearer " + token,
          },
        });
        if (!resp.ok) {
          throw new Error(`Failed to fetch restaurant orders: ${resp.status}`);
        }
        const result = await resp.json();
        setData(result);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Failed to load data");
      } finally {
        setLoading(false);
      }
    }
    if (id) fetchRestaurantOrders();
  }, [id]);

  if (loading) return <div className="p-8">Loading...</div>;
  if (error) return <div className="p-8 text-red-600">Error: {error}</div>;
  if (!data) return <div className="p-8">No data found</div>;

  return (
    <div className="p-8 bg-gray-100 min-h-screen">
      <button
        onClick={() => navigate("/admin")}
        className="flex items-center gap-2 mb-6 text-blue-600 hover:text-blue-800"
      >
        <FaArrowLeft /> Back
      </button>

      <h1 className="text-3xl font-bold mb-6">{data.restaurantName}</h1>

      {/* Total Revenue Card - SAME as mobile */}
      <div className="bg-gradient-to-r from-green-500 to-green-600 rounded-2xl p-8 mb-8 text-white shadow-lg">
        <div className="text-sm font-semibold opacity-90">Total Revenue</div>
        <div className="text-4xl font-bold mt-2">€{data.totalRevenue.toFixed(2)}</div>
        <div className="text-sm opacity-90 mt-2">{data.orders.length} order{data.orders.length !== 1 ? 's' : ''}</div>
      </div>

      {/* Transaction Cards */}
      <div className="space-y-4">
        {data.orders.map((order) => (
          <div
            key={order.id}
            className="bg-white rounded-xl p-4 shadow-sm border border-gray-200 hover:shadow-md transition"
          >
            {/* Header Row */}
            <div className="flex justify-between items-start mb-3">
              <div>
                <div className="font-bold text-gray-900">Order #{order.orderCode}</div>
                <div className="text-sm text-gray-500 mt-1">
                  {new Date(order.createdAt).toLocaleDateString()}
                </div>
              </div>
              <div className="text-right">
                <div className="font-bold text-lg text-green-600">€{order.total.toFixed(2)}</div>
              </div>
            </div>

            {/* Client Info */}
            <div className="text-sm text-gray-600 mb-3">Client: {order.customerName}</div>

            {/* Breakdown Section */}
            <div className="bg-gray-50 rounded-lg p-3 space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-gray-600">Order Total:</span>
                <span className="font-semibold">€{order.total.toFixed(2)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-600">Status:</span>
                <span className={`px-2 py-1 rounded-full text-xs font-semibold ${
                  order.status === 'DELIVERED' || order.status === 'PICKED_UP'
                    ? 'bg-green-100 text-green-800'
                    : 'bg-yellow-100 text-yellow-800'
                }`}>
                  {order.status}
                </span>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
