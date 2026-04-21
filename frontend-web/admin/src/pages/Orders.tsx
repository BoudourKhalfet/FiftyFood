import React, { useEffect, useState } from "react";
import { fetchAllOrders } from "../api/admin";
import { OrderStatusBadge } from "../components/OrderStatusBadge";

type Order = {
  id: string;
  reference: string;
  userName: string;
  restaurantName: string;
  amount: number;
  method: string; // PICKUP/DELIVERY
  status: string;
  date: string;
  deliverer?: string;
};

const Orders: React.FC = () => {
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchAllOrders()
      .then((data) => {
        console.log("Fetched orders:", data);
        setOrders(data);
        setError(null);
      })
      .catch((err) => {
        console.error("Error fetching orders:", err);
        setError("Failed to load orders");
      })
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="p-12 bg-[#f8f8f6] min-h-screen">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Admin Dashboard</h1>
        <p className="text-lg text-gray-400">
          Platform governance and supervision
        </p>
      </div>
      {/* Section Title/Controls */}
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-semibold">Order Overview</h2>
        {/* If you want to add future search/filter, controls go here */}
      </div>
      <div className="bg-white rounded-2xl border shadow p-6">
        {/* Table */}
        <div style={{ overflowX: "auto" }}>
          <table className="w-full text-gray-800">
            <thead>
              <tr>
                <th className="py-3 text-left text-green-900 font-semibold">
                  Order ID
                </th>
                <th className="py-3 text-left text-green-900 font-semibold">
                  User
                </th>
                <th className="py-3 text-left text-green-900 font-semibold">
                  Restaurant
                </th>
                <th className="py-3 text-left text-green-900 font-semibold">
                  Amount
                </th>
                <th className="py-3 text-left text-green-900 font-semibold">
                  Method
                </th>
                <th className="py-3 text-left text-green-900 font-semibold">
                  Status
                </th>
                <th className="py-3 text-left text-green-900 font-semibold">
                  Date
                </th>
                <th className="py-3 text-left text-green-900 font-semibold">
                  Deliverer
                </th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={8} className="text-center text-gray-400 py-10">
                    Loading...
                  </td>
                </tr>
              ) : error ? (
                <tr>
                  <td colSpan={8} className="text-center text-red-500 py-10">
                    {error}
                  </td>
                </tr>
              ) : orders.length === 0 ? (
                <tr>
                  <td colSpan={8} className="text-center text-gray-400 py-10">
                    No orders.
                  </td>
                </tr>
              ) : (
                orders.map((order) => (
                  <tr
                    key={order.id}
                    className="border-b last:border-b-0 hover:bg-gray-50"
                  >
                    <td className="py-3 font-semibold">
                      {order.reference || order.id}
                    </td>
                    <td className="py-3">{order.userName}</td>
                    <td className="py-3">{order.restaurantName}</td>
                    <td className="py-3">€{order.amount?.toFixed(2)}</td>
                    <td className="py-3">
                      <span className="inline-block bg-gray-100 rounded px-2 py-1 text-xs font-semibold text-gray-500">
                        {(order.method || "").toLowerCase()}
                      </span>
                    </td>
                    <td className="py-3">
                      <OrderStatusBadge status={order.status} />
                    </td>
                    <td className="py-3">{order.date?.slice(0, 10)}</td>
                    <td className="py-3">
                      {(order.method === "DELIVERY" ||
                        order.method === "delivery") &&
                      order.deliverer
                        ? order.deliverer
                        : "—"}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

export default Orders;
