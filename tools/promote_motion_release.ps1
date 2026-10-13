# Explicit generation and checksum guards make each exchange reviewable.
param(
    [string]$Generation = 'motion-20261013',
    [string]$ExpectedPrevious = '15D4D4098BD767B8B8D63C5550749387DC57FC091651285BCB7BA5F37FF77939',
    [string]$ReadyName = 'motion-ready'
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot)).Path
function Digest([string]$path) {
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($algorithm.ComputeHash([IO.File]::ReadAllBytes($path))).Replace('-','') }
    finally { $algorithm.Dispose() }
}
function Contained([string]$relative) {
    $path = [IO.Path]::GetFullPath((Join-Path $projectRoot $relative))
    if (-not $path.StartsWith($projectRoot + '\',[StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe path: $path" }
    return $path
}
function Read-Json([string]$path) { Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json }
function Write-Json([string]$path, $value) { $value | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $path -Encoding UTF8 }
function Verify-Hashes([string]$folder, $hashes) {
    foreach ($entry in $hashes.PSObject.Properties) {
        $path = [IO.Path]::GetFullPath((Join-Path $folder $entry.Name))
        if (-not $path.StartsWith($folder + '\',[StringComparison]::OrdinalIgnoreCase)) { throw "Manifest escaped folder: $path" }
        if ((Digest $path) -ne $entry.Value) { throw "Checksum mismatch: $path" }
    }
}
function Check-Tree([string]$path) {
    $resolved = (Resolve-Path -LiteralPath $path).Path
    if ($resolved -ne $path -or -not $resolved.StartsWith($projectRoot + '\',[StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe tree: $resolved" }
    if ((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Refusing link: $path" }
    foreach ($item in Get-ChildItem -LiteralPath $path -Recurse -Force) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Refusing nested link: $($item.FullName)" }
    }
}
$currentBuild = Contained 'build/current'
$candidateBuild = Contained 'build/candidate'
$currentArt = Contained 'artifacts/current'
$readyArt = Contained (Join-Path 'artifacts' $ReadyName)
$webRoot = Contained 'web'
$retiringBuild = Contained 'build/retiring-before-motion'
$retiringArt = Contained 'artifacts/retiring-before-motion'
$retiringWeb = Contained 'build/retiring-web-before-motion'
$failedWeb = Contained 'build/failed-motion-web'
foreach ($path in @($retiringBuild,$retiringArt,$retiringWeb,$failedWeb)) {
    if (Test-Path -LiteralPath $path) { throw "Prior transition needs recovery: $path" }
}
foreach ($path in @($currentBuild,$candidateBuild,$currentArt,$readyArt,$webRoot)) { Check-Tree $path }
$verification = Read-Json (Join-Path $readyArt 'verification.json')
if ($verification.generation -ne $Generation -or -not $verification.local_validation_complete -or $verification.promotion -ne 'pending') { throw 'Candidate validation is incomplete.' }
if ($verification.previous_executable_sha256 -ne $expectedPrevious -or (Digest (Join-Path $currentBuild 'OrbitBreaker.exe')) -ne $expectedPrevious) { throw 'Previous normal release changed.' }
foreach ($name in @('SHA256.txt','PLAY-KO.txt')) {
    if (-not (Test-Path -LiteralPath (Join-Path $currentBuild $name) -PathType Leaf)) { throw "Previous release is missing $name" }
}
$previousVerification = Read-Json (Join-Path $currentArt 'verification.json')
if (-not $previousVerification.local_validation_complete -or $previousVerification.promotion -ne 'local-current') { throw 'Previous release evidence is incomplete.' }
$oldHashes = Read-Json (Join-Path $currentArt 'release-hashes.json')
$hashes = Read-Json (Join-Path $readyArt 'release-hashes.json')
$production = Read-Json (Join-Path $readyArt 'production-source-hashes.json')
$evidenceHashes = Read-Json (Join-Path $readyArt 'evidence-hashes.json')
Verify-Hashes $currentBuild $oldHashes
Verify-Hashes $candidateBuild $hashes
Verify-Hashes $projectRoot $production
Verify-Hashes $readyArt $evidenceHashes
if ($verification.native_release.executable_sha256.ToUpperInvariant() -ne (Digest (Join-Path $candidateBuild 'OrbitBreaker.exe'))) { throw 'Candidate differs from tested executable.' }
foreach ($entry in $oldHashes.PSObject.Properties) {
    if ($entry.Name.StartsWith('web/') -and (Digest (Join-Path $webRoot $entry.Name.Substring(4))) -ne $entry.Value) { throw 'Previous published copy changed.' }
}
$moves = [Collections.Generic.List[object]]::new()
function Move-Checked([string]$from,[string]$to) {
    Check-Tree $from
    if (-not $to.StartsWith($projectRoot + '\',[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $to)) { throw "Unsafe move destination: $to" }
    Move-Item -LiteralPath $from -Destination $to
    $moves.Add(@{from=$from;to=$to})
}
$copyStarted = $false
try {
    Move-Checked $currentBuild $retiringBuild
    Move-Checked $currentArt $retiringArt
    Move-Checked $candidateBuild $currentBuild
    Move-Checked $readyArt $currentArt
    Move-Checked $webRoot $retiringWeb
    $copyStarted = $true
    Copy-Item -LiteralPath (Join-Path $currentBuild 'web') -Destination $webRoot -Recurse
    if (Test-Path -LiteralPath (Join-Path $retiringWeb '.gdignore')) {
        Copy-Item -LiteralPath (Join-Path $retiringWeb '.gdignore') -Destination (Join-Path $webRoot '.gdignore')
    }
    Verify-Hashes $currentBuild $hashes
    Verify-Hashes $currentArt $evidenceHashes
    Verify-Hashes $retiringBuild $oldHashes
    Verify-Hashes $projectRoot $production
    foreach ($entry in $hashes.PSObject.Properties) {
        if ($entry.Name.StartsWith('web/') -and (Digest (Join-Path $webRoot $entry.Name.Substring(4))) -ne $entry.Value) { throw 'New Web copy mismatch.' }
    }
    $verification.promotion = 'local-current'
    Write-Json (Join-Path $currentArt 'verification.json') $verification
} catch {
    $originalError = $_
    if ($copyStarted -and (Test-Path -LiteralPath $webRoot)) { Move-Item -LiteralPath $webRoot -Destination $failedWeb }
    for ($i = $moves.Count - 1; $i -ge 0; $i--) {
        $move = $moves[$i]
        if ((Test-Path -LiteralPath $move.to) -and -not (Test-Path -LiteralPath $move.from)) { Move-Item -LiteralPath $move.to -Destination $move.from }
    }
    throw $originalError
}
# Only fresh retiring directories are eligible. Previously rejected scratch paths are never removed.
$removed = @(); $blocked = @()
$cleanup = @($retiringBuild,$retiringArt,$retiringWeb)
if ($Generation -eq 'mobile-20261013') { $cleanup += (Contained 'artifacts/mobile-candidate') }
foreach ($path in $cleanup) {
    try {
        Check-Tree $path
        Remove-Item -LiteralPath $path -Recurse -Force
        $removed += $path
    } catch { $blocked += @{path=$path;reason=$_.Exception.Message} }
}
$scratch = @()
foreach ($relative in @('artifacts/candidate','art_source/web_qa_project','art_source/memory_baseline_project')) {
    $path = Contained $relative
    if (Test-Path -LiteralPath $path) { $scratch += @{path=$path;reason='Previously blocked by policy; not retried'} }
}
$planningTemp = 'C:\Users\home\AppData\Local\Temp\orbit-breaker-art-review-20261012'
if (Test-Path -LiteralPath $planningTemp) { $scratch += @{path=$planningTemp;reason='Previously blocked by policy; not retried'} }
$comparisonProject = Contained 'art_source/motion_baseline_project'
if (Test-Path -LiteralPath $comparisonProject) { $scratch += @{path=$comparisonProject;reason='Previously blocked by policy; not retried'} }
$retention = @{generation=$Generation;local_release_cleanup_complete=($blocked.Count -eq 0);single_verified_release_generation=($blocked.Count -eq 0);
    removed=$removed;blocked=$blocked;temporary_cleanup_complete=($scratch.Count -eq 0);retained_scratch=$scratch;
    source_and_player_data='preserved';public_publication=$verification.public_publication;
    evidence_manifest_note='evidence-hashes.json covers curated immutable evidence; final inventory also includes promotion metadata'}
Write-Json (Join-Path $currentArt 'retention-status.json') $retention
$inventory = @()
foreach ($folder in @($currentBuild,$currentArt)) {
    foreach ($file in Get-ChildItem -LiteralPath $folder -Recurse -File | Sort-Object FullName) {
        if ($file.Name -eq 'file-inventory.json') { continue }
        $inventory += @{path=$file.FullName.Substring($projectRoot.Length+1).Replace('\','/');bytes=$file.Length;sha256=(Digest $file.FullName)}
    }
}
Write-Json (Join-Path $currentArt 'file-inventory.json') @{generation=$Generation;excludes_self=$true;files=$inventory}
Write-Host 'Motion generation promoted. Previous release was preserved until new release/Web/evidence checks succeeded.'
if ($blocked.Count -or $scratch.Count) { Write-Host 'Temporary cleanup is incomplete; see retention-status.json. Previously blocked paths were not retried.' }
