param([switch]$OpenGame)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$env:ORBIT_API_URL = 'http://127.0.0.1:8788'
$env:ORBIT_WEB_DIR = Join-Path $projectRoot 'build\candidate\web'
if ($OpenGame) {
    $executable = Join-Path $projectRoot 'build\candidate\OrbitBreaker.exe'
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw 'Build the candidate before opening the game.' }
    Start-Process -FilePath $executable -WorkingDirectory $projectRoot -WindowStyle Normal
}
Write-Host 'Local web: http://127.0.0.1:8788/game/  (Ctrl+C stops the local service)'
& node --env-file-if-exists=server/.env server/gateway.mjs
if ($LASTEXITCODE -ne 0) { throw 'Online service failed.' }
