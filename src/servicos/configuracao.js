import { headersCatalogo, ordsFetch } from '../lib/ords.js'
import { mensagemErro } from '../lib/erros.js'

export async function getConfiguracao() {
  try {
    return await ordsFetch('/pipocag/api/config')
  } catch (erro) {
    throw new Error(mensagemErro(erro))
  }
}

export async function salvarConfiguracao({ numero_whatsapp, nome_exibido, slogan }) {
  try {
    return await ordsFetch('/pipocag/api/config', {
      method: 'PUT',
      auth: true,
      headers: headersCatalogo({
        numero_whatsapp: String(numero_whatsapp).replace(/\D/g, ''),
        nome_exibido: nome_exibido.trim() || 'POPÊ',
        slogan: slogan.trim(),
      }),
    })
  } catch (erro) {
    throw new Error(mensagemErro(erro))
  }
}
