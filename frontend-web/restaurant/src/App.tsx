import { useEffect, useMemo, useState } from "react";
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  ComposedChart,
  Line,
  LineChart,
  Pie,
  PieChart,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
  Legend,
} from "recharts";
import {
  TrendingUp,
  TrendingDown,
  Euro,
  Package,
  Leaf,
  Star,
  Clock,
  Users,
  Lightbulb,
  AlertTriangle,
  Sparkles,
  Target,
  Calendar,
  ChefHat,
  Truck,
  Store,
  Brain,
  Activity,
  CheckCircle2,
} from "lucide-react";

import {
  generateDailyHistory,
  generateOfferHistory,
  generateHourlyHistory,
} from "./lib/restaurant/mockHistory";
import { trainAndForecast, type Forecast } from "./lib/restaurant/forecaster";
import { generateTips, type RestaurantTip } from "./lib/restaurant/tipsEngine";

const DAYS_SHORT = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

const methodSplit = [
  { name: "Pickup", value: 68, color: "#16807a" },
  { name: "Delivery", value: 32, color: "#f59e0b" },
];

const ratingsBreakdown = [
  { stars: "5★", count: 142 },
  { stars: "4★", count: 58 },
  { stars: "3★", count: 14 },
  { stars: "2★", count: 4 },
  { stars: "1★", count: 2 },
];

function Card({
  children,
  className = "",
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={`rounded-2xl border border-[#d9e4df] bg-white shadow-[0_1px_2px_rgba(15,23,42,0.06)] ${className}`}
    >
      {children}
    </div>
  );
}

function Badge({
  children,
  className = "",
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <span
      className={`inline-flex items-center rounded-full border px-2.5 py-1 text-xs font-semibold ${className}`}
    >
      {children}
    </span>
  );
}

function Progress({ value }: { value: number }) {
  return (
    <div className="h-2.5 w-full overflow-hidden rounded-full bg-slate-100">
      <div
        className="h-full rounded-full bg-[#16807a] transition-all duration-300"
        style={{ width: `${Math.max(0, Math.min(100, value))}%` }}
      />
    </div>
  );
}

function KpiCard({
  icon: Icon,
  label,
  value,
  change,
  trend,
  tone = "primary",
}: {
  icon: React.ElementType;
  label: string;
  value: string;
  change: string;
  trend: "up" | "down";
  tone?: "primary" | "success" | "warning" | "secondary";
}) {
  const toneMap: Record<string, string> = {
    primary: "bg-[#e8f7f3] text-[#16807a]",
    success: "bg-[#ecfdf3] text-[#16a34a]",
    warning: "bg-[#fff7e9] text-[#f59e0b]",
    secondary: "bg-[#f5f3ff] text-[#7c3aed]",
  };

  return (
    <Card>
      <div className="space-y-3 p-4">
        <div className="flex items-start justify-between">
          <div
            className={`flex h-10 w-10 items-center justify-center rounded-xl ${toneMap[tone]}`}
          >
            <Icon className="h-5 w-5" />
          </div>
          <Badge
            className={
              trend === "up"
                ? "border-emerald-300 text-emerald-600"
                : "border-red-300 text-red-600"
            }
          >
            {trend === "up" ? (
              <TrendingUp className="mr-1 h-3 w-3" />
            ) : (
              <TrendingDown className="mr-1 h-3 w-3" />
            )}
            {change}
          </Badge>
        </div>
        <div>
          <p className="text-2xl font-bold text-slate-900">{value}</p>
          <p className="text-xs text-slate-500">{label}</p>
        </div>
      </div>
    </Card>
  );
}

