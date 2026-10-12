$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot)).Path
$sha256 = [System.Security.Cryptography.SHA256]::Create()
function Digest([string]$path) { [BitConverter]::ToString($sha256.ComputeHash([IO.File]::ReadAllBytes($path))).Replace('-','') }
function Contained([string]$relative) {
    $path = [IO.Path]::GetFullPath((Join-Path $projectRoot $relative))
    if (-not $path.StartsWith($projectRoot + '\',[StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe path: $path" }
    return $path
}
function Remove-Checked([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return }
    $resolved = (Resolve-Path -LiteralPath $path).Path
    if ($resolved -ne $path -or -not $resolved.StartsWith($projectRoot + '\',[StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe cleanup: $resolved" }
    if ((Get-Item -LiteralPath $resolved).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Cleanup refuses a junction: $resolved" }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
$currentBuild=Contained 'build/current'
$candidateBuild=Contained 'build/candidate'
$currentArt=Contained 'artifacts/current'
$candidateArt=Contained 'artifacts/candidate'
$webRoot=Contained 'web'
$retiringBuild=Contained 'build/retiring-art-baseline'
$retiringArt=Contained 'artifacts/retiring-art-baseline'
$retiringWeb=Contained 'build/retiring-art-web'
$failedWeb=Contained 'build/failed-art-web'
$verification=Get-Content -LiteralPath (Join-Path $candidateArt 'verification.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $verification.local_validation_complete -or $verification.promotion -ne 'pending') { throw 'Candidate has not passed the complete validation gate.' }
$hashes=Get-Content -LiteralPath (Join-Path $candidateArt 'release-hashes.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($entry in $hashes.PSObject.Properties) {
    if ((Digest (Join-Path $candidateBuild $entry.Name)) -ne $entry.Value) { throw "Candidate checksum mismatch: $($entry.Name)" }
}
foreach ($path in @($retiringBuild,$retiringArt,$retiringWeb,$failedWeb)) { if (Test-Path -LiteralPath $path) { throw "Prior transition needs recovery: $path" } }
foreach ($relative in @('SHA256.txt','PLAY-KO.txt')) { if (-not (Test-Path -LiteralPath (Join-Path $currentBuild $relative))) { throw 'Previous release guidance/checksums missing.' } }
if (-not (Test-Path -LiteralPath (Join-Path $currentArt 'verification.json'))) { throw 'Previous release evidence missing.' }
if ((Digest (Join-Path $currentBuild 'OrbitBreaker.exe')) -ne 'D60452D5E341CFBDEF1182ACD5E454B862FD34245A1C3C0A2E15094A76058234') { throw 'Previous verified release changed; inspect before promotion.' }
$moves=[Collections.Generic.List[object]]::new()
function Move-Checked([string]$from,[string]$to) {
    if (-not $from.StartsWith($projectRoot+'\',[StringComparison]::OrdinalIgnoreCase) -or -not $to.StartsWith($projectRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Move escaped workspace.' }
    if (Test-Path -LiteralPath $to) { throw "Move destination exists: $to" }
    Move-Item -LiteralPath $from -Destination $to
    $moves.Add(@{from=$from;to=$to})
}
$copyStarted=$false
try {
    Move-Checked $currentBuild $retiringBuild
    Move-Checked $currentArt $retiringArt
    Move-Checked $candidateBuild $currentBuild
    Move-Checked $candidateArt $currentArt
    Move-Checked $webRoot $retiringWeb
    $copyStarted=$true
    Copy-Item -LiteralPath (Join-Path $currentBuild 'web') -Destination $webRoot -Recurse
    foreach ($entry in $hashes.PSObject.Properties) {
        if ((Digest (Join-Path $currentBuild $entry.Name)) -ne $entry.Value) { throw "Promoted checksum mismatch: $($entry.Name)" }
        if ($entry.Name.StartsWith('web/')) {
            if ((Digest (Join-Path $webRoot $entry.Name.Substring(4))) -ne $entry.Value) { throw "Web copy mismatch: $($entry.Name)" }
        }
    }
    if ((Digest (Join-Path $retiringBuild 'OrbitBreaker.exe')) -ne 'D60452D5E341CFBDEF1182ACD5E454B862FD34245A1C3C0A2E15094A76058234') { throw 'Preserved baseline checksum mismatch.' }
} catch {
    if ($copyStarted -and (Test-Path -LiteralPath $webRoot)) { Move-Item -LiteralPath $webRoot -Destination $failedWeb }
    for ($i=$moves.Count-1;$i -ge 0;$i--) {
        $move=$moves[$i]
        if ((Test-Path -LiteralPath $move.to) -and -not (Test-Path -LiteralPath $move.from)) { Move-Item -LiteralPath $move.to -Destination $move.from }
    }
    throw
}
$verification.promotion='local-current'
$verification | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $currentArt 'verification.json') -Encoding UTF8
$removed=@(); $blocked=@()
$cleanup=@($retiringBuild,$retiringArt,$retiringWeb,(Contained 'art_source/web_qa_project'),(Contained 'artifacts/current/art/first-pass'),(Contained 'artifacts/current/art/loader-failure'))
foreach ($path in $cleanup) {
    try { Remove-Checked $path; $removed += $path }
    catch { $blocked += @{path=$path;reason=$_.Exception.Message} }
}
foreach ($name in @('native-title.wav','native-title00000000.png','native-title00000001.png')) {
    $path=Contained ('artifacts/current/art/'+$name)
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
}
$retention=@{ generation='art-20261012';local_release_cleanup_complete=($blocked.Count -eq 0);removed=$removed;blocked=$blocked;planning_temp_cleanup='Previously blocked by policy; not retried';source_and_player_data='preserved';public_publication='not performed' }
$retention | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $currentArt 'retention-status.json') -Encoding UTF8
$sha256.Dispose()
Write-Host 'Promoted current, verified preserved baseline and new release/Web hashes, then cleaned previous local release generation.'
if ($blocked.Count) { Write-Host 'Cleanup incomplete: inspect retention-status.json.' }
