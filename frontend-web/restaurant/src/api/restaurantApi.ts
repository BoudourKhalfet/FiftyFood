const API_BASE_URL =
  import.meta.env.VITE_API_URL || "http://192.168.1.15:3000";

export interface RestaurantStats {
  restaurantName: string;
  // Total stats
  totalSales: number;
  totalOrders: number;
  totalMealsSaved: number;
  avgRating: number;
  activeOffers: number;

  // 7-day stats
  revenue7d: number;
  orders7d: number;
  mealsSaved7d: number;
  revenueChangePercent: number;
  ordersChangePercent: number;
  mealsSavedChangePercent: number;
  avgRatingChange: number;
  commissionRate: number;
}

export interface WeeklyChartDay {
  day: string;
  revenue: number;
  orders: number;
}

export interface RatingsDistribution {
  total: number;
  distribution: { stars: number; count: number }[];
}

export interface MonthlyHistoryDay {
  month: string;
  revenue: number;
  mealsSaved: number;
}

export interface PickupPerHour {
  hour: string;
  count: number;
}

export interface Complaint {
  id: string;
  reason: string;
  description: string | null;
  createdAt: string;
  complainantName: string;
  orderReference: string;
}

export interface ApiResponse<T> {
  data?: T;
  error?: string;
}

class RestaurantApi {
  private getAuthToken(): string | null {
    return (
      localStorage.getItem("access_token") ||
      localStorage.getItem("onboarding_token")
    );
  }

  private getHeaders(): HeadersInit {
    const token = this.getAuthToken();
    return {
      "Content-Type": "application/json",
      ...(token && { Authorization: `Bearer ${token}` }),
    };
  }

  async getMonthlyHistory(): Promise<MonthlyHistoryDay[]> {
    const response = await fetch(`${API_BASE_URL}/restaurant/onboarding/monthly-history`, {
      method: "GET",
      headers: this.getHeaders(),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    return response.json();
  }

  async getPickupsPerHour(): Promise<PickupPerHour[]> {
    const response = await fetch(`${API_BASE_URL}/restaurant/onboarding/pickups-per-hour`, {
      method: "GET",
      headers: this.getHeaders(),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    return response.json();
  }

  async getRatingsDistribution(): Promise<RatingsDistribution> {
    const response = await fetch(`${API_BASE_URL}/restaurant/onboarding/ratings-distribution`, {
      method: "GET",
      headers: this.getHeaders(),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    return response.json();
  }

  async getWeeklyChartData(): Promise<WeeklyChartDay[]> {
    const response = await fetch(`${API_BASE_URL}/restaurant/onboarding/weekly-chart`, {
      method: "GET",
      headers: this.getHeaders(),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    return response.json();
  }

  async getRestaurantStats(): Promise<RestaurantStats> {
    try {
      const response = await fetch(
        `${API_BASE_URL}/restaurant/onboarding/stats`,
        {
          method: "GET",
          headers: this.getHeaders(),
        },
      );

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data: RestaurantStats = await response.json();
      return data;
    } catch (error) {
      console.error("Error fetching restaurant stats:", error);
      throw error;
    }
  }

  async getComplaints(limit?: number): Promise<Complaint[]> {
    const response = await fetch(
      `${API_BASE_URL}/feedback/received/complaints?limit=${limit ?? 50}`,
      {
        method: "GET",
        headers: this.getHeaders(),
      },
    );
    if (!response.ok) throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    return response.json();
  }
}

export default new RestaurantApi();
