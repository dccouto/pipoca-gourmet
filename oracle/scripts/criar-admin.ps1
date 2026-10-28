param(
  [string]$Email = '',
  [string]$Senha = '',
  [string]$Nome = 'Admin',
  [string]$SecretsFile = '',
  [string]$ProxyBase = 'https://pope-ords-proxy.dccouto.workers.dev/ords'
)

<#
.SYNOPSIS
  Cria ou atualiza um admin em usuarios_admin (hash sha256$salt$hex) via REST SQL/ORDS.
  Não precisa abrir o OCI Console nem o SQL Developer.

.EXAMPLE
  .\criar-admin.ps1
  # usa ADMIN_APP_EMAIL e ADMIN_APP_PASSWORD de .oci-secrets.env

.EXAMPLE
  .\criar-admin.ps1 -Email 'novo@exemplo.com' -Senha 'SenhaForte123!'
#>

$ErrorActionPreference = 'Stop'

if (-not $SecretsFile) {
  $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
  $SecretsFile = Join-Path $repoRoot '.oci-secrets.env'
}

function Get-Secret([string]$Key) {
  $line = Select-String -Path $SecretsFile -Pattern "^$Key=" | Select-Object -First 1
  if (-not $line) { throw "Chave $Key não encontrada em $SecretsFile" }
  return $line.Line.Substring("$Key=".Length)
}

function Escape-SqlLiteral([string]$Value) {
  return ($Value -replace "'", "''")
}

if (-not $Email) { $Email = (Get-Secret 'ADMIN_APP_EMAIL').Trim() }
if (-not $Senha) { $Senha = (Get-Secret 'ADMIN_APP_PASSWORD') }

if (-not $Email -or -not $Senha) {
  throw 'Informe -Email e -Senha, ou defina ADMIN_APP_EMAIL / ADMIN_APP_PASSWORD em .oci-secrets.env'
}

$emailSql = Escape-SqlLiteral ($Email.Trim().ToLowerInvariant())
$senhaSql = Escape-SqlLiteral $Senha
$nomeSql = Escape-SqlLiteral $Nome

$sql = @"
DECLARE
  l_email VARCHAR2(320) := '$emailSql';
  l_senha VARCHAR2(255) := '$senhaSql';
  l_nome  VARCHAR2(120) := '$nomeSql';
  l_salt  VARCHAR2(64);
  l_hash  VARCHAR2(255);
BEGIN
  l_salt := LOWER(RAWTOHEX(SYS_GUID()));
  l_hash := 'sha256$' || l_salt || '$' || auth_util.sha256_hex(l_salt || l_senha);

  MERGE INTO usuarios_admin u
  USING (SELECT l_email AS email FROM dual) s
     ON (LOWER(u.email) = s.email)
  WHEN MATCHED THEN
    UPDATE SET
      senha_hash    = l_hash,
      nome          = NVL(NULLIF(TRIM(l_nome), ''), u.nome),
      ativo         = 1,
      atualizado_em = SYSTIMESTAMP
  WHEN NOT MATCHED THEN
    INSERT (email, senha_hash, nome, ativo)
    VALUES (s.email, l_hash, NVL(NULLIF(TRIM(l_nome), ''), 'Admin'), 1);

  COMMIT;
END;
/
"@

$tmp = Join-Path $env:TEMP ("pipocag-criar-admin-{0}.sql" -f [guid]::NewGuid().ToString('N'))
try {
  Set-Content -Path $tmp -Value $sql -Encoding UTF8
  Write-Host "Criando/atualizando admin: $Email"
  & (Join-Path $PSScriptRoot 'apply-sql.ps1') -SqlFile $tmp -SecretsFile $SecretsFile
} finally {
  Remove-Item -Path $tmp -Force -ErrorAction SilentlyContinue
}

Write-Host "Testando login em $ProxyBase/pipocag/auth/login ..."
$loginUri = "$($ProxyBase.TrimEnd('/'))/pipocag/auth/login"
try {
  $r = Invoke-WebRequest -Uri $loginUri -Method POST `
    -Headers @{ email = $Email.Trim(); senha = $Senha } `
    -UseBasicParsing -TimeoutSec 45
  if ($r.Content -notmatch '"token"') {
    throw "Login sem token. Resposta: $($r.Content)"
  }
  Write-Host 'Login OK (token recebido).'
} catch {
  # Fallback Node (alguns ambientes Windows falham no TLS do Invoke-WebRequest)
  $env:E = $Email.Trim()
  $env:S = $Senha
  $env:U = $loginUri
  $nodeOut = node --input-type=module -e "const r=await fetch(process.env.U,{method:'POST',headers:{email:process.env.E,senha:process.env.S}}); const t=await r.text(); if(!t.includes('token')) { console.error(t); process.exit(1)}; console.log('Login OK (token recebido).')"
  Remove-Item Env:E, Env:S, Env:U -ErrorAction SilentlyContinue
  if ($LASTEXITCODE -ne 0) { throw "Falha no login após criar admin: $_ / $nodeOut" }
  Write-Host $nodeOut
}

Write-Host ''
Write-Host 'Pronto. Entre em https://dccouto.github.io/pipoca-gourmet/admin/ com este e-mail e a senha usada.'
