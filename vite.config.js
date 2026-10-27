import { defineConfig, loadEnv } from 'vite'
import { resolve } from 'node:path'

const raiz = import.meta.dirname

function ordsProxy(proxyTarget) {
  return {
    '/ords': {
      target: proxyTarget,
      changeOrigin: true,
      secure: true,
      // ORDS ADB rejeita Origin (ORDS-13002) mesmo com origins '*'.
      configure: (proxy) => {
        proxy.on('proxyReq', (proxyReq) => {
          proxyReq.removeHeader('origin')
          proxyReq.removeHeader('referer')
        })
      },
    },
  }
}

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, raiz, '')
  const proxyTarget = (env.ORDS_PROXY_TARGET || '').replace(/\/+$/, '')
  const proxy = proxyTarget ? ordsProxy(proxyTarget) : undefined

  return {
    base: process.env.VITE_BASE || '/',
    appType: 'mpa',
    server: proxy ? { proxy } : undefined,
    preview: proxy ? { proxy } : undefined,
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
