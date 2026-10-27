param(
  [Parameter(Mandatory = $true)][string]$SqlFile,
  [string]$SecretsFile = ''
)

if (-not $SecretsFile) {
  $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
  $SecretsFile = Join-Path $repoRoot '.oci-secrets.env'
}

$ErrorActionPreference = 'Stop'

function Get-Secret([string]$Key) {
  $line = Select-String -Path $SecretsFile -Pattern "^$Key=" | Select-Object -First 1
  if (-not $line) { throw "Chave $Key não encontrada em $SecretsFile" }
  return $line.Line.Substring("$Key=".Length)
}

$ords = (Get-Secret 'ADB_ORDS_URL').TrimEnd('/')
$user = 'PIPOCAG'
$pass = Get-Secret 'PIPOCAG_SCHEMA_PASSWORD'
$sql = Get-Content -Path $SqlFile -Raw -Encoding UTF8

$pair = "${user}:${pass}"
$basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))

Write-Host "Aplicando $SqlFile em $ords/pipocag/_/sql ..."

$response = Invoke-WebRequest -Uri "$ords/pipocag/_/sql" -Method POST `
  -Headers @{ Authorization = "Basic $basic" } `
  -ContentType 'application/sql; charset=utf-8' `
  -Body $sql `
  -UseBasicParsing

$json = $response.Content | ConvertFrom-Json
$json | ConvertTo-Json -Depth 8
if ($json.items) {
  $erros = @($json.items | Where-Object { $_.errorCode -or $_.errorMessage -or ($_.result -and $_.result.errorCode) })
  if ($erros.Count -gt 0) {
    Write-Error "SQL com erros ($($erros.Count))."
    exit 1
  }
}
Write-Host 'OK'
