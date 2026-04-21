import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    strictPort: true,
    port: 5174,
    proxy: {
      "^/auth/": "http://192.168.61.154:3000",
      "^/admin/(dashboard|users|clients|restaurants|orders|deliverers)": "http://192.168.61.154:3000",
    },
    middlewareMode: false,
  },
  // Ensure all routes redirect to index.html for SPA
  preview: {
    port: 5174,
  },
});
