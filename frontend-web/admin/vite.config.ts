import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    strictPort: false, // Allow trying another port if 5173 is in use
    port: 5174,

    proxy: {
      "^/auth": "http://localhost:3000",
      "^/admin": "http://localhost:3000",
      "^/orders": "http://localhost:3000",
    },
    // Vite v4+ SPA fallback is ON by default; no need for extra config usually
  },
});
