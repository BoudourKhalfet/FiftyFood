export type DailyPoint = {
  date: string;
  dayOfWeek: number;
  revenue: number;
  orders: number;
  mealsSaved: number;
};

export type OfferHistoryPoint = {
  name: string;
  sold: number;
  total: number;
};

export type HourlyPoint = {
  hour: number;
  pickups: number;
};

export function generateDailyHistory(days: number): DailyPoint[] {
  const now = new Date();
  const out: DailyPoint[] = [];

  for (let i = days - 1; i >= 0; i -= 1) {
    const d = new Date(now);
    d.setDate(now.getDate() - i);

    const weekday = d.getDay();
    const weekendBoost = weekday === 5 || weekday === 6 ? 1.18 : 1;
    const wave = 1 + Math.sin((days - i) / 4) * 0.13;
    const baseRevenue = 280;
    const revenue = Math.round(
      baseRevenue * weekendBoost * wave + (days - i) * 2.1,
    );
    const orders = Math.max(8, Math.round(revenue / 11));
    const mealsSaved = Math.max(6, Math.round(orders * 1.24));

    out.push({
      date: d.toISOString().slice(0, 10),
      dayOfWeek: weekday,
      revenue,
      orders,
      mealsSaved,
    });
  }

  return out;
}

export function generateOfferHistory(): OfferHistoryPoint[] {
  return [
    { name: "Pasta Box", sold: 61, total: 75 },
    { name: "Chicken Bowl", sold: 47, total: 60 },
    { name: "Bakery Mix", sold: 38, total: 50 },
    { name: "Veggie Pack", sold: 29, total: 42 },
    { name: "Dessert Combo", sold: 24, total: 36 },
  ];
}

export function generateHourlyHistory(): HourlyPoint[] {
  return [
    { hour: 10, pickups: 8 },
    { hour: 11, pickups: 12 },
    { hour: 12, pickups: 18 },
    { hour: 13, pickups: 26 },
    { hour: 14, pickups: 22 },
    { hour: 15, pickups: 17 },
    { hour: 16, pickups: 15 },
    { hour: 17, pickups: 20 },
    { hour: 18, pickups: 24 },
    { hour: 19, pickups: 19 },
  ];
}
