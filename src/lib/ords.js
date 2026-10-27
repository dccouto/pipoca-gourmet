const base = (import.meta.env.VITE_ORDS_BASE_URL || '').trim().replace(/\/+$/, '')
const TOKEN_KEY = 'pope_ords_token'

export const ordsConfigurado = Boolean(base)

export function urlOrds(caminho) {
  if (!base) {
    throw new Error('Oracle ORDS não configurado. Defina VITE_ORDS_BASE_URL no .env')
  }
  const path = caminho.startsWith('/') ? caminho : `/${caminho}`
  return `${base}${path}`
}

export function getToken() {
  return localStorage.getItem(TOKEN_KEY) || ''
}

export function setToken(token) {
  if (token) localStorage.setItem(TOKEN_KEY, token)
  else localStorage.removeItem(TOKEN_KEY)
}

function enc(valor) {
  return encodeURIComponent(String(valor ?? ''))
}

/**
 * @param {string} caminho
 * @param {{ method?: string, headers?: Record<string,string>, auth?: boolean, query?: Record<string,string|number|boolean|undefined> }} [opcoes]
 */
export async function ordsFetch(caminho, opcoes = {}) {
  const metodo = opcoes.method || 'GET'
  const headers = { ...(opcoes.headers || {}) }

  if (opcoes.auth) {
    const token = getToken()
    if (!token) throw new Error('Sessão expirada. Entre novamente.')
    headers.Authorization = `Bearer ${token}`
  }

  let url = urlOrds(caminho)
  if (opcoes.query) {
    const qs = new URLSearchParams()
    for (const [chave, valor] of Object.entries(opcoes.query)) {
      if (valor === undefined || valor === null || valor === '') continue
      qs.set(chave, String(valor))
    }
    const texto = qs.toString()
    if (texto) url += (url.includes('?') ? '&' : '?') + texto
  }

  let resposta
  try {
    resposta = await fetch(url, { method: metodo, headers })
  } catch {
    throw new Error('Sem conexão com o Oracle ORDS. Confira VITE_ORDS_BASE_URL e a rede.')
  }

  const texto = await resposta.text()
  let dados = null
  try {
    dados = texto ? JSON.parse(texto) : null
  } catch {
    throw new Error(texto || `Resposta inválida do ORDS (${resposta.status})`)
  }

  if (!resposta.ok) {
    throw new Error(dados?.erro || dados?.message || `Erro ORDS ${resposta.status}`)
  }
  if (dados && typeof dados === 'object' && !Array.isArray(dados) && dados.erro) {
    throw new Error(dados.erro + (dados.detalhe ? `: ${dados.detalhe}` : ''))
  }
  return dados
}

export function headersCatalogo(campos) {
  const out = {}
  for (const [chave, valor] of Object.entries(campos)) {
    if (valor === undefined || valor === null) continue
    out[chave] = enc(valor)
  }
  return out
}
