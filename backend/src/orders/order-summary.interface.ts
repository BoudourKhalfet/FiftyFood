export interface OrderSummary {
  id: string;
  reference: string;
  pickupQrToken?: string;
  pickupQrDisplay?: string;
  pickupTime?: string;
  restaurantName?: string;
  // Add other returned fields here as needed.
}
