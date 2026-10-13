param([string]$GodotPath = 'D:\Antigravity\GodotGameProject\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$baseline = Get-Content -LiteralPath (Join-Path $projectRoot 'art_source/baseline/hashes.json') -Raw -Encoding UTF8 | ConvertFrom-Json
# The 3.17 render assertion now measures the outlined event icon, replacing a solid-marker pixel.
$allowed = @('main.gd','item_catalog.gd','item_icon.gd','ui_glyph.gd','export_presets.cfg','project.godot','test_viewport.gd','menu_flow.gd','test_uiux.gd','test_feedback_v317.gd')
$checked = 0
$sha256 = [System.Security.Cryptography.SHA256]::Create()
foreach ($entry in $baseline) {
    if ((Split-Path -Leaf $entry.Path) -in $allowed) { continue }
    $actual = [BitConverter]::ToString($sha256.ComputeHash([IO.File]::ReadAllBytes($entry.Path))).Replace('-','')
    if ($actual -ne $entry.Hash) { throw "Protected baseline changed: $($entry.Path)" }
    $checked++
}
$sha256.Dispose()
Write-Host "Protected source/fixtures: $checked hashes unchanged."
$result = @(& $GodotPath --path $projectRoot --audio-driver Dummy --resolution 1600x900 --script res://tests/test_art.gd -- --performance 2>&1)
$code = $LASTEXITCODE
$result | Set-Content -LiteralPath (Join-Path $projectRoot 'artifacts/candidate/art/art-test.log') -Encoding UTF8
$result | ForEach-Object { Write-Host $_ }
$message = $result -join "`n"
if ($code -ne 0 -or $message -match '(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):' -or $message -notmatch 'ART SELF-CHECK: (\d+) / \1 assertions passed') { throw 'Art contract or render validation failed.' }
$performance = Get-Content -LiteralPath (Join-Path $projectRoot 'artifacts/candidate/art/final/moving-performance.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($trial in $performance) {
    if ($trial.p95_ms -gt 16.7 -or $trial.p99_ms -gt 25 -or $trial.min_enemies -lt 240 -or $trial.min_shots -lt 240) { throw "Moving performance target failed: trial $($trial.trial)" }
}
Write-Host 'Art contracts, rendered fixtures and three moving performance trials passed. Browser remains a separate gate.'
