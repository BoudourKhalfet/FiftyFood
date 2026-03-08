export const LIVREUR_UPLOAD_TYPES = [
  'photo',
  'license',
  'ownership',
  'vehicle',
] as const;
export type LivreurUploadType = (typeof LIVREUR_UPLOAD_TYPES)[number];
