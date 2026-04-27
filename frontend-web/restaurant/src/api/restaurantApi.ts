const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://192.168.61.154:3000';

export interface RestaurantStats {
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
}

export interface ApiResponse<T> {
  data?: T;
  error?: string;
}

class RestaurantApi {
  private getAuthToken(): string | null {
    return localStorage.getItem('access_token') || localStorage.getItem('onboarding_token');
  }

  private getHeaders(): HeadersInit {
    const token = this.getAuthToken();
    return {
      'Content-Type': 'application/json',
      ...(token && { Authorization: `Bearer ${token}` }),
    };
  }

  async getRestaurantStats(): Promise<RestaurantStats> {
    try {
      const response = await fetch(
        `${API_BASE_URL}/restaurant/onboarding/stats`,
        {
          method: 'GET',
          headers: this.getHeaders(),
        }
      );

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data: RestaurantStats = await response.json();
      return data;
    } catch (error) {
      console.error('Error fetching restaurant stats:', error);
      throw error;
    }
  }
}

export default new RestaurantApi();
