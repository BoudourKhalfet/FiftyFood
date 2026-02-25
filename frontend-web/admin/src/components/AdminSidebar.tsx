import { FaUtensils, FaUsers, FaTruck, FaClipboardList, FaChartBar, FaRegChartBar, FaSignOutAlt, FaCog, FaLeaf } from "react-icons/fa";
import { Link } from "react-router-dom";
interface SidebarProps {
  current: string;
  onNavigate: (key: string) => void;
}

const menu = [
  { label: "Overview", key: "overview", icon: <FaChartBar /> },
  { label: "Restaurants", key: "restaurants", icon: <FaUtensils />, badge: 12 },
  { label: "Clients", key: "clients", icon: <FaUsers /> },
  { label: "Deliverers", key: "deliverers", icon: <FaTruck /> },
  { label: "Orders", key: "orders", icon: <FaClipboardList />, disabled: true },
  { label: "Reports", key: "reports", icon: <FaRegChartBar />, badge: 3 },
  { label: "AI Insights", key: "insights", icon: <FaRegChartBar /> },
];

export default function AdminSidebar({ current, onNavigate }: SidebarProps) {
  return (
    <nav className="flex flex-col min-h-screen w-64 bg-[#f7fafd] border-r border-gray-200 py-6 px-4">
      {/* Logo & Header */}
      <div className="flex items-center mb-10 gap-3">
      <Link to="/" className="flex items-center gap-3 mb-1">
  {/* Gradient rounded square with FaLeaf icon */}
  <div className="w-12 h-12 rounded-xl flex items-center justify-center bg-gradient-to-br from-[#16807a] to-[#2db080]">
    <FaLeaf className="w-7 h-7 text-white" />
  </div>
  <div>
    <span className="text-2xl font-extrabold tracking-tight leading-tight">
      <span className="text-[#212929]">Fifty</span>
      <span className="text-[#277262]">Food</span>
    </span>
    <div className="text-sm text-gray-400">Admin Portal</div>
  </div>
</Link>
      </div>
      {/* Navigation */}
      <ul className="flex-1 space-y-2">
        {menu.map(item => (
          <li
            key={item.key}
            className={`flex items-center gap-3 px-4 py-2 rounded-lg cursor-pointer relative transition
              ${item.disabled
                ? "text-gray-400 cursor-not-allowed"
                : current === item.key
                ? "bg-[#16807a] text-white font-semibold"
                : "text-gray-700 hover:bg-[#e6f8f6]"
              }`}
            onClick={() => !item.disabled && onNavigate(item.key)}
          >
            {item.icon}
            <span>{item.label}</span>
            {item.badge != null && (
              <span className={`ml-auto text-xs font-bold px-2 py-0.5 rounded-full
                ${current === item.key ? "bg-white text-[#16807a]" : "bg-[#e2f6ee] text-[#16807a]"}`}>
                {item.badge}
              </span>
            )}
          </li>
        ))}
      </ul>
      <button
  className="flex items-center gap-3 text-gray-500 font-medium hover:text-[#16807a] focus:outline-none pt-8 text-sm"
  style={{ background: "none", border: "none" }}
>
  <FaCog className="w-4 h-4" />
  <span>Settings</span>
</button>
      <button className="mt-4 flex items-center gap-3 text-red-600 font-semibold hover:underline">
        <FaSignOutAlt /> <span>Sign Out</span>
      </button>
    </nav>
  );
}