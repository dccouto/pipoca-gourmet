import { ordsConfigurado } from './lib/ords.js'
import { formatarPrecoCentavos } from './lib/erros.js'
import { CONFIG_FALLBACK, KITS_FALLBACK, SABORES_FALLBACK } from './dados/fallback.js'
import { listarSabores } from './servicos/sabores.js'
import { listarKits } from './servicos/kits.js'
import { getConfiguracao } from './servicos/configuracao.js'

function linkWhatsApp(whatsapp, sabor, nomeMarca) {
  const texto = encodeURIComponent(
    `Oi, ${nomeMarca}! Quero pedir o sabor *${sabor.nome}* (${formatarPrecoCentavos(sabor.preco_centavos)}). 🍿`,
  )
  return `https://wa.me/${whatsapp}?text=${texto}`
}

function linkWhatsAppGeral(whatsapp, nomeMarca) {
  const texto = encodeURIComponent(`Oi, ${nomeMarca}! Quero pedir pipoca gourmet 🍿`)
  return `https://wa.me/${whatsapp}?text=${texto}`
}

function svgPipoca(nomeMarca) {
  const rotulo = (nomeMarca || 'POPÊ').slice(0, 8)
  return `
    <svg class="hero-art" viewBox="0 0 640 520" aria-hidden="true">
      <defs>
        <linearGradient id="balde" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stop-color="#FF4D6D"/>
          <stop offset="100%" stop-color="#E11D48"/>
        </linearGradient>
        <linearGradient id="pipoca" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#FFF8DC"/>
          <stop offset="55%" stop-color="#FFE566"/>
          <stop offset="100%" stop-color="#F5C842"/>
        </linearGradient>
      </defs>
      <ellipse cx="320" cy="470" rx="180" ry="18" fill="#2A1810" opacity=".12"/>
      <path d="M170 280 L190 470 Q320 500 450 470 L470 280 Z" fill="url(#balde)"/>
      <path d="M185 290 L200 450 Q320 475 440 450 L455 290 Z" fill="#FF6B85" opacity=".35"/>
      <rect x="155" y="255" width="330" height="40" rx="8" fill="#FF2D55"/>
      <text x="320" y="283" text-anchor="middle" font-family="Fredoka, sans-serif" font-weight="700" font-size="22" fill="#FFF8E7">${rotulo}</text>
      <g class="pop-cluster">
        <ellipse class="kernel k1" cx="250" cy="200" rx="38" ry="32" fill="url(#pipoca)"/>
        <ellipse class="kernel k2" cx="310" cy="160" rx="42" ry="36" fill="url(#pipoca)"/>
        <ellipse class="kernel k3" cx="370" cy="195" rx="36" ry="30" fill="url(#pipoca)"/>
        <ellipse class="kernel k4" cx="280" cy="130" rx="34" ry="28" fill="url(#pipoca)"/>
        <ellipse class="kernel k5" cx="340" cy="115" rx="40" ry="34" fill="url(#pipoca)"/>
        <ellipse class="kernel k6" cx="220" cy="155" rx="30" ry="26" fill="url(#pipoca)"/>
        <ellipse class="kernel k7" cx="400" cy="150" rx="32" ry="28" fill="url(#pipoca)"/>
        <ellipse class="kernel k8" cx="300" cy="90" rx="28" ry="24" fill="url(#pipoca)"/>
        <ellipse class="kernel k9" cx="360" cy="75" rx="26" ry="22" fill="url(#pipoca)"/>
        <circle cx="265" cy="175" r="6" fill="#FFF" opacity=".55"/>
        <circle cx="330" cy="140" r="8" fill="#FFF" opacity=".45"/>
        <circle cx="385" cy="175" r="5" fill="#FFF" opacity=".5"/>
      </g>
    </svg>
  `
}

async function carregarDados() {
  if (!ordsConfigurado) {
    return {
      sabores: SABORES_FALLBACK,
      kits: KITS_FALLBACK,
      config: CONFIG_FALLBACK,
      aviso: 'Oracle ORDS ainda não configurado — mostrando dados de exemplo.',
    }
  }

  try {
    const [sabores, kits, config] = await Promise.all([
      listarSabores({ soAtivos: true }),
      listarKits({ soAtivos: true }),
      getConfiguracao(),
    ])
    return {
      sabores: sabores.length ? sabores : SABORES_FALLBACK,
      kits: kits.length ? kits : KITS_FALLBACK,
      config: config || CONFIG_FALLBACK,
      aviso: '',
    }
  } catch (erro) {
    return {
      sabores: SABORES_FALLBACK,
      kits: KITS_FALLBACK,
      config: CONFIG_FALLBACK,
      aviso: erro instanceof Error ? erro.message : 'Não foi possível carregar do Oracle ORDS.',
    }
  }
}

function renderizarKit(kit) {
  return `
    <article class="kit ${kit.destaque ? 'destaque' : ''}">
      ${kit.selo ? `<p class="kit-selo">${kit.selo}</p>` : ''}
      <h3>${kit.nome}</h3>
      <p>${kit.descricao}</p>
      <p class="kit-preco">${formatarPrecoCentavos(kit.preco_centavos)}</p>
    </article>
  `
}

