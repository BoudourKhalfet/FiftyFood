import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    strictPort: true,
    port: 5174,
    proxy: {
      "^/auth": {
        target: "http://localhost:3000",
        changeOrigin: true,
      },
      "^/admin/(users|dashboard|restaurants|livreurs|clients|decisions)": {
        target: "http://localhost:3000",
        changeOrigin: true,
      },
      "^/orders": {
        target: "http://localhost:3000",
        changeOrigin: true,
      },
      "^/users": {
        target: "http://localhost:3000",
        changeOrigin: true,
      },
      "^/restaurants": {
        target: "http://localhost:3000",
        changeOrigin: true,
      },
      "^/livreur": {
        target: "http://localhost:3000",
        changeOrigin: true,
      },
      "^/feedback": {
        target: "http://localhost:3000",
        changeOrigin: true,
      },
      "^/payments": {
        target: "http://localhost:3000",
        changeOrigin: true,
      },
      "^/offers": {
        target: "http://localhost:3000",
        changeOrigin: true,
      },
    },
    middlewareMode: false,
  },
  preview: {
    port: 5174,
  },
});
