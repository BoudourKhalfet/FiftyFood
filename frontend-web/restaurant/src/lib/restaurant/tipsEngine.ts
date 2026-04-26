import type { Forecast } from './forecaster';
import type { DailyPoint, HourlyPoint, OfferHistoryPoint } from './mockHistory';

export type RestaurantTip = {
  id: string;
  type: 'success' | 'warning' | 'tip' | 'forecast';
  title: string;
  message: string;
  evidence: string;
  confidence: number;
};

export function generateTips(input: {
  daily: DailyPoint[];
  offers: OfferHistoryPoint[];
  hourly: HourlyPoint[];
  forecasts: Forecast[];
}): RestaurantTip[] {
  const tips: RestaurantTip[] = [];
  const { daily, offers, hourly, forecasts } = input;

  const last7 = daily.slice(-7);
  const prev7 = daily.slice(-14, -7);
  const rev7 = last7.reduce((s, d) => s + d.revenue, 0);
  const revPrev = prev7.reduce((s, d) => s + d.revenue, 0);

  if (revPrev > 0 && rev7 > revPrev * 1.07) {
    tips.push({
      id: 'rev-growth',
      type: 'success',
      title: 'Revenue momentum is strong',
      message: 'Your weekly revenue is climbing. Keep high-performing offers visible through peak pickup hours.',
      evidence: `Last 7d revenue ${rev7} vs previous 7d ${revPrev}.`,
      confidence: 0.86,
    });
  }

  const weakOffer = offers
    .map((o) => ({ ...o, pct: o.total > 0 ? o.sold / o.total : 0 }))
    .sort((a, b) => a.pct - b.pct)[0];

  if (weakOffer && weakOffer.pct < 0.65) {
    tips.push({
      id: 'offer-low-sellthrough',
      type: 'warning',
      title: 'One offer is underperforming',
      message: `Consider adjusting pricing or photo for ${weakOffer.name} to improve sell-through.`,
      evidence: `${weakOffer.sold}/${weakOffer.total} sold (${Math.round(weakOffer.pct * 100)}%).`,
      confidence: 0.79,
    });
  }

  const peak = [...hourly].sort((a, b) => b.pickups - a.pickups)[0];
  if (peak) {
    tips.push({
      id: 'pickup-peak',
      type: 'tip',
      title: 'Peak pickup window detected',
      message: `Most pickups happen around ${peak.hour}:00. Schedule prep completion slightly earlier to reduce waiting time.`,
      evidence: `${peak.pickups} pickups around ${peak.hour}:00, highest hour in your recent data.`,
      confidence: 0.83,
    });
  }

  if (forecasts.length > 0) {
    const avgForecast =
      forecasts.reduce((sum, f) => sum + f.predictedRevenue, 0) / forecasts.length;
    tips.push({
      id: 'forecast-week',
      type: 'forecast',
      title: 'Forecast suggests steady next week',
      message: 'Expected revenue remains stable with mild upward trend toward the weekend.',
      evidence: `Predicted daily revenue avg ~${Math.round(avgForecast)} over next ${forecasts.length} days.`,
      confidence:
        forecasts.reduce((sum, f) => sum + f.confidence, 0) / forecasts.length,
    });
  }

  return tips.slice(0, 4);
}
