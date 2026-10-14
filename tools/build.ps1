param(
    [string]$GodotPath = 'D:\Antigravity\GodotGameProject\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath"
}

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'project.godot') -PathType Leaf)) {
    throw "project.godot not found in $projectRoot"
}

function Invoke-GodotChecked {
    param([string[]]$Arguments, [string]$SuccessPattern = '')

	if ('--audio-driver' -notin $Arguments) { $Arguments = @('--audio-driver', 'Dummy') + $Arguments }
    $ErrorActionPreference = 'Continue'
    $output = @(& $GodotPath @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $output | ForEach-Object { Write-Host $_ }
    $outputText = $output -join "`n"
    if ($exitCode -ne 0) { throw "Godot failed (exit $exitCode)." }
    # Godot can report a script error while returning exit code zero.
    if ($outputText -match '(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):') {
        throw 'Godot reported an error; export stopped.'
    }
    if ($SuccessPattern -and $outputText -notmatch $SuccessPattern) {
        throw 'The test did not report all checks passing; export stopped.'
    }
}

function Get-SourceHashes {
    $hashes = [ordered]@{}
    foreach ($base in @('scripts','assets','tests','tools')) {
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot $base) -File -Recurse | Sort-Object FullName) {
            if ($file.Extension -in @('.uid','.pyc')) { continue }
            $relative = $file.FullName.Substring($projectRoot.Length + 1).Replace('\','/')
            $hashes[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        }
    }
    foreach ($relative in @('project.godot','main.tscn','export_presets.cfg','icon.svg')) {
        $hashes[$relative] = (Get-FileHash -LiteralPath (Join-Path $projectRoot $relative) -Algorithm SHA256).Hash
    }
    return $hashes
}

$buildDirectory = Join-Path $projectRoot 'build\candidate'
$outputPath = Join-Path $buildDirectory 'OrbitBreaker.exe'
New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null

Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--editor', '--quit')
$sourceHashes = Get-SourceHashes
$validationStarted = (Get-Date).ToUniversalTime().ToString('o')
$ErrorActionPreference = 'Continue'
& python -m unittest discover -s (Join-Path $projectRoot 'tests') -p test_validation.py 2>&1 | ForEach-Object { Write-Host $_ }
$validationExit = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($validationExit -ne 0) { throw 'Build validation regression tests failed.' }

Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_combat_expansion.gd') `
    -SuccessPattern '(?m)^COMBAT SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'

Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_performance.gd') `
    -SuccessPattern '(?m)^PERFORMANCE: 600 moving frames, 240 enemies/shots, 300 gems;.*p95 [0-9.]+ms'

Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_audio.gd') `
    -SuccessPattern '(?m)^AUDIO SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'

Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_feedback_mobile.gd') `
    -SuccessPattern '(?m)^MOBILEFEEDBACK SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'

Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_mobile.gd') `
    -SuccessPattern '(?m)^MOBILE SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'

Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_model.gd') `
    -SuccessPattern '(?m)^MODEL SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'
Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_survival.gd') `
    -SuccessPattern '(?m)^SURVIVAL SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'
Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_expansion.gd') `
    -SuccessPattern '(?m)^EXPANSION SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'
Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_feedback.gd') `
    -SuccessPattern '(?m)^FEEDBACK SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'
Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_feedback_v315.gd') `
    -SuccessPattern '(?m)^FEEDBACK315 SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'
Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_feedback_v317.gd') `
    -SuccessPattern '(?m)^FEEDBACK317 SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'
Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_feedback_v318.gd') `
    -SuccessPattern '(?m)^FEEDBACK318 SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'
Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_events.gd') `
    -SuccessPattern '(?m)^EVENT SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'
Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_expedition.gd') `
    -SuccessPattern '(?m)^EXPEDITION SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'
Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_ships.gd') `
    -SuccessPattern '(?m)^SHIP SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'
Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_viewport.gd') `
    -SuccessPattern '(?m)^VIEWPORT SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'
Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_orbital.gd') `
    -SuccessPattern '(?m)^ORBITAL SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'
Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_items.gd') `
    -SuccessPattern '(?m)^ITEM SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'
Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_replay_world.gd') `
    -SuccessPattern '(?m)^REPLAY WORLD SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'
Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_balance.gd') `
    -SuccessPattern '(?m)^BALANCE SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'
Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_support.gd') `
    -SuccessPattern '(?m)^SUPPORT TESTS: [1-9][0-9]* checks, 0 failures\s*$'
Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_ui.gd') `
    -SuccessPattern '(?m)^UI SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'
Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_progression.gd') `
    -SuccessPattern '(?m)^PROGRESSION SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'
Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_uiux.gd', '--', '--stage=6') `
    -SuccessPattern '(?m)^UIUX SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'

Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_art.gd') `
    -SuccessPattern '(?m)^ART SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'

Invoke-GodotChecked -Arguments @('--path', $projectRoot, '--audio-driver', 'Dummy', '--script', 'res://tests/test_pregame.gd') `
    -SuccessPattern '(?m)^PREGAME SELF-CHECK: ([1-9][0-9]*) / \1 assertions passed\s*$'

Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--export-release', 'Windows Desktop', $outputPath)
if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
    throw "Export returned success without creating $outputPath"
}

$buildHash = [System.Security.Cryptography.SHA256]::Create()
try { Write-Host ([BitConverter]::ToString($buildHash.ComputeHash([IO.File]::ReadAllBytes($outputPath))).Replace('-','')) }
finally { $buildHash.Dispose() }
$webDirectory = Join-Path $buildDirectory 'web'
New-Item -ItemType Directory -Path $webDirectory -Force | Out-Null
Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--export-release', 'Web', (Join-Path $webDirectory 'index.html'))
Invoke-GodotChecked -Arguments @('--path', $projectRoot, '--audio-driver', 'Dummy', '--script', 'res://tests/audio_smoke.gd') -SuccessPattern 'AUDIO SMOKE COMPLETE'
$finalSources = Get-SourceHashes
if ($sourceHashes.Count -ne $finalSources.Count) { throw 'Source inventory changed during validation.' }
foreach ($entry in $sourceHashes.GetEnumerator()) {
    if ($finalSources[$entry.Key] -ne $entry.Value) { throw "Source changed during validation: $($entry.Key)" }
}
$outputs = [ordered]@{'OrbitBreaker.exe' = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash}
foreach ($file in Get-ChildItem -LiteralPath $webDirectory -File) {
    $outputs['web/' + $file.Name] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
}
@{complete=$true;started=$validationStarted;source_hashes=$sourceHashes;outputs=$outputs} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $buildDirectory 'candidate-validation.json') -Encoding UTF8
Write-Host 'Candidate exported. Promote only after the exported executable and browser checks pass. Existing release remains untouched.'
