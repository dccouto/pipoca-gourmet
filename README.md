# POPÊ — Pipoca Gourmet

Site de vendas de pipoca gourmet + painel admin.

**Front:** estático (Vite) → GitHub Pages  
**Backend:** Oracle Autonomous Database Always Free + ORDS (`us-ashburn-1`)  
Supabase foi removido; o front fala só com Oracle ORDS.

Detalhes da infra: [`oracle/README-ORACLE.md`](oracle/README-ORACLE.md).

## Rodar local

```powershell
npm install
copy .env.example .env
# .env recomendado (sem BOM UTF-8):
#   VITE_ORDS_BASE_URL=/ords
#   ORDS_PROXY_TARGET=https://XXXX-pipocag.adb.us-ashburn-1.oraclecloudapps.com
npm run dev
```

- Vitrine: http://localhost:5173/
- Admin: http://localhost:5173/admin/

O proxy Vite (`ORDS_PROXY_TARGET`) evita o bloqueio CORS do ORDS no browser (remove `Origin`/`Referer` ao encaminhar). Sem `.env`, a vitrine usa dados de exemplo.

## Login admin

Use `ADMIN_APP_EMAIL` e `ADMIN_APP_PASSWORD` de `.oci-secrets.env` (nunca commitados).

## Oracle (já provisionado)

| Recurso | Valor |
|--------|--------|
| ADB | `PipocaGourmet` / DB `PIPOCAG` |
| Auth | `POST /ords/pipocag/auth/login` (headers `email`, `senha`) |
| API | `/ords/pipocag/api/sabores`, `/kits`, `/config` |
| Secrets | `.oci-secrets.env` (gitignored) |

Aplicar/atualizar SQL no ADB:

```powershell
powershell -File oracle/scripts/apply-sql.ps1 -SqlFile oracle/sql/003_ords_catalog.sql -SecretsFile .oci-secrets.env
```

## GitHub Pages (produção)

No repositório, configure o secret `VITE_ORDS_BASE_URL` com a URL **pública completa** do ORDS (ex.: `https://XXXX-pipocag.adb.us-ashburn-1.oraclecloudapps.com/ords`).

**Bloqueio CORS conhecido:** o ORDS do ADB rejeita requests com header `Origin` (ORDS-13002) e o preflight `OPTIONS` não devolve headers CORS. A vitrine pública (GET simples) pode falhar no browser; mutações admin com `Authorization` certamente falham cross-origin.

**Workarounds:** manter o proxy local para admin; em produção, usar um proxy same-origin (Cloudflare Worker, Functions, etc.) ou hospedar o front atrás do mesmo host que encaminhe `/ords`.

## Painel

- Sabores e kits (CRUD, ativo/inativo)
- Configurações (WhatsApp, marca, slogan)

## Build

```bash
npm run build
```

Saída em `dist/` (vitrine + `/admin/`). O workflow `.github/workflows/pages.yml` publica no push em `main`.
