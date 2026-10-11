param([string]$GodotPath = 'D:\Antigravity\GodotGameProject\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$evidence = Join-Path $projectRoot 'artifacts\candidate'
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$results = @()
$cases = @(
    @{ Name="feedback318-1600"; Script="test_feedback_v318"; Size="1600x900"; Extra=@("--capture") },
    @{ Name="feedback318-960"; Script="test_feedback_v318"; Size="960x540"; Extra=@("--capture") },
    @{ Name='feedback317-1600'; Script='test_feedback_v317'; Size='1600x900'; Extra=@('--capture') },
    @{ Name='feedback317-960'; Script='test_feedback_v317'; Size='960x540'; Extra=@('--capture') },
    @{ Name='feedback315-1600'; Script='test_feedback_v315'; Size='1600x900'; Extra=@('--capture') },
    @{ Name='feedback315-960'; Script='test_feedback_v315'; Size='960x540'; Extra=@('--capture') },
    @{ Name='ui-1600'; Script='test_ui'; Size='1600x900'; Extra=@('--capture') },
    @{ Name='ui-960'; Script='test_ui'; Size='960x540'; Extra=@('--capture','--capture-small') },
    @{ Name='expedition-1600'; Script='test_expedition'; Size='1600x900'; Extra=@('--capture') },
    @{ Name='expedition-960'; Script='test_expedition'; Size='960x540'; Extra=@('--capture','--capture-small') },
    @{ Name='viewport-1600'; Script='test_viewport'; Size='1600x900'; Extra=@('--capture','--check-fullscreen') },
    @{ Name='viewport-1920'; Script='test_viewport'; Size='1920x1200'; Extra=@('--capture') },
    @{ Name='viewport-2560'; Script='test_viewport'; Size='2560x1080'; Extra=@('--capture') },
    @{ Name='items'; Script='test_items'; Size='1600x900'; Extra=@('--capture') },
    @{ Name='events'; Script='test_events'; Size='1600x900'; Extra=@('--capture') },
    @{ Name='uiux'; Script='test_uiux'; Size='1600x900'; Extra=@('--stage=6') }
)
foreach ($case in $cases) {
    $arguments = @('--path',$projectRoot,'--audio-driver','Dummy','--resolution',$case.Size,'--script',("res://tests/{0}.gd" -f $case.Script),'--') + $case.Extra
    $output = @(& $GodotPath @arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $output | Set-Content -LiteralPath (Join-Path $evidence ($case.Name + '.log')) -Encoding UTF8
    $message = $output -join "`n"
    if ($exitCode -ne 0 -or $message -match '(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):' -or $message -notmatch 'SELF-CHECK: (\d+) / \1 assertions passed') {
        throw "Rendering failed: $($case.Name). See its evidence log."
    }
    $results += @{ name=$case.Name; passed=[int]$Matches[1]; size=$case.Size }
    Write-Host "$($case.Name): $($Matches[1]) passed"
}
$results | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'render-results.json') -Encoding UTF8
Write-Host 'All rendering fixtures passed. Exported executable and browser checks remain separate.'