export default function App() {
  const daily = useMemo(() => generateDailyHistory(60), []);
  const offers = useMemo(() => generateOfferHistory(), []);
  const hourly = useMemo(() => generateHourlyHistory(), []);

  const last7 = daily.slice(-7);
  const weeklyChartData = last7.map((d) => ({
    day: DAYS_SHORT[d.dayOfWeek],
    revenue: d.revenue,
    orders: d.orders,
  }));

  const monthlyTrend = useMemo(() => {
    const byMonth: Record<string, { revenue: number; meals: number }> = {};

    for (const d of daily) {
      const month = d.date.substring(0, 7);
      if (!byMonth[month]) {
        byMonth[month] = { revenue: 0, meals: 0 };
      }
      byMonth[month].revenue += d.revenue;
      byMonth[month].meals += d.mealsSaved;
    }

    return Object.entries(byMonth)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([month, value]) => ({
        month: new Date(`${month}-01`).toLocaleDateString("en", {
          month: "short",
        }),
        revenue: value.revenue,
        meals: value.meals,
      }));
  }, [daily]);

  const offerPerformance = offers.map((o) => ({
    name: o.name,
    sold: o.sold,
    total: o.total,
  }));

  const [loading, setLoading] = useState(true);
  const [forecasts, setForecasts] = useState<Forecast[]>([]);
  const [tips, setTips] = useState<RestaurantTip[]>([]);
  const [trainedOnDays, setTrainedOnDays] = useState(0);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);

    (async () => {
      try {
        const result = await trainAndForecast(daily, 7, 60);
        if (cancelled) return;

        setForecasts(result.forecasts);
        setTrainedOnDays(result.trainedOnDays);
        setTips(
          generateTips({
            daily,
            offers,
            hourly,
            forecasts: result.forecasts,
          }),
        );
      } catch (error) {
        if (cancelled) return;
        console.error("Forecast training failed:", error);
        setTips(generateTips({ daily, offers, hourly, forecasts: [] }));
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [daily, offers, hourly]);

  const totalRevenue = last7.reduce((sum, d) => sum + d.revenue, 0);
  const totalOrders = last7.reduce((sum, d) => sum + d.orders, 0);
  const totalMeals = last7.reduce((sum, d) => sum + d.mealsSaved, 0);

  const forecastChartData = [
    ...last7.map((d) => ({
      label: DAYS_SHORT[d.dayOfWeek],
      actual: d.revenue,
      predicted: null as number | null,
      lower: null as number | null,
      upper: null as number | null,
    })),
    ...forecasts.map((f) => ({
      label: DAYS_SHORT[f.dayOfWeek],
      actual: null as number | null,
      predicted: f.predictedRevenue,
      lower: f.lower,
      upper: f.upper,
    })),
  ];

  const avgConfidence =
    forecasts.length > 0
      ? forecasts.reduce((sum, f) => sum + f.confidence, 0) / forecasts.length
      : 0;

  return (
    <main className="min-h-screen bg-[#f8faf9] px-4 py-6 md:px-8 lg:px-10">
      <div className="mx-auto w-full max-w-[1500px] space-y-6">
        <div>
          <h2 className="text-lg font-semibold text-slate-900">Overview</h2>
          <p className="text-sm text-slate-600">
            Performance, ML forecasts, and statistics-driven tips
          </p>
        </div>

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <KpiCard
            icon={Euro}
            label="Revenue (7d)"
            value={`€${totalRevenue}`}
            change="+12.4%"
            trend="up"
            tone="primary"
          />
          <KpiCard
            icon={Package}
            label="Orders (7d)"
            value={`${totalOrders}`}
            change="+8.1%"
            trend="up"
            tone="secondary"
          />
          <KpiCard
            icon={Leaf}
            label="Meals saved"
            value={`${totalMeals}`}
            change="+15.2%"
            trend="up"
            tone="success"
          />
          <KpiCard
            icon={Star}
            label="Avg rating"
            value="4.7"
            change="-0.1"
            trend="down"
            tone="warning"
          />
        </div>

        <Card className="border-[#b9dfd8]">
          <div className="space-y-4 p-5">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <h3 className="flex items-center gap-2 text-base font-semibold text-slate-900">
                  <Brain className="h-5 w-5 text-[#16807a]" />
                  Next 7 days forecast
                </h3>
                <p className="text-sm text-slate-600">
                  In-browser model trained on {trainedOnDays} days of your
                  history
                </p>
              </div>
              {!loading && forecasts.length > 0 && (
                <Badge className="border-[#b8d8d0] text-slate-700">
                  <Activity className="mr-1 h-3 w-3" />
                  Confidence {(avgConfidence * 100).toFixed(0)}%
                </Badge>
              )}
            </div>

            {loading ? (
              <div className="h-[280px] animate-pulse rounded-xl bg-slate-100" />
            ) : (
              <ResponsiveContainer width="100%" height={280}>
                <ComposedChart data={forecastChartData}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#d9e4df" />
                  <XAxis dataKey="label" stroke="#64748b" fontSize={12} />
                  <YAxis stroke="#64748b" fontSize={12} />
                  <Tooltip />
                  <Legend />
                  <ReferenceLine
                    x={DAYS_SHORT[last7[last7.length - 1].dayOfWeek]}
                    stroke="#cbd5e1"
                    strokeDasharray="3 3"
                    label={{ value: "Today", fill: "#64748b", fontSize: 11 }}
                  />
                  <Area
                    type="monotone"
                    dataKey="upper"
                    stroke="transparent"
                    fill="#d2f2eb"
                    name="Confidence band"
                  />
                  <Area
                    type="monotone"
                    dataKey="lower"
                    stroke="transparent"
                    fill="#ffffff"
                    legendType="none"
                  />
                  <Line
                    type="monotone"
                    dataKey="actual"
                    stroke="#f59e0b"
                    strokeWidth={2.5}
                    name="Actual"
                    dot={{ r: 4 }}
                    connectNulls={false}
                  />
                  <Line
                    type="monotone"
                    dataKey="predicted"
                    stroke="#16807a"
                    strokeWidth={2.5}
                    strokeDasharray="6 4"
                    name="Predicted"
                    dot={{ r: 4 }}
                    connectNulls={false}
                  />
                </ComposedChart>
              </ResponsiveContainer>
            )}
          </div>
        </Card>

        <Card>
          <div className="space-y-4 p-5">
            <div>
              <h3 className="flex items-center gap-2 text-base font-semibold text-slate-900">
                <Calendar className="h-5 w-5 text-[#16807a]" />
                Weekly performance
              </h3>
              <p className="text-sm text-slate-600">
                Revenue and orders over the last 7 days
              </p>
            </div>

            <ResponsiveContainer width="100%" height={280}>
              <AreaChart data={weeklyChartData}>
                <defs>
                  <linearGradient id="revGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#16807a" stopOpacity={0.4} />
                    <stop offset="100%" stopColor="#16807a" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#d9e4df" />
                <XAxis dataKey="day" stroke="#64748b" fontSize={12} />
                <YAxis stroke="#64748b" fontSize={12} />
                <Tooltip />
                <Legend />
                <Area
                  type="monotone"
                  dataKey="revenue"
                  stroke="#16807a"
                  fill="url(#revGrad)"
                  strokeWidth={2}
                  name="Revenue (€)"
                />
                <Area
                  type="monotone"
                  dataKey="orders"
                  stroke="#f59e0b"
                  fill="transparent"
                  strokeWidth={2}
                  name="Orders"
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </Card>

        <div className="grid gap-6 lg:grid-cols-2">
          <Card>
            <div className="space-y-4 p-5">
              <div>
                <h3 className="flex items-center gap-2 text-base font-semibold text-slate-900">
                  <TrendingUp className="h-5 w-5 text-emerald-600" />
                  Monthly history
                </h3>
                <p className="text-sm text-slate-600">
                  Revenue and meals saved trend
                </p>
              </div>
              <ResponsiveContainer width="100%" height={240}>
                <LineChart data={monthlyTrend}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#d9e4df" />
                  <XAxis dataKey="month" stroke="#64748b" fontSize={12} />
                  <YAxis stroke="#64748b" fontSize={12} />
                  <Tooltip />
                  <Legend />
                  <Line
                    type="monotone"
                    dataKey="revenue"
                    stroke="#16807a"
                    strokeWidth={2}
                    name="Revenue (€)"
                    dot={{ r: 4 }}
                  />
                  <Line
                    type="monotone"
                    dataKey="meals"
                    stroke="#16a34a"
                    strokeWidth={2}
                    name="Meals saved"
                    dot={{ r: 4 }}
                  />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </Card>

          <Card>
            <div className="space-y-4 p-5">
              <div>
                <h3 className="flex items-center gap-2 text-base font-semibold text-slate-900">
                  <Clock className="h-5 w-5 text-amber-600" />
                  Pickups per hour
                </h3>
                <p className="text-sm text-slate-600">
                  When customers come to collect
                </p>
              </div>
              <ResponsiveContainer width="100%" height={240}>
                <BarChart
                  data={hourly.map((h) => ({
                    hour: `${h.hour}h`,
                    pickups: h.pickups,
                  }))}
                >
                  <CartesianGrid strokeDasharray="3 3" stroke="#d9e4df" />
                  <XAxis dataKey="hour" stroke="#64748b" fontSize={12} />
                  <YAxis stroke="#64748b" fontSize={12} />
                  <Tooltip />
                  <Bar dataKey="pickups" radius={[8, 8, 0, 0]}>
                    {hourly.map((entry, i) => (
                      <Cell
                        key={i}
                        fill={entry.pickups > 20 ? "#16807a" : "#9ca3af"}
                      />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
          </Card>

          <Card>
            <div className="space-y-4 p-5">
              <div>
                <h3 className="flex items-center gap-2 text-base font-semibold text-slate-900">
                  <Truck className="h-5 w-5 text-[#f59e0b]" />
                  Pickup vs Delivery
                </h3>
                <p className="text-sm text-slate-600">
                  Order method distribution
                </p>
              </div>

              <div className="flex items-center gap-6">
                <ResponsiveContainer width="50%" height={180}>
                  <PieChart>
                    <Pie
                      data={methodSplit}
                      cx="50%"
                      cy="50%"
                      innerRadius={45}
                      outerRadius={75}
                      paddingAngle={4}
                      dataKey="value"
                    >
                      {methodSplit.map((e, i) => (
                        <Cell key={i} fill={e.color} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>

                <div className="flex-1 space-y-3">
                  {methodSplit.map((m) => (
                    <div key={m.name} className="space-y-1">
                      <div className="flex justify-between text-sm">
                        <span className="flex items-center gap-2">
                          {m.name === "Pickup" ? (
                            <Store className="h-4 w-4 text-[#16807a]" />
                          ) : (
                            <Truck className="h-4 w-4 text-[#f59e0b]" />
                          )}
                          {m.name}
                        </span>
                        <span className="font-semibold">{m.value}%</span>
                      </div>
                      <Progress value={m.value} />
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </Card>

          <Card>
            <div className="space-y-4 p-5">
              <div>
                <h3 className="flex items-center gap-2 text-base font-semibold text-slate-900">
                  <Target className="h-5 w-5 text-[#16807a]" />
                  Offer performance
                </h3>
                <p className="text-sm text-slate-600">
                  Sell-through rate per offer
                </p>
              </div>

              <div className="space-y-4">
                {offerPerformance.map((o) => {
                  const pct = Math.round((o.sold / o.total) * 100);
                  return (
                    <div key={o.name} className="space-y-1.5">
                      <div className="flex justify-between text-sm">
                        <span className="truncate pr-2 font-medium text-slate-900">
                          {o.name}
                        </span>
                        <span className="flex-shrink-0 text-slate-500">
                          {o.sold}/{o.total} • {pct}%
                        </span>
                      </div>
                      <Progress value={pct} />
                    </div>
                  );
                })}
              </div>
            </div>
          </Card>
        </div>

        <Card>
          <div className="space-y-4 p-5">
            <div>
              <h3 className="flex items-center gap-2 text-base font-semibold text-slate-900">
                <Star className="h-5 w-5 text-amber-500" />
                Customer ratings
              </h3>
              <p className="text-sm text-slate-600">
                Distribution of{" "}
                {ratingsBreakdown.reduce((s, r) => s + r.count, 0)} reviews
              </p>
            </div>

            <ResponsiveContainer width="100%" height={180}>
              <BarChart data={ratingsBreakdown} layout="vertical">
                <CartesianGrid strokeDasharray="3 3" stroke="#d9e4df" />
                <XAxis type="number" stroke="#64748b" fontSize={12} />
                <YAxis
                  dataKey="stars"
                  type="category"
                  stroke="#64748b"
                  fontSize={12}
                  width={40}
                />
                <Tooltip />
                <Bar dataKey="count" fill="#f59e0b" radius={[0, 8, 8, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </Card>

        <Card className="border-[#b9dfd8] bg-gradient-to-br from-[#f0fbf8] to-white">
          <div className="space-y-3 p-5">
            <div>
              <h3 className="flex items-center gap-2 text-base font-semibold text-slate-900">
                <Sparkles className="h-5 w-5 text-[#16807a]" />
                Data-driven tips
              </h3>
              <p className="text-sm text-slate-600">
                Generated from statistics and forecast modeling on your{" "}
                {trainedOnDays || 60} days of history
              </p>
            </div>

            {loading ? (
              <>
                <div className="h-20 animate-pulse rounded-xl bg-slate-100" />
                <div className="h-20 animate-pulse rounded-xl bg-slate-100" />
                <div className="h-20 animate-pulse rounded-xl bg-slate-100" />
              </>
            ) : tips.length === 0 ? (
              <p className="py-8 text-center text-sm text-slate-500">
                Not enough data yet. Tips will appear once you have at least 14
                days of history.
              </p>
            ) : (
              tips.map((tip) => {
                const style = {
                  success: {
                    Icon: TrendingUp,
                    box: "bg-emerald-50 border-emerald-200",
                    icon: "text-emerald-600",
                  },
                  warning: {
                    Icon: AlertTriangle,
                    box: "bg-amber-50 border-amber-200",
                    icon: "text-amber-600",
                  },
                  tip: {
                    Icon: Lightbulb,
                    box: "bg-teal-50 border-teal-200",
                    icon: "text-teal-600",
                  },
                  forecast: {
                    Icon: Brain,
                    box: "bg-violet-50 border-violet-200",
                    icon: "text-violet-600",
                  },
                }[tip.type];

                const Icon = style.Icon;

                return (
                  <div
                    key={tip.id}
                    className={`flex gap-3 rounded-xl border p-4 ${style.box}`}
                  >
                    <div
                      className={`flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-lg bg-white ${style.icon}`}
                    >
                      <Icon className="h-4 w-4" />
                    </div>
                    <div className="min-w-0 flex-1 space-y-1.5">
                      <div className="flex flex-wrap items-start justify-between gap-2">
                        <p className="text-sm font-semibold text-slate-900">
                          {tip.title}
                        </p>
                        <Badge className="h-5 gap-1 border-[#cde4de] text-[10px] text-slate-600">
                          <CheckCircle2 className="h-2.5 w-2.5" />
                          {(tip.confidence * 100).toFixed(0)}% confidence
                        </Badge>
                      </div>
                      <p className="text-sm text-slate-600">{tip.message}</p>
                      <p className="border-t border-slate-200 pt-1 text-[11px] italic text-slate-500">
                        📊 {tip.evidence}
                      </p>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </Card>

        <div className="grid gap-4 md:grid-cols-3">
          <Card>
            <div className="flex items-center gap-3 p-4">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-50">
                <Users className="h-5 w-5 text-emerald-600" />
              </div>
              <div>
                <p className="text-sm text-slate-500">Repeat customers</p>
                <p className="text-lg font-bold text-slate-900">42%</p>
              </div>
            </div>
          </Card>

          <Card>
            <div className="flex items-center gap-3 p-4">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-teal-50">
                <ChefHat className="h-5 w-5 text-[#16807a]" />
              </div>
              <div>
                <p className="text-sm text-slate-500">Avg prep time</p>
                <p className="text-lg font-bold text-slate-900">12 min</p>
              </div>
            </div>
          </Card>

          <Card>
            <div className="flex items-center gap-3 p-4">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-amber-50">
                <Clock className="h-5 w-5 text-amber-600" />
              </div>
              <div>
                <p className="text-sm text-slate-500">No-show rate</p>
                <p className="text-lg font-bold text-slate-900">3.2%</p>
              </div>
            </div>
          </Card>
        </div>
      </div>
    </main>
  );
}
