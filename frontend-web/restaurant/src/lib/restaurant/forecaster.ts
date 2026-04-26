import type { DailyPoint } from './mockHistory';

export type Forecast = {
  dayOfWeek: number;
  predictedRevenue: number;
  lower: number;
  upper: number;
  confidence: number;
};

export async function trainAndForecast(
  daily: DailyPoint[],
  horizon: number,
  minTrainingDays: number,
): Promise<{ forecasts: Forecast[]; trainedOnDays: number }> {
  const trainedOnDays = Math.max(minTrainingDays, Math.min(365, daily.length));
  const train = daily.slice(-trainedOnDays);

  const avg = train.reduce((sum, d) => sum + d.revenue, 0) / Math.max(train.length, 1);

  const recent = train.slice(-7);
  const older = train.slice(-14, -7);
  const recentAvg = recent.reduce((s, d) => s + d.revenue, 0) / Math.max(recent.length, 1);
  const olderAvg = older.length
    ? older.reduce((s, d) => s + d.revenue, 0) / older.length
    : recentAvg;
  const trend = Math.max(-0.2, Math.min(0.2, (recentAvg - olderAvg) / Math.max(olderAvg, 1)));

  const lastDate = new Date(daily[daily.length - 1]?.date ?? new Date().toISOString().slice(0, 10));
  const forecasts: Forecast[] = [];

  for (let i = 1; i <= horizon; i += 1) {
    const next = new Date(lastDate);
    next.setDate(lastDate.getDate() + i);
    const dayOfWeek = next.getDay();
    const weekendBoost = dayOfWeek === 5 || dayOfWeek === 6 ? 1.12 : 1;
    const predictedRevenue = Math.round(avg * (1 + trend * (i / horizon)) * weekendBoost);
    const band = Math.max(18, Math.round(predictedRevenue * 0.12));

    forecasts.push({
      dayOfWeek,
      predictedRevenue,
      lower: Math.max(0, predictedRevenue - band),
      upper: predictedRevenue + band,
      confidence: Math.max(0.55, 0.9 - i * 0.04),
    });
  }

  // Keep async shape to mimic ML retraining latency.
  await new Promise((resolve) => setTimeout(resolve, 500));
  return { forecasts, trainedOnDays };
}
