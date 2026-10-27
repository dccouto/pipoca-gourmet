/**
 * Proxy ORDS → Oracle ADB.
 * Remove Origin/Referer (ADB responde ORDS-13002 Forbidden com Origin).
 *
 * Usos:
 * 1) Cloudflare Worker standalone (wrangler.toml) — CORS para GitHub Pages
 * 2) Cloudflare Pages Function (functions/ords/[[path]].js) — same-origin /ords
 */

const HOP_BY_HOP = new Set([
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailers',
  'transfer-encoding',
  'upgrade',
  'host',
  'origin',
  'referer',
  'cf-connecting-ip',
  'cf-ipcountry',
  'cf-ray',
  'cf-visitor',
  'x-forwarded-proto',
  'x-forwarded-for',
  'x-real-ip',
])

function targetBase(env) {
  return String(env.ORDS_PROXY_TARGET || '')
    .trim()
    .replace(/\/+$/, '')
}

function corsOrigins(env) {
  const raw = String(env.CORS_ALLOW_ORIGINS || '*').trim()
  if (!raw || raw === '*') return ['*']
  return raw.split(',').map((s) => s.trim()).filter(Boolean)
}

function pickAllowOrigin(request, env) {
  const allowed = corsOrigins(env)
  if (allowed.includes('*')) return '*'
  const origin = request.headers.get('Origin') || ''
  if (origin && allowed.includes(origin)) return origin
  return allowed[0] || '*'
}

function corsHeaders(request, env) {
  const allow = pickAllowOrigin(request, env)
  const headers = {
    'Access-Control-Allow-Origin': allow,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers':
      request.headers.get('Access-Control-Request-Headers') ||
      'Authorization, Content-Type, email, senha, nome, descricao, emoji, cor, ativo, ordem, preco_centavos, destaque, selo, numero_whatsapp, nome_exibido, slogan',
    'Access-Control-Max-Age': '86400',
  }
  if (allow !== '*') headers.Vary = 'Origin'
  return headers
}

function buildUpstreamUrl(request, env) {
  const base = targetBase(env)
  if (!base) return null
  const incoming = new URL(request.url)
  // Mantém /ords/... no path (ORDS público espera /ords/...)
  return `${base}${incoming.pathname}${incoming.search}`
}

function filterRequestHeaders(request) {
  const out = new Headers()
  for (const [key, value] of request.headers.entries()) {
    if (HOP_BY_HOP.has(key.toLowerCase())) continue
    out.set(key, value)
  }
  return out
}

/**
 * @param {Request} request
 * @param {{ ORDS_PROXY_TARGET?: string, CORS_ALLOW_ORIGINS?: string }} env
 * @param {{ addCors?: boolean }} [opts]
 */
export async function proxyOrds(request, env, opts = {}) {
  const addCors = opts.addCors !== false
  const cors = addCors ? corsHeaders(request, env) : {}

  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: cors })
  }

  const upstreamUrl = buildUpstreamUrl(request, env)
  if (!upstreamUrl) {
    return new Response(
      JSON.stringify({
        erro: 'ORDS_PROXY_TARGET não configurado no Worker/Pages',
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...cors },
      },
    )
  }

  const headers = filterRequestHeaders(request)
  const init = {
    method: request.method,
    headers,
    redirect: 'follow',
  }
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    init.body = request.body
    // @ts-expect-error duplex exigido em alguns runtimes com body stream
    init.duplex = 'half'
  }

  let upstream
  try {
    upstream = await fetch(upstreamUrl, init)
  } catch (err) {
    return new Response(
      JSON.stringify({
        erro: 'Falha ao contatar Oracle ORDS',
        detalhe: err instanceof Error ? err.message : String(err),
      }),
      {
        status: 502,
        headers: { 'Content-Type': 'application/json', ...cors },
      },
    )
  }

  const responseHeaders = new Headers(upstream.headers)
  for (const key of ['Access-Control-Allow-Origin', 'Access-Control-Allow-Methods', 'Access-Control-Allow-Headers']) {
    responseHeaders.delete(key)
  }
  for (const [key, value] of Object.entries(cors)) {
    responseHeaders.set(key, value)
  }

  return new Response(upstream.body, {
    status: upstream.status,
    statusText: upstream.statusText,
    headers: responseHeaders,
  })
}

/** Entrada Worker standalone (wrangler). */
export default {
  async fetch(request, env) {
    return proxyOrds(request, env, { addCors: true })
  },
}
