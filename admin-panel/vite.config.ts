import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

// Local development: `npm run dev` proxies /api to the live analytics API.
// Put the admin basic-auth pair in admin-panel/.env.local (gitignored):
//   ADMIN_API_ORIGIN=https://admin.treepnet.com
//   ADMIN_BASIC=admin:<password>
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  const origin = env.ADMIN_API_ORIGIN || 'https://admin.130-61-138-104.sslip.io';
  const auth = env.ADMIN_BASIC ? `Basic ${Buffer.from(env.ADMIN_BASIC).toString('base64')}` : undefined;
  return {
    plugins: [react()],
    server: {
      port: 3000,
      host: true,
      proxy: {
        '/api': {
          target: origin,
          changeOrigin: true,
          secure: true,
          headers: auth ? { Authorization: auth } : undefined,
        },
      },
    },
  };
});
