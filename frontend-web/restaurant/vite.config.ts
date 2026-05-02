import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    strictPort: true,
    port: 5175,
    proxy: {
      "^/auth": "http://192.168.53.51:3000",
      "^/restaurant": "http://192.168.53.51:3000",
    },
  },
});
