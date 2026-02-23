export const LIVREUR_UPLOAD_TYPES = [
  'photo',
  'cinOrPassport',
  'license',
  'insurance',
  'bankRib',
] as const;
export type LivreurUploadType = (typeof LIVREUR_UPLOAD_TYPES)[number];
