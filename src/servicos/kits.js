import { headersCatalogo, ordsFetch } from '../lib/ords.js'
import { mensagemErro } from '../lib/erros.js'

/**
 * @param {{ soAtivos?: boolean }} [opcoes]
 */
export async function listarKits(opcoes = {}) {
  try {
    const lista = await ordsFetch('/pipocag/api/kits', {
      query: opcoes.soAtivos ? { ativos: 1 } : undefined,
    })
    return Array.isArray(lista)
      ? lista.map((k) => ({ ...k, selo: (k.selo || '').trim() }))
      : []
  } catch (erro) {
    throw new Error(mensagemErro(erro))
  }
}

export async function salvarKit(dados, id) {
  try {
    const headers = headersCatalogo({
      nome: dados.nome.trim(),
      descricao: dados.descricao.trim(),
      preco_centavos: dados.preco_centavos,
      destaque: dados.destaque ? '1' : '0',
      selo: dados.selo.trim() || ' ',
      ativo: dados.ativo ? '1' : '0',
      ordem: Number(dados.ordem) || 0,
    })

    if (id) {
      return await ordsFetch(`/pipocag/api/kits/${id}`, {
        method: 'PUT',
        auth: true,
        headers,
      })
    }
    return await ordsFetch('/pipocag/api/kits', {
      method: 'POST',
      auth: true,
      headers,
    })
  } catch (erro) {
    throw new Error(mensagemErro(erro))
  }
}

export async function excluirKit(id) {
  try {
    await ordsFetch(`/pipocag/api/kits/${id}`, {
      method: 'DELETE',
      auth: true,
    })
  } catch (erro) {
    throw new Error(mensagemErro(erro))
  }
}
