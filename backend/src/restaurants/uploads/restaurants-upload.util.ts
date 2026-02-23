import { extname } from 'path';
import { BadRequestException } from '@nestjs/common';
import { RestaurantUploadType } from './restaurants-upload.constants';

export function getPublicBaseUrl() {
  return process.env.PUBLIC_BACKEND_URL || 'http://localhost:3000';
}

export function makeRestaurantUploadPublicUrl(
  userId: string,
  filename: string,
): string {
  const baseUrl = getPublicBaseUrl().replace(/\/+$/, '');
  return `${baseUrl}/uploads/restaurants/${userId}/${filename}`;
}

export function getRestaurantUploadFilename(
  uploadType: RestaurantUploadType,
  originalName: string,
): string {
  const ext = extname(originalName || '').toLowerCase();
  if (!ext) throw new BadRequestException('File must have an extension');
  return `${uploadType}${ext}`;
}
