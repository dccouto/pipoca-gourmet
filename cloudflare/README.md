# Proxy ORDS (Cloudflare)

O Oracle ADB ORDS rejeita requests com header `Origin` (**ORDS-13002**) e o preflight `OPTIONS` não devolve CORS. O browser em GitHub Pages **não** pode chamar a URL do ADB diretamente.

Este diretório traz um proxy mínimo que:

1. Encaminha `/ords/*` para `ORDS_PROXY_TARGET`
2. **Remove** `Origin` e `Referer` antes de falar com o ADB
3. Responde `OPTIONS` com CORS (modo Worker separado)

## Opção A — Worker + GitHub Pages (mínimo)

Mantém o site no GitHub Pages; o front chama o Worker.

```bash
npx wrangler login
npx wrangler secret put ORDS_PROXY_TARGET
# valor: https://XXXX-pipocag.adb.us-ashburn-1.oraclecloudapps.com
# (sem /ords no final)

npx wrangler secret put CORS_ALLOW_ORIGINS
# valor: https://dccouto.github.io,http://localhost:5173

npx wrangler deploy
```

No GitHub → Settings → Secrets → Actions:

| Secret | Valor |
|--------|--------|
| `VITE_ORDS_BASE_URL` | `https://pope-ords-proxy.<sua-conta>.workers.dev/ords` |

Push em `main` republica o Pages com essa base.

## Opção B — Cloudflare Pages (same-origin, recomendado)

Site e `/ords` no **mesmo host** → `VITE_ORDS_BASE_URL=/ords`.

1. Crie o projeto Pages `pipoca-gourmet` (ou deixe o wrangler criar no 1º deploy).
2. Em **Settings → Environment variables** do projeto Pages (Production):
   - `ORDS_PROXY_TARGET` = `https://XXXX-pipocag.adb....oraclecloudapps.com`
3. No GitHub:
   - Secrets: `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`
   - Variable: `ENABLE_CLOUDFLARE_PAGES=true`
4. Workflow: `.github/workflows/cloudflare-pages.yml`

A Function `functions/ords/[[path]].js` cobre `/ords/*`.

## Local (já funciona sem Cloudflare)

```
VITE_ORDS_BASE_URL=/ords
ORDS_PROXY_TARGET=https://XXXX-pipocag.adb....oraclecloudapps.com
npm run dev
```

O Vite remove `Origin`/`Referer` no proxy — espelha o Worker.
