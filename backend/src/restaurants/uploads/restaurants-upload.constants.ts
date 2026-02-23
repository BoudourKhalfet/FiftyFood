export const RESTAURANT_UPLOAD_TYPES = [
  'logo',
  'cover',
  'business-registration',
  'hygiene-certificate',
  'proof-of-ownership',
] as const;

export type RestaurantUploadType = (typeof RESTAURANT_UPLOAD_TYPES)[number];