export async function montarApp(root) {
  root.innerHTML = `
    <div class="carregando-site">
      <p>Estourando pipoca…</p>
    </div>
  `

  const { sabores, kits, config, aviso } = await carregarDados()
  const nomeMarca = config.nome_exibido || 'POPÊ'
  const whatsapp = config.numero_whatsapp || CONFIG_FALLBACK.numero_whatsapp
  let saborAtivo = sabores[0]?.id

  root.innerHTML = `
    <div class="bg-blobs" aria-hidden="true">
      <span class="blob b1"></span>
      <span class="blob b2"></span>
      <span class="blob b3"></span>
      <div class="confete"></div>
    </div>

    ${aviso ? `<div class="aviso-banner" role="status">${aviso}</div>` : ''}

    <header class="topo">
      <a class="logo" href="#topo" aria-label="${nomeMarca} início">
        <span class="logo-mark" aria-hidden="true">🍿</span>
        <span class="logo-word">${nomeMarca}</span>
      </a>
      <nav class="nav">
        <a href="#sabores">Sabores</a>
        <a href="#kits">Kits</a>
        <a href="#pedido" class="nav-cta">Pedir</a>
      </nav>
    </header>

    <main id="topo">
      <section class="hero">
        <div class="hero-copy">
          <p class="brand-hero">${nomeMarca}</p>
          <h1>${config.slogan || 'Pipoca gourmet que estoura de alegria'}</h1>
          <p class="hero-lead">Sabores artesanais, fresquinhos e irresistíveis — feitos pra transformar qualquer momento em festa.</p>
          <div class="hero-acoes">
            <a class="btn btn-primario" href="#sabores">Ver sabores</a>
            <a class="btn btn-fantasma" href="${linkWhatsAppGeral(whatsapp, nomeMarca)}" target="_blank" rel="noopener">Pedir no WhatsApp</a>
          </div>
        </div>
        <div class="hero-visual">
          ${svgPipoca(nomeMarca)}
        </div>
      </section>

      <section class="secao sabores" id="sabores">
        <div class="secao-cabeca">
          <h2>Escolha seu estouro</h2>
          <p>Toque num sabor e monte o pedido perfeito.</p>
        </div>
        <div class="sabores-grade" role="list">
          ${sabores
            .map(
              (s) => `
            <button
              type="button"
              class="sabor ${String(s.id) === String(saborAtivo) ? 'ativo' : ''}"
              data-sabor="${s.id}"
              role="listitem"
              style="--sabor-cor: ${s.cor}"
            >
              <span class="sabor-emoji" aria-hidden="true">${s.emoji}</span>
              <span class="sabor-nome">${s.nome}</span>
              <span class="sabor-desc">${s.descricao}</span>
              <span class="sabor-preco">${formatarPrecoCentavos(s.preco_centavos)}</span>
            </button>
          `,
            )
            .join('')}
        </div>
        ${
          sabores[0]
            ? `
        <div class="sabor-pedido" id="pedido-rapido">
          <p><strong id="sabor-selecionado">${sabores[0].nome}</strong> no saquinho — ${formatarPrecoCentavos(sabores[0].preco_centavos)}</p>
          <a class="btn btn-primario" id="btn-pedir-sabor" href="${linkWhatsApp(whatsapp, sabores[0], nomeMarca)}" target="_blank" rel="noopener">Quero esse!</a>
        </div>`
            : '<p class="vazio-publico">Nenhum sabor ativo no momento.</p>'
        }
      </section>

      <section class="secao kits" id="kits">
        <div class="secao-cabeca">
          <h2>Kits pra compartilhar</h2>
          <p>Mais pipoca, mais sorrisos, menos decisão.</p>
        </div>
        <div class="kits-lista">
          ${kits.length ? kits.map(renderizarKit).join('') : '<p class="vazio-publico">Nenhum kit ativo no momento.</p>'}
        </div>
      </section>

      <section class="secao pedido" id="pedido">
        <div class="pedido-box">
          <h2>Pronto pra estourar?</h2>
          <p>Manda um oi no WhatsApp e a gente monta seu pedido com carinho (e muito tempero).</p>
          <a class="btn btn-grande" href="${linkWhatsAppGeral(whatsapp, nomeMarca)}" target="_blank" rel="noopener">
            Pedir no WhatsApp
          </a>
        </div>
      </section>
    </main>

    <footer class="rodape">
      <p class="rodape-marca">${nomeMarca}</p>
      <p>Pipoca gourmet artesanal · Feita com alegria</p>
      <p class="rodape-aviso"><a href="/admin/">Área administrativa</a></p>
    </footer>
  `

  const botoes = root.querySelectorAll('.sabor')
  const btnPedir = root.querySelector('#btn-pedir-sabor')
  const pedidoRapido = root.querySelector('#pedido-rapido')

  botoes.forEach((btn) => {
    btn.addEventListener('click', () => {
      saborAtivo = btn.dataset.sabor
      const sabor = sabores.find((s) => String(s.id) === String(saborAtivo))
      if (!sabor || !pedidoRapido || !btnPedir) return
      botoes.forEach((b) => b.classList.toggle('ativo', String(b.dataset.sabor) === String(saborAtivo)))
      pedidoRapido.querySelector('p').innerHTML =
        `<strong id="sabor-selecionado">${sabor.nome}</strong> no saquinho — ${formatarPrecoCentavos(sabor.preco_centavos)}`
      btnPedir.href = linkWhatsApp(whatsapp, sabor, nomeMarca)
      btnPedir.classList.add('pop')
      window.setTimeout(() => btnPedir.classList.remove('pop'), 400)
    })
  })
}
