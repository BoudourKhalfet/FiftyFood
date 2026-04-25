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
        setOrders(data);
        setError(null);
      })
      .catch((err) => {
        setError(err instanceof Error ? err.message : "Failed to fetch orders");
      })
      .finally(() => setLoading(false));
  }, []);

  const normalizedQuery = searchQuery.trim().toLowerCase();
  const filteredOrders = orders.filter((order) => {
    if (!normalizedQuery) return true;

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
      {/* Section Title/Controls */}
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-semibold">Order Overview</h2>
        {/* If you want to add future search/filter, controls go here */}
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
        {/* Table */}
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
                    className="border-b border-gray-100 last:border-b-0 hover:bg-[#f3fbfa] transition-colors"
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
                    <td className="py-3 px-3">{order.date?.slice(0, 10)}</td>
                    <td className="py-3 px-3">
                      <button
                        type="button"
                        className="bg-[#0f766e] hover:bg-[#0c5d57] text-white text-xs font-semibold px-3 py-2 rounded-lg transition-colors shadow-sm"
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
        <div className="fixed inset-0 z-50 bg-black/35 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-xl w-full max-w-xl overflow-hidden">
            <div className="px-6 py-4 flex items-center justify-between border-b border-[#e6efed]">
              <h3 className="text-xl font-bold text-[#0f766e]">
                Order Details
              </h3>
              <button
                type="button"
                onClick={() => setSelectedOrder(null)}
                className="text-gray-500 hover:text-gray-800 text-sm font-semibold"
              >
                Close
              </button>
            </div>

            <div className="p-6 grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
              <DetailItem
                label="Order Code"
                value={
                  selectedOrder.orderDisplayCode ||
                  selectedOrder.orderCode ||
                  "—"
                }
              />
              <DetailItem
                label="Client"
                value={selectedOrder.userName || "—"}
              />
              <DetailItem
                label="Restaurant"
                value={selectedOrder.restaurantName || "—"}
              />
              <DetailItem
                label="Amount"
                value={
                  typeof selectedOrder.amount === "number"
                    ? `€${selectedOrder.amount.toFixed(2)}`
                    : "—"
                }
              />
              <DetailItem
                label="Method"
                value={selectedOrder.method || "—"}
                badgeClassName="bg-cyan-100 text-cyan-800"
              />
              <DetailItem
                label="Status"
                value={<OrderStatusBadge status={selectedOrder.status || ""} />}
              />
              <DetailItem
                label="Date"
                value={selectedOrder.date?.slice(0, 10) || "—"}
              />
              <DetailItem
                label="Deliverer"
                value={
                  (selectedOrder.method === "DELIVERY" ||
                    selectedOrder.method === "delivery") &&
                  selectedOrder.deliverer
                    ? selectedOrder.deliverer
                    : "—"
                }
              />
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

type DetailItemProps = {
  label: string;
  value: React.ReactNode;
  badgeClassName?: string;
};

const DetailItem: React.FC<DetailItemProps> = ({
  label,
  value,
  badgeClassName,
}) => {
  return (
    <div className="bg-[#f7faf9] border border-[#e2efed] rounded-lg px-3 py-2">
      <p className="text-xs text-gray-500 mb-1">{label}</p>
      {badgeClassName ? (
        <span
          className={`inline-flex rounded-full px-2.5 py-1 text-xs font-semibold ${badgeClassName}`}
        >
          {value}
        </span>
      ) : (
        <p className="text-sm font-semibold text-gray-900 break-words">
          {value}
        </p>
      )}
    </div>
  );
};

export default Orders;
