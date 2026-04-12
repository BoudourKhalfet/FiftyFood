import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    strictPort: false, // Allow trying another port if 5173 is in use
    // This tells Vite to send /auth/* and /admin/* API requests to your backend (usually NestJS at port 3000)
    proxy: {
      "^/auth": "http://localhost:3000",
      "^/admin": "http://localhost:3000",
    },
    // Vite v4+ SPA fallback is ON by default; no need for extra config usually
  },
});
