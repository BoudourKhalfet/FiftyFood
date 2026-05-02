import React, { useEffect, useState } from "react";
import { fetchAllOrders } from "../api/admin";
import { OrderStatusBadge } from "../components/OrderStatusBadge";

type Order = {
  id: string;
  reference: string;
  userName: string;
  restaurantName: string;
  amount: number;
  method: string;
  status: string;
  date: string;
  deliverer?: string;
  orderCode?: string;
  orderDisplayCode?: string;
  offerTitle?: string;
};

const Orders: React.FC = () => {
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedOrder, setSelectedOrder] = useState<Order | null>(null);
  const [searchQuery, setSearchQuery] = useState("");

  useEffect(() => {
    fetchAllOrders()
      .then((data) => {
        console.log("Fetched orders:", data);
        setOrders(data);
      })
      .catch((err) => {
        setError(err instanceof Error ? err.message : "Failed to fetch orders");
      })
      .finally(() => {
        setLoading(false);
      });
  }, []);

  const normalizedQuery = searchQuery.toLowerCase();

  const filteredOrders = orders.filter((order) => {
    const searchable = [
      order.orderDisplayCode,
      order.orderCode,
      order.deliverer,
      order.restaurantName,
      order.userName,
      order.status,
    ]
      .filter(Boolean)
      .join(" ")
      .toLowerCase();

    return searchable.includes(normalizedQuery);
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
        <h2 className="text-xl font-semibold">Order Overview</h2>
      </div>

      <div className="mb-4 flex justify-end">
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="Search by code, deliverer, restaurant, client, or status"
          className="w-full max-w-md rounded-xl border border-[#cfe3e0] bg-[#f8fcfb] px-4 py-2.5 text-sm text-gray-800 outline-none focus:border-[#0f766e] focus:ring-2 focus:ring-[#bde3dc]"
        />
      </div>

      <div className="bg-white rounded-2xl border border-[#d9ebe9] shadow p-6">
        <div style={{ overflowX: "auto" }}>
          <table className="w-full text-gray-800">
            <thead className="bg-[#eff9f7]">
              <tr>
                <th className="py-3 px-3 text-left text-green-900 font-semibold rounded-l-lg">
                  Order Code
                </th>
                <th className="py-3 px-3 text-left text-green-900 font-semibold">
                  Client
                </th>
                <th className="py-3 px-3 text-left text-green-900 font-semibold">
                  Amount
                </th>
                <th className="py-3 px-3 text-left text-green-900 font-semibold">
                  Status
                </th>
                <th className="py-3 px-3 text-left text-green-900 font-semibold">
                  Date
                </th>
                <th className="py-3 px-3 text-left text-green-900 font-semibold rounded-r-lg">
                  Action
                </th>
              </tr>
            </thead>

            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={6} className="text-center text-gray-400 py-10">
                    Loading...
                  </td>
                </tr>
              ) : error ? (
                <tr>
                  <td colSpan={6} className="text-center text-red-500 py-10">
                    {error}
                  </td>
                </tr>
              ) : filteredOrders.length === 0 ? (
                <tr>
                  <td colSpan={6} className="text-center text-gray-400 py-10">
                    No orders match your search.
                  </td>
                </tr>
              ) : (
                filteredOrders.map((order) => (
                  <tr
                    key={order.id}
                    className="border-b border-gray-100 hover:bg-[#f3fbfa]"
                  >
                    <td className="py-3 px-3 font-semibold text-[#0f5f5b]">
                      {order.orderDisplayCode || order.orderCode || "—"}
                    </td>
                    <td className="py-3 px-3">{order.userName}</td>
                    <td className="py-3 px-3 font-semibold text-[#155e75]">
                      €{order.amount?.toFixed(2)}
                    </td>
                    <td className="py-3 px-3">
                      <OrderStatusBadge status={order.status} />
                    </td>
                    <td className="py-3 px-3">
                      {order.date?.slice(0, 10)}
                    </td>
                    <td className="py-3 px-3">
                      <button
                        className="bg-[#0f766e] hover:bg-[#0c5d57] text-white text-xs px-3 py-2 rounded-lg"
                        onClick={() => setSelectedOrder(order)}
                      >
                        View
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {selectedOrder && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl w-full max-w-lg shadow-xl overflow-hidden">
            {/* Modal Header */}
            <div className="flex items-center justify-between p-5 border-b border-gray-100">
              <div>
                <h3 className="text-xl font-semibold text-gray-900">
                  Order #{selectedOrder.orderDisplayCode || selectedOrder.orderCode || selectedOrder.id.slice(0, 8)}
                </h3>
                <p className="text-sm text-gray-500 mt-1">
                  Placed on {new Date(selectedOrder.date).toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}
                </p>
              </div>
              <button
                onClick={() => setSelectedOrder(null)}
                className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <svg className="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            {/* Modal Body */}
            <div className="p-5 space-y-4">
              {/* Status Badge */}
              <div className="flex items-center justify-between bg-gray-50 rounded-lg p-3">
                <span className="text-sm text-gray-600">Status</span>
                <OrderStatusBadge status={selectedOrder.status} />
              </div>

              {/* Info Grid */}
              <div className="grid grid-cols-2 gap-4">
                <div className="bg-gray-50 rounded-lg p-3">
                  <p className="text-xs text-gray-500 mb-1">Client</p>
                  <p className="font-medium text-gray-900">{selectedOrder.userName}</p>
                </div>
                <div className="bg-gray-50 rounded-lg p-3">
                  <p className="text-xs text-gray-500 mb-1">Restaurant</p>
                  <p className="font-medium text-gray-900">{selectedOrder.restaurantName}</p>
                </div>
                <div className="bg-gray-50 rounded-lg p-3">
                  <p className="text-xs text-gray-500 mb-1">Amount</p>
                  <p className="font-medium text-teal-700">€{selectedOrder.amount?.toFixed(2)}</p>
                </div>
                <div className="bg-gray-50 rounded-lg p-3">
                  <p className="text-xs text-gray-500 mb-1">Payment Method</p>
                  <p className="font-medium text-gray-900">{selectedOrder.method || "—"}</p>
                </div>
              </div>

              {selectedOrder.deliverer && (
                <div className="bg-gray-50 rounded-lg p-3">
                  <p className="text-xs text-gray-500 mb-1">Deliverer</p>
                  <p className="font-medium text-gray-900">{selectedOrder.deliverer}</p>
                </div>
              )}
            </div>

            {/* Modal Footer */}
            <div className="flex items-center justify-end gap-3 p-5 border-t border-gray-100 bg-gray-50">
              <button
                onClick={() => setSelectedOrder(null)}
                className="px-4 py-2 text-gray-700 hover:bg-gray-200 rounded-lg transition-colors font-medium"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Orders;