import { defineConfig, loadEnv } from 'vite'
import { resolve } from 'node:path'

const raiz = import.meta.dirname

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, raiz, '')
  const proxyTarget = (env.ORDS_PROXY_TARGET || '').replace(/\/+$/, '')

  return {
    base: process.env.VITE_BASE || '/',
    appType: 'mpa',
    server: proxyTarget
      ? {
          proxy: {
            '/ords': {
              target: proxyTarget,
              changeOrigin: true,
              secure: true,
              // ORDS ADB rejeita Origin (ORDS-13002) mesmo com origins '*'.
              // No proxy local removemos Origin/Referer para o fetch same-origin funcionar.
              configure: (proxy) => {
                proxy.on('proxyReq', (proxyReq) => {
                  proxyReq.removeHeader('origin')
                  proxyReq.removeHeader('referer')
                })
              },
            },
          },
        }
      : undefined,
    build: {
      rollupOptions: {
        input: {
          main: resolve(raiz, 'index.html'),
          admin: resolve(raiz, 'admin/index.html'),
        },
      },
    },
  }
})
