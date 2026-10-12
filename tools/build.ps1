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

$buildDirectory = Join-Path $projectRoot 'build\candidate'
$outputPath = Join-Path $buildDirectory 'OrbitBreaker.exe'
New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null

Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--editor', '--quit')

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

Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--export-release', 'Windows Desktop', $outputPath)
if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
    throw "Export returned success without creating $outputPath"
}

Get-FileHash -LiteralPath $outputPath -Algorithm SHA256
$webDirectory = Join-Path $buildDirectory 'web'
New-Item -ItemType Directory -Path $webDirectory -Force | Out-Null
Invoke-GodotChecked -Arguments @('--headless', '--path', $projectRoot, '--export-release', 'Web', (Join-Path $webDirectory 'index.html'))
Invoke-GodotChecked -Arguments @('--path', $projectRoot, '--audio-driver', 'Dummy', '--quit-after', '180')
Write-Host 'Candidate exported. Promote only after the exported executable and browser checks pass. Existing release remains untouched.'
