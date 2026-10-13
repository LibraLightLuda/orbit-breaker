param([string]$GodotPath = 'D:\Antigravity\GodotGameProject\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$evidence = Join-Path $projectRoot 'artifacts\candidate\motion'
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'motion_review.html') -Destination (Join-Path $evidence 'index.html')
$output = @(& $GodotPath --path $projectRoot --resolution 1280x720 --audio-driver Dummy --script res://tests/test_motion.gd 2>&1)
$code = $LASTEXITCODE
$output | Set-Content -LiteralPath (Join-Path $evidence 'motion.log') -Encoding UTF8
$message = $output -join "`n"
if ($code -ne 0 -or $message -match '(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):' -or $message -notmatch 'MOTION SELF-CHECK: (\d+) / \1 assertions passed') {
    throw 'Motion contract failed. Inspect motion.log and the actual rendered clips.'
}
Write-Host $Matches[0]
Write-Host "Render review: $evidence\index.html. Visual inspection and Windows/Web performance remain separate checks."
