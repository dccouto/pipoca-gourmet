# POPÊ — Pipoca Gourmet

Site de vendas de pipoca gourmet + painel admin.

**Front:** Vite MPA (vitrine `/` + admin `/admin/`)  
**Backend:** Oracle Autonomous Database Always Free + ORDS (`us-ashburn-1`)  
Supabase foi removido; o front fala só com Oracle ORDS.

Detalhes da infra: [`oracle/README-ORACLE.md`](oracle/README-ORACLE.md) · Proxy prod: [`cloudflare/README.md`](cloudflare/README.md).

## Rodar local

```powershell
npm install
copy .env.example .env
# .env (sem BOM UTF-8):
#   VITE_ORDS_BASE_URL=/ords
#   ORDS_PROXY_TARGET=https://XXXX-pipocag.adb.us-ashburn-1.oraclecloudapps.com
npm run dev
```

- Vitrine: http://localhost:5173/
- Admin: http://localhost:5173/admin/

O proxy Vite (`ORDS_PROXY_TARGET`) remove `Origin`/`Referer` ao encaminhar — sem isso o ADB responde **403 ORDS-13002**. Sem `.env`, a vitrine usa dados de exemplo.

## Login admin

Use `ADMIN_APP_EMAIL` e `ADMIN_APP_PASSWORD` de `.oci-secrets.env` (nunca commitados).

## Oracle (já provisionado)

| Recurso | Valor |
|--------|--------|
| ADB | `PipocaGourmet` / DB `PIPOCAG` |
| Auth | `POST /ords/pipocag/auth/login` (headers `email`, `senha`) |
| API | `/ords/pipocag/api/sabores`, `/kits`, `/config` |
| Secrets | `.oci-secrets.env` (gitignored) |

```powershell
powershell -File oracle/scripts/apply-sql.ps1 -SqlFile oracle/sql/003_ords_catalog.sql -SecretsFile .oci-secrets.env
```

## Produção (CORS / ORDS-13002)

O ORDS do ADB **rejeita** `Origin` mesmo com CORS liberado no módulo. GitHub Pages puro **não** consegue falar com o ADB no browser.

Escolha um caminho:

| Caminho | `VITE_ORDS_BASE_URL` | Onde |
|---------|----------------------|------|
| **A) Worker + GitHub Pages** | URL do Worker (`…workers.dev/ords`) | Secret Actions `VITE_ORDS_BASE_URL` |
| **B) Cloudflare Pages** (recomendado) | `/ords` (same-origin) | Workflow + var `ORDS_PROXY_TARGET` no Pages |

Passo a passo: [`cloudflare/README.md`](cloudflare/README.md).

### GitHub Pages (workflow atual)

`.github/workflows/pages.yml` injeta `secrets.VITE_ORDS_BASE_URL`.  
**Não** use a URL crua do ADB — use a do Worker (opção A).

### Cloudflare Pages (opcional)

`.github/workflows/cloudflare-pages.yml` — ative com `ENABLE_CLOUDFLARE_PAGES=true` + secrets Cloudflare.

## Painel

- Sabores e kits (CRUD, ativo/inativo)
- Configurações (WhatsApp, marca, slogan)

## Build

```bash
npm run build
```

Saída em `dist/`. Push em `main` dispara o workflow de Pages.
