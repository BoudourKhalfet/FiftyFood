import { mkdirSync } from 'fs';

export function ensureDir(path: string) {
  mkdirSync(path, { recursive: true });
}
