export function mensagemErro(erro) {
  if (!erro) return 'Algo deu errado.'
  const texto = typeof erro === 'string' ? erro : erro.message || String(erro)

  if (/Failed to fetch|NetworkError|fetch/i.test(texto)) {
    return 'Sem conexão com o Oracle ORDS. Confira VITE_ORDS_BASE_URL e a rede.'
  }
  if (/credenciais invalidas|nao autorizado/i.test(texto)) {
    return 'E-mail ou senha incorretos, ou sessão expirada.'
  }
  if (/ORDS não configurado|não configurado/i.test(texto)) {
    return texto
  }
  return texto
}

export function formatarPrecoCentavos(centavos) {
  return (Number(centavos) / 100).toLocaleString('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  })
}

export function reaisParaCentavos(valor) {
  const limpo = String(valor).replace(',', '.').trim()
  const num = Number(limpo)
  if (Number.isNaN(num) || num < 0) return 0
  return Math.round(num * 100)
}

export function centavosParaReaisInput(centavos) {
  return (Number(centavos) / 100).toFixed(2)
}
