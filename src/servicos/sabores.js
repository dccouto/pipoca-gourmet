import { headersCatalogo, ordsFetch } from '../lib/ords.js'
import { mensagemErro } from '../lib/erros.js'

/**
 * @param {{ soAtivos?: boolean }} [opcoes]
 */
export async function listarSabores(opcoes = {}) {
  try {
    const lista = await ordsFetch('/pipocag/api/sabores', {
      query: opcoes.soAtivos ? { ativos: 1 } : undefined,
    })
    return Array.isArray(lista) ? lista : []
  } catch (erro) {
    throw new Error(mensagemErro(erro))
  }
}

export async function salvarSabor(dados, id) {
  try {
    const headers = headersCatalogo({
      nome: dados.nome.trim(),
      emoji: dados.emoji.trim() || '🍿',
      descricao: dados.descricao.trim(),
      preco_centavos: dados.preco_centavos,
      cor: dados.cor.trim() || '#E8A838',
      ativo: dados.ativo ? '1' : '0',
      ordem: Number(dados.ordem) || 0,
    })

    if (id) {
      return await ordsFetch(`/pipocag/api/sabores/${id}`, {
        method: 'PUT',
        auth: true,
        headers,
      })
    }
    return await ordsFetch('/pipocag/api/sabores', {
      method: 'POST',
      auth: true,
      headers,
    })
  } catch (erro) {
    throw new Error(mensagemErro(erro))
  }
}

export async function excluirSabor(id) {
  try {
    await ordsFetch(`/pipocag/api/sabores/${id}`, {
      method: 'DELETE',
      auth: true,
    })
  } catch (erro) {
    throw new Error(mensagemErro(erro))
  }
}
