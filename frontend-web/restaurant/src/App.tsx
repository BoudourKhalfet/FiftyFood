type MetricCard = {
  id: string;
  icon: string;
  iconBg: string;
  value: string;
  label: string;
  change: string;
  positive: boolean;
};

const metrics: MetricCard[] = [
  {
    id: "revenue",
    icon: "€",
    iconBg: "bg-teal-50 text-teal-600",
    value: "€2300",
    label: "Revenue (7d)",
    change: "+12.4%",
    positive: true,
  },
  {
    id: "orders",
    icon: "◻",
    iconBg: "bg-orange-50 text-orange-500",
    value: "227",
    label: "Orders (7d)",
    change: "+8.1%",
    positive: true,
  },
  {
    id: "saved",
    icon: "◌",
    iconBg: "bg-emerald-50 text-emerald-600",
    value: "284",
    label: "Meals saved",
    change: "+15.2%",
    positive: true,
  },
  {
    id: "rating",
    icon: "☆",
    iconBg: "bg-amber-50 text-amber-500",
    value: "4.7",
    label: "Avg rating",
    change: "-0.1",
    positive: false,
  },
];

function App() {
  return (
    <main className="min-h-screen bg-[#f8faf9] px-6 py-6 md:px-9 lg:px-10">
      <section className="mx-auto w-full max-w-[1600px]">
        <header className="mb-8">
          <h1 className="text-[36px] font-bold leading-tight text-slate-900">
            Overview
          </h1>
          <p className="mt-1 text-lg text-slate-600">
            Performance, ML forecasts, and statistics-driven tips
          </p>
        </header>

        <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 xl:grid-cols-4">
          {metrics.map((metric) => (
            <article
              key={metric.id}
              className="rounded-2xl border border-[#d9e4df] bg-white p-6 shadow-[0_1px_2px_rgba(15,23,42,0.06)]"
            >
              <div className="mb-6 flex items-start justify-between">
                <div
                  className={`flex h-14 w-14 items-center justify-center rounded-2xl text-3xl font-semibold ${metric.iconBg}`}
                >
                  {metric.icon}
                </div>
                <span
                  className={`inline-flex items-center rounded-full border px-3 py-1 text-xl font-semibold ${
                    metric.positive
                      ? "border-emerald-300 bg-emerald-50 text-emerald-600"
                      : "border-red-300 bg-red-50 text-red-600"
                  }`}
                >
                  {metric.positive ? "↗ " : "↘ "}
                  {metric.change}
                </span>
              </div>

              <p className="text-[46px] font-bold leading-none text-slate-900">
                {metric.value}
              </p>
              <p className="mt-3 text-[28px] text-slate-600">{metric.label}</p>
            </article>
          ))}
        </div>
      </section>
    </main>
  );
}

export default App;
