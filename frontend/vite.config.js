import { fileURLToPath, URL } from 'node:url';
import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

/**
 * `@/…` resolves to `src/…` so imports never climb out of a folder with `../../`.
 * The dev server proxies `/api` to the Express backend, which keeps the browser
 * on one origin and makes CORS a non-issue during development.
 */
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  const backend = env.VITE_BACKEND_URL || 'http://localhost:4000';

  return {
    plugins: [react(), tailwindcss()],
    resolve: {
      alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) },
    },
    server: {
      port: 5173,
      // Reachable from a phone on the same wifi, which is the point of this app.
      host: true,
      proxy: {
        '/api': { target: backend, changeOrigin: true },
        '/files': { target: backend, changeOrigin: true },
      },
    },
    build: {
      outDir: 'dist',
      sourcemap: mode !== 'production',
    },
  };
});
