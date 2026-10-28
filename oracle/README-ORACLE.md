# PipocaGourmet — Oracle Cloud (DB + Auth + API)

Front estático no **GitHub Pages**. Banco, autenticação e catálogo na **Oracle Cloud Free Tier** (`us-ashburn-1`).  
Migração do Supabase **concluída** — o front usa apenas ORDS (`src/lib/ords.js` + `src/servicos/*`).

## Provisionado

| Recurso | Valor |
|--------|--------|
| ADB Always Free (ATP) | Display `PipocaGourmet`, DB name `PIPOCAG` |
| ORDS | Schema REST `pipocag` |
| Object Storage | Bucket privado `pipoca-gourmet` |

Secrets: `.oci-secrets.env` e cópia em `~\.oci\pipoca-gourmet.env` (gitignored). Wallet em `oracle/wallet/` (gitignored).

## Endpoints

### Auth
- `GET  {ORDS}/pipocag/auth/ping`
- `POST {ORDS}/pipocag/auth/login` — headers `email`, `senha` → `{ token, expira_horas, usuario_id }`
- `POST {ORDS}/pipocag/auth/senha` — `Authorization: Bearer` + headers `senha_atual`, `senha_nova` (percent-encoded) → `{ ok: true }`

### Catálogo (público)
- `GET {ORDS}/pipocag/api/sabores?ativos=1`
- `GET {ORDS}/pipocag/api/kits?ativos=1`
- `GET {ORDS}/pipocag/api/config`

### Catálogo (admin — `Authorization: Bearer <token>`)
Campos de escrita vão em **headers** (valores `encodeURIComponent` / UTF-8).
- `POST/PUT/DELETE` em `/api/sabores` e `/api/sabores/:id`
- `POST/PUT/DELETE` em `/api/kits` e `/api/kits/:id`
- `PUT /api/config`

## SQL versionado

| Arquivo | Conteúdo |
|---------|----------|
| `oracle/sql/001_schema_pipocag.sql` | Usuário + tabelas |
| `oracle/sql/002_ords_auth.sql` | Pacote auth + módulo ORDS |
| `oracle/sql/003_ords_catalog.sql` | Pacote catálogo + seed + módulo `api` |
| `oracle/sql/004_decode_headers.sql` | Decode UTF-8 dos headers |
| `oracle/sql/005_cors_fix.sql` | Origins `*` (legado; ADB ainda rejeita Origin) |
| `oracle/sql/006_cors_query.sql` | Diagnóstico `user_ords_modules` |
| `oracle/sql/007_cors_origins.sql` | Origins explícitas (localhost + GitHub Pages) |
| `oracle/sql/008_auth_senha.sql` | `auth_util.alterar_senha_json` + `POST /auth/senha` |

Aplicar:

```powershell
powershell -File oracle/scripts/apply-sql.ps1 `
  -SqlFile oracle/sql/003_ords_catalog.sql `
  -SecretsFile .oci-secrets.env
```

## Front local (recomendado)

```
VITE_ORDS_BASE_URL=/ords
ORDS_PROXY_TARGET=https://….adb.us-ashburn-1.oraclecloudapps.com
```

O Vite encaminha `/ords` e **remove** `Origin`/`Referer` — sem isso o ADB responde `ORDS-13002 Forbidden` no browser.

## Produção

### CORS / bloqueio (causa raiz)

Mesmo com `ORDS.SET_MODULE_ORIGINS_ALLOWED(..., '*')` ou lista explícita, requests **com** header `Origin` ao ORDS do ADB retornam **403 ORDS-13002**. Preflight `OPTIONS` também não devolve `Access-Control-Allow-*`.

O browser em GitHub Pages **não** pode chamar o ADB diretamente.

### Mitigação (no repo)

Proxy Cloudflare que remove `Origin`/`Referer` — ver [`cloudflare/README.md`](../cloudflare/README.md).

| Opção | `VITE_ORDS_BASE_URL` | Deploy |
|-------|----------------------|--------|
| Worker + GitHub Pages | `https://pope-ords-proxy.…workers.dev/ords` | Secret Actions + `wrangler deploy` |
| Cloudflare Pages | `/ords` | Function `functions/ords/` + `ORDS_PROXY_TARGET` |

Local continua com proxy Vite (`ORDS_PROXY_TARGET` + `VITE_ORDS_BASE_URL=/ords`).

## Teste rápido

```powershell
$ords = (Select-String -Path .\.oci-secrets.env -Pattern '^ADB_ORDS_URL=').Line.Split('=',2)[1].TrimEnd('/')
curl.exe -s "$ords/pipocag/auth/ping"
curl.exe -s "$ords/pipocag/api/sabores?ativos=1"
# Com Origin (deve falhar no ADB atual):
curl.exe -s -D - -o NUL "$ords/pipocag/api/config" -H "Origin: http://localhost:5173"
```
