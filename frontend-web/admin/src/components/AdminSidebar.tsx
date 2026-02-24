import { FaUtensils, FaUsers, FaTruck, FaClipboardList, FaChartBar, FaSignOutAlt } from "react-icons/fa";

export default function AdminSidebar({ current, onNavigate }: { current: string, onNavigate: (page: string) => void }) {
  const menu = [
    { label: "Restaurants", icon: <FaUtensils />, key: "restaurants" },
    { label: "Clients", icon: <FaUsers />, key: "clients" },
    { label: "Deliverers", icon: <FaTruck />, key: "deliverers" },
    { label: "Orders", icon: <FaClipboardList />, key: "orders", disabled: true },
    { label: "Reports", icon: <FaChartBar />, key: "reports", disabled: true },
    { label: "AI Insights", icon: <FaChartBar />, key: "insights", disabled: true },
  ];
  return (
    <nav className="flex flex-col min-h-screen w-56 bg-gray-50 p-4 border-r">
      <div className="mb-10 text-xl font-bold">FiftyFood<br /><span className="text-xs font-normal">Admin Portal</span></div>
      <ul className="flex-1 space-y-4">
        {menu.map(item => (
          <li key={item.key}
              className={`
                flex items-center gap-3 px-3 py-2 rounded-lg cursor-pointer
                ${item.disabled ? "text-gray-400 cursor-not-allowed" : current === item.key ? "bg-green-100 text-green-700 font-semibold" : "text-gray-700"}
              `}
              onClick={() => !item.disabled && onNavigate(item.key)}>
            {item.icon}
            {item.label}
          </li>
        ))}
      </ul>
      <button className="mt-auto flex items-center gap-3 text-red-600 font-semibold hover:underline">
        <FaSignOutAlt /> Sign Out
      </button>
    </nav>
  );
}