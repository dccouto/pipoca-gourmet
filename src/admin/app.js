import { ordsConfigurado } from '../lib/ords.js'
import {
  centavosParaReaisInput,
  formatarPrecoCentavos,
  mensagemErro,
  reaisParaCentavos,
} from '../lib/erros.js'
import { alterarSenha, carregarSessao, entrar, sair } from '../servicos/auth.js'
import { excluirSabor, listarSabores, salvarSabor } from '../servicos/sabores.js'
import { excluirKit, listarKits, salvarKit } from '../servicos/kits.js'
import { getConfiguracao, salvarConfiguracao } from '../servicos/configuracao.js'

const rotasAuth = new Set(['sabores', 'kits', 'config'])

function rotaAtual() {
  const hash = window.location.hash.replace(/^#\/?/, '') || 'sabores'
  return hash.split('?')[0]
}

function irPara(rota) {
  window.location.hash = `#/${rota}`
}

function escapar(texto) {
  return String(texto ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
}

export async function montarAdmin(root) {
  const estado = {
    sessao: null,
    carregando: true,
    erro: '',
    ok: '',
    sabores: [],
    kits: [],
    config: null,
    modal: null,
  }

  async function bootstrap() {
    if (!ordsConfigurado) {
      estado.carregando = false
      render()
      return
    }

    try {
      estado.sessao = await carregarSessao()
      if (estado.sessao && rotasAuth.has(rotaAtual())) {
        await carregarDadosRota()
      } else if (estado.sessao && rotaAtual() === 'login') {
        irPara('sabores')
        return
      } else if (!estado.sessao && rotasAuth.has(rotaAtual())) {
        irPara('login')
        return
      }
    } catch (erro) {
      estado.erro = mensagemErro(erro)
    } finally {
      estado.carregando = false
      render()
    }
  }

  async function carregarDadosRota() {
    const rota = rotaAtual()
    if (rota === 'sabores') estado.sabores = await listarSabores()
    if (rota === 'kits') estado.kits = await listarKits()
    if (rota === 'config') estado.config = await getConfiguracao()
  }

  function render() {
    if (!ordsConfigurado) {
      root.innerHTML = `
        <div class="admin-shell">
          <div class="alerta alerta-aviso">
            Configure o Oracle ORDS: copie <code>.env.example</code> para <code>.env</code>,
            preencha <code>VITE_ORDS_BASE_URL</code> (URL pública do ADB) e reinicie o Vite.
            Detalhes em <code>oracle/README-ORACLE.md</code>.
          </div>
          <p><a href="${import.meta.env.BASE_URL}">← Voltar ao site</a></p>
        </div>
      `
      return
    }

    if (estado.carregando) {
      root.innerHTML = `<div class="carregando">Carregando painel…</div>`
      return
    }

    const rota = rotaAtual()
    if (!estado.sessao || rota === 'login') {
      root.innerHTML = telaLogin()
      ligarLogin()
      return
    }

    root.innerHTML = `
      <div class="admin-shell">
        ${cabecalho(rota)}
        ${estado.erro ? `<div class="alerta alerta-erro" role="alert">${escapar(estado.erro)}</div>` : ''}
        ${estado.ok ? `<div class="alerta alerta-ok">${escapar(estado.ok)}</div>` : ''}
        ${rota === 'sabores' ? telaSabores() : ''}
        ${rota === 'kits' ? telaKits() : ''}
        ${rota === 'config' ? telaConfig() : ''}
        ${estado.modal ? estado.modal.html : ''}
      </div>
    `
    ligarPainel(rota)
  }

  function cabecalho(rota) {
    return `
      <header class="admin-topo">
        <a class="admin-marca" href="${import.meta.env.BASE_URL}">🍿 <span>POPÊ</span> Admin</a>
        <nav class="admin-nav">
          <a href="#/sabores" class="${rota === 'sabores' ? 'ativo' : ''}">Sabores</a>
          <a href="#/kits" class="${rota === 'kits' ? 'ativo' : ''}">Kits</a>
          <a href="#/config" class="${rota === 'config' ? 'ativo' : ''}">Configurações</a>
          <button type="button" id="btn-sair">Sair</button>
        </nav>
      </header>
    `
  }

  function telaLogin() {
    return `
      <div class="login-box">
        <h1>Área admin</h1>
        <p>Entre com o e-mail e senha do admin Oracle (usuarios_admin).</p>
        ${estado.erro ? `<div class="alerta alerta-erro" role="alert">${escapar(estado.erro)}</div>` : ''}
        <form id="form-login">
          <div>
            <label for="email">E-mail</label>
            <input id="email" name="email" type="email" autocomplete="username" required />
          </div>
          <div>
            <label for="senha">Senha</label>
            <input id="senha" name="senha" type="password" autocomplete="current-password" required />
          </div>
          <button class="btn btn-primario" type="submit" id="btn-entrar">Entrar</button>
        </form>
        <p style="margin-top:1.25rem"><a href="${import.meta.env.BASE_URL}">← Voltar ao site</a></p>
      </div>
    `
  }

  function telaSabores() {
    if (!estado.sabores.length) {
      return `
        <div class="painel-titulo">
          <div>
            <h1>Sabores</h1>
            <p>O que aparece na vitrine do site.</p>
          </div>
          <button type="button" class="btn btn-primario" id="btn-novo-sabor">Novo sabor</button>
        </div>
        <div class="card vazio"><strong>Nenhum sabor</strong>Cadastre o primeiro estouro.</div>
      `
    }

    return `
      <div class="painel-titulo">
        <div>
          <h1>Sabores</h1>
          <p>${estado.sabores.length} cadastrado(s). Inativos ficam ocultos no site.</p>
        </div>
        <button type="button" class="btn btn-primario" id="btn-novo-sabor">Novo sabor</button>
      </div>
      <div class="lista">
        ${estado.sabores
          .map(
            (s) => `
          <article class="item-lista" data-id="${s.id}">
            <div class="item-lista-info">
              <span class="item-emoji">${escapar(s.emoji)}</span>
              <div>
                <h3>${escapar(s.nome)}</h3>
                <p class="item-meta">
                  ${formatarPrecoCentavos(s.preco_centavos)} · ordem ${s.ordem}
                  · <span class="selo ${s.ativo ? '' : 'off'}">${s.ativo ? 'Ativo' : 'Inativo'}</span>
                </p>
              </div>
            </div>
            <div class="item-acoes">
              <button type="button" class="btn btn-fantasma btn-sm btn-editar-sabor">Editar</button>
              <button type="button" class="btn btn-perigo btn-sm btn-excluir-sabor">Excluir</button>
            </div>
          </article>
        `,
          )
          .join('')}
      </div>
    `
  }

  function telaKits() {
    return `
      <div class="painel-titulo">
        <div>
          <h1>Kits</h1>
          <p>Combos pra compartilhar na vitrine.</p>
        </div>
        <button type="button" class="btn btn-primario" id="btn-novo-kit">Novo kit</button>
      </div>
      ${
        !estado.kits.length
          ? `<div class="card vazio"><strong>Nenhum kit</strong>Monte o primeiro combo.</div>`
          : `<div class="lista">
        ${estado.kits
          .map(
            (k) => `
          <article class="item-lista" data-id="${k.id}">
            <div class="item-lista-info">
              <div>
                <h3>${escapar(k.nome)}</h3>
                <p class="item-meta">
                  ${formatarPrecoCentavos(k.preco_centavos)}
                  ${k.destaque ? ' · destaque' : ''}
                  · <span class="selo ${k.ativo ? '' : 'off'}">${k.ativo ? 'Ativo' : 'Inativo'}</span>
                </p>
              </div>
            </div>
            <div class="item-acoes">
              <button type="button" class="btn btn-fantasma btn-sm btn-editar-kit">Editar</button>
              <button type="button" class="btn btn-perigo btn-sm btn-excluir-kit">Excluir</button>
            </div>
          </article>
        `,
          )
          .join('')}
      </div>`
      }
    `
  }

  function telaConfig() {
    const c = estado.config || { numero_whatsapp: '', nome_exibido: 'POPÊ', slogan: '' }
    return `
      <div class="painel-titulo">
        <div>
          <h1>Configurações</h1>
          <p>WhatsApp, textos da marca e senha do admin.</p>
        </div>
      </div>
      <form class="card form-grid" id="form-config">
        <div>
          <label for="nome_exibido">Nome da marca</label>
          <input id="nome_exibido" name="nome_exibido" type="text" value="${escapar(c.nome_exibido)}" required />
        </div>
        <div>
          <label for="numero_whatsapp">WhatsApp (só números, com DDI)</label>
          <input id="numero_whatsapp" name="numero_whatsapp" type="text" value="${escapar(c.numero_whatsapp)}" placeholder="5511999999999" required />
        </div>
        <div>
          <label for="slogan">Slogan / título do hero</label>
          <input id="slogan" name="slogan" type="text" value="${escapar(c.slogan)}" />
        </div>
        <div class="form-acoes">
          <button class="btn btn-primario" type="submit">Salvar</button>
        </div>
      </form>
      <form class="card form-grid" id="form-senha" style="margin-top:1.25rem">
        <h2 style="margin:0;font-family:var(--fonte-marca);font-size:1.15rem">Alterar senha</h2>
        <p style="margin:0;color:var(--apagado);font-size:0.95rem">
          Outras sessões do mesmo admin serão encerradas. Esta permanece ativa.
        </p>
        <div>
          <label for="senha_atual">Senha atual</label>
          <input id="senha_atual" name="senha_atual" type="password" autocomplete="current-password" required />
        </div>
        <div>
          <label for="senha_nova">Nova senha</label>
          <input id="senha_nova" name="senha_nova" type="password" autocomplete="new-password" minlength="8" required />
        </div>
        <div>
          <label for="senha_confirma">Confirmar nova senha</label>
          <input id="senha_confirma" name="senha_confirma" type="password" autocomplete="new-password" minlength="8" required />
        </div>
        <div class="form-acoes">
          <button class="btn btn-primario" type="submit" id="btn-alterar-senha">Alterar senha</button>
        </div>
      </form>
    `
  }

  function modalSabor(sabor) {
    const editando = Boolean(sabor)
    const s = sabor || {
      nome: '',
      emoji: '🍿',
      descricao: '',
      preco_centavos: 2800,
      cor: '#E8A838',
      ativo: true,
      ordem: (estado.sabores.length || 0) + 1,
    }
    return `
      <div class="modal-fundo" id="modal-fundo">
        <div class="modal" role="dialog" aria-modal="true">
          <h2>${editando ? 'Editar sabor' : 'Novo sabor'}</h2>
          <form class="form-grid" id="form-sabor">
            <div class="form-grid duas">
              <div>
                <label for="nome">Nome</label>
                <input id="nome" name="nome" type="text" value="${escapar(s.nome)}" required />
              </div>
              <div>
                <label for="emoji">Emoji</label>
                <input id="emoji" name="emoji" type="text" value="${escapar(s.emoji)}" maxlength="8" />
              </div>
            </div>
            <div>
              <label for="descricao">Descrição</label>
              <textarea id="descricao" name="descricao">${escapar(s.descricao)}</textarea>
            </div>
            <div class="form-grid duas">
              <div>
                <label for="preco">Preço (R$)</label>
                <input id="preco" name="preco" type="number" min="0" step="0.01" value="${centavosParaReaisInput(s.preco_centavos)}" required />
              </div>
              <div>
                <label for="ordem">Ordem</label>
                <input id="ordem" name="ordem" type="number" value="${s.ordem}" />
              </div>
            </div>
            <div class="form-grid duas">
              <div>
                <label for="cor">Cor</label>
                <input id="cor" name="cor" type="color" value="${escapar(s.cor || '#E8A838')}" />
              </div>
              <div class="campo-check">
                <input id="ativo" name="ativo" type="checkbox" ${s.ativo ? 'checked' : ''} />
                <label for="ativo">Ativo no site</label>
              </div>
            </div>
            <div class="form-acoes">
              <button class="btn btn-primario" type="submit">Salvar</button>
              <button class="btn btn-fantasma" type="button" id="btn-cancelar-modal">Cancelar</button>
            </div>
          </form>
        </div>
      </div>
    `
  }

  function modalKit(kit) {
    const editando = Boolean(kit)
    const k = kit || {
      nome: '',
      descricao: '',
      preco_centavos: 5000,
      destaque: false,
      selo: '',
      ativo: true,
      ordem: (estado.kits.length || 0) + 1,
    }
    return `
      <div class="modal-fundo" id="modal-fundo">
        <div class="modal" role="dialog" aria-modal="true">
          <h2>${editando ? 'Editar kit' : 'Novo kit'}</h2>
          <form class="form-grid" id="form-kit">
            <div>
              <label for="nome">Nome</label>
              <input id="nome" name="nome" type="text" value="${escapar(k.nome)}" required />
            </div>
            <div>
              <label for="descricao">Descrição</label>
              <textarea id="descricao" name="descricao">${escapar(k.descricao)}</textarea>
            </div>
            <div class="form-grid duas">
              <div>
                <label for="preco">Preço (R$)</label>
                <input id="preco" name="preco" type="number" min="0" step="0.01" value="${centavosParaReaisInput(k.preco_centavos)}" required />
              </div>
              <div>
                <label for="ordem">Ordem</label>
                <input id="ordem" name="ordem" type="number" value="${k.ordem}" />
              </div>
            </div>
            <div class="form-grid duas">
              <div>
                <label for="selo">Selo (opcional)</label>
                <input id="selo" name="selo" type="text" value="${escapar(k.selo)}" placeholder="Mais pedido" />
              </div>
              <div class="campo-check">
                <input id="destaque" name="destaque" type="checkbox" ${k.destaque ? 'checked' : ''} />
                <label for="destaque">Destaque visual</label>
              </div>
            </div>
            <div class="campo-check" style="margin-top:0">
              <input id="ativo" name="ativo" type="checkbox" ${k.ativo ? 'checked' : ''} />
              <label for="ativo">Ativo no site</label>
            </div>
            <div class="form-acoes">
              <button class="btn btn-primario" type="submit">Salvar</button>
              <button class="btn btn-fantasma" type="button" id="btn-cancelar-modal">Cancelar</button>
            </div>
          </form>
        </div>
      </div>
    `
  }

  function fecharModal() {
    estado.modal = null
    render()
  }

  function abrirModalSabor(sabor) {
    estado.modal = { tipo: 'sabor', id: sabor?.id || null, html: modalSabor(sabor) }
    render()
  }

  function abrirModalKit(kit) {
    estado.modal = { tipo: 'kit', id: kit?.id || null, html: modalKit(kit) }
    render()
  }

  function ligarLogin() {
    const form = root.querySelector('#form-login')
    form?.addEventListener('submit', async (evento) => {
      evento.preventDefault()
      estado.erro = ''
      const email = form.email.value.trim()
      const senha = form.senha.value
      const botao = root.querySelector('#btn-entrar')
      botao.disabled = true
      botao.textContent = 'Entrando…'
      try {
        estado.sessao = await entrar(email, senha)
        irPara('sabores')
      } catch (erro) {
        estado.erro = mensagemErro(erro)
        render()
      }
    })
  }

  function ligarPainel(rota) {
    root.querySelector('#btn-sair')?.addEventListener('click', async () => {
      try {
        await sair()
        estado.sessao = null
        estado.ok = ''
        irPara('login')
      } catch (erro) {
        estado.erro = mensagemErro(erro)
        render()
      }
    })

    if (rota === 'sabores') {
      root.querySelector('#btn-novo-sabor')?.addEventListener('click', () => abrirModalSabor(null))
      root.querySelectorAll('.btn-editar-sabor').forEach((btn) => {
        btn.addEventListener('click', () => {
          const id = btn.closest('[data-id]')?.dataset.id
          abrirModalSabor(estado.sabores.find((s) => String(s.id) === String(id)))
        })
      })
      root.querySelectorAll('.btn-excluir-sabor').forEach((btn) => {
        btn.addEventListener('click', async () => {
          const id = btn.closest('[data-id]')?.dataset.id
          const sabor = estado.sabores.find((s) => String(s.id) === String(id))
          if (!sabor || !confirm(`Excluir “${sabor.nome}”?`)) return
          try {
            await excluirSabor(id)
            estado.sabores = estado.sabores.filter((s) => String(s.id) !== String(id))
            estado.ok = 'Sabor excluído.'
            estado.erro = ''
            render()
          } catch (erro) {
            estado.erro = mensagemErro(erro)
            render()
          }
        })
      })
    }

    if (rota === 'kits') {
      root.querySelector('#btn-novo-kit')?.addEventListener('click', () => abrirModalKit(null))
      root.querySelectorAll('.btn-editar-kit').forEach((btn) => {
        btn.addEventListener('click', () => {
          const id = btn.closest('[data-id]')?.dataset.id
          abrirModalKit(estado.kits.find((k) => String(k.id) === String(id)))
        })
      })
      root.querySelectorAll('.btn-excluir-kit').forEach((btn) => {
        btn.addEventListener('click', async () => {
          const id = btn.closest('[data-id]')?.dataset.id
          const kit = estado.kits.find((k) => String(k.id) === String(id))
          if (!kit || !confirm(`Excluir “${kit.nome}”?`)) return
          try {
            await excluirKit(id)
            estado.kits = estado.kits.filter((k) => String(k.id) !== String(id))
            estado.ok = 'Kit excluído.'
            estado.erro = ''
            render()
          } catch (erro) {
            estado.erro = mensagemErro(erro)
            render()
          }
        })
      })
    }

    if (rota === 'config') {
      root.querySelector('#form-config')?.addEventListener('submit', async (evento) => {
        evento.preventDefault()
        const form = evento.currentTarget
        try {
          estado.config = await salvarConfiguracao({
            nome_exibido: form.nome_exibido.value,
            numero_whatsapp: form.numero_whatsapp.value,
            slogan: form.slogan.value,
          })
          estado.ok = 'Configurações salvas.'
          estado.erro = ''
          render()
        } catch (erro) {
          estado.erro = mensagemErro(erro)
          render()
        }
      })

      root.querySelector('#form-senha')?.addEventListener('submit', async (evento) => {
        evento.preventDefault()
        const form = evento.currentTarget
        const atual = form.senha_atual.value
        const nova = form.senha_nova.value
        const confirma = form.senha_confirma.value
        estado.erro = ''
        estado.ok = ''
        if (nova !== confirma) {
          estado.erro = 'A confirmação não confere com a nova senha.'
          render()
          return
        }
        if (nova.length < 8) {
          estado.erro = 'A nova senha deve ter ao menos 8 caracteres.'
          render()
          return
        }
        const botao = root.querySelector('#btn-alterar-senha')
        if (botao) {
          botao.disabled = true
          botao.textContent = 'Alterando…'
        }
        try {
          await alterarSenha(atual, nova)
          estado.ok = 'Senha alterada com sucesso.'
          estado.erro = ''
          form.reset()
          render()
        } catch (erro) {
          estado.erro = mensagemErro(erro)
          render()
        }
      })
    }

    if (estado.modal?.tipo === 'sabor') {
      root.querySelector('#btn-cancelar-modal')?.addEventListener('click', fecharModal)
      root.querySelector('#modal-fundo')?.addEventListener('click', (e) => {
        if (e.target.id === 'modal-fundo') fecharModal()
      })
      root.querySelector('#form-sabor')?.addEventListener('submit', async (evento) => {
        evento.preventDefault()
        const form = evento.currentTarget
        try {
          const salvo = await salvarSabor(
            {
              nome: form.nome.value,
              emoji: form.emoji.value,
              descricao: form.descricao.value,
              preco_centavos: reaisParaCentavos(form.preco.value),
              cor: form.cor.value,
              ativo: form.ativo.checked,
              ordem: form.ordem.value,
            },
            estado.modal.id,
          )
          if (estado.modal.id) {
            estado.sabores = estado.sabores.map((s) =>
              String(s.id) === String(salvo.id) ? salvo : s,
            )
          } else {
            estado.sabores = [...estado.sabores, salvo].sort((a, b) => a.ordem - b.ordem)
          }
          estado.modal = null
          estado.ok = 'Sabor salvo.'
          estado.erro = ''
          render()
        } catch (erro) {
          estado.erro = mensagemErro(erro)
          render()
        }
      })
    }

    if (estado.modal?.tipo === 'kit') {
      root.querySelector('#btn-cancelar-modal')?.addEventListener('click', fecharModal)
      root.querySelector('#modal-fundo')?.addEventListener('click', (e) => {
        if (e.target.id === 'modal-fundo') fecharModal()
      })
      root.querySelector('#form-kit')?.addEventListener('submit', async (evento) => {
        evento.preventDefault()
        const form = evento.currentTarget
        try {
          const salvo = await salvarKit(
            {
              nome: form.nome.value,
              descricao: form.descricao.value,
              preco_centavos: reaisParaCentavos(form.preco.value),
              destaque: form.destaque.checked,
              selo: form.selo.value,
              ativo: form.ativo.checked,
              ordem: form.ordem.value,
            },
            estado.modal.id,
          )
          if (estado.modal.id) {
            estado.kits = estado.kits.map((k) =>
              String(k.id) === String(salvo.id) ? salvo : k,
            )
          } else {
            estado.kits = [...estado.kits, salvo].sort((a, b) => a.ordem - b.ordem)
          }
          estado.modal = null
          estado.ok = 'Kit salvo.'
          estado.erro = ''
          render()
        } catch (erro) {
          estado.erro = mensagemErro(erro)
          render()
        }
      })
    }
  }

  window.addEventListener('hashchange', async () => {
    estado.erro = ''
    estado.ok = ''
    estado.modal = null
    if (!ordsConfigurado) {
      render()
      return
    }
    if (!estado.sessao && rotasAuth.has(rotaAtual())) {
      irPara('login')
      return
    }
    if (estado.sessao && rotaAtual() === 'login') {
      irPara('sabores')
      return
    }
    if (estado.sessao && rotasAuth.has(rotaAtual())) {
      estado.carregando = true
      render()
      try {
        await carregarDadosRota()
      } catch (erro) {
        estado.erro = mensagemErro(erro)
      } finally {
        estado.carregando = false
        render()
      }
      return
    }
    render()
  })

  await bootstrap()
}
