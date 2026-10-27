/**
 * Cloudflare Pages Function — proxy same-origin /ords/*
 * Secret/var: ORDS_PROXY_TARGET = https://XXXX-pipocag.adb....oraclecloudapps.com
 * (sem sufixo /ords — o path do request já inclui /ords/...)
 */
import { proxyOrds } from '../../cloudflare/ords-proxy.js'

export async function onRequest(context) {
  // Same-origin: CORS opcional; mantemos headers permissivos por simplicidade.
  return proxyOrds(context.request, context.env, { addCors: true })
}
