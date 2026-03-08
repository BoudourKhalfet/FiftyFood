import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    // This tells Vite to send /auth/* and /admin/* API requests to your backend (usually NestJS at port 3000)
    proxy: {
      "/auth": "http://localhost:3000", // <-- For API: /auth/login etc.
      "^/admin/(users|restaurants|clients|deliverers|orders|reports|insights)":
        "http://localhost:3000",
    },
    // Vite v4+ SPA fallback is ON by default; no need for extra config usually
  },
});
