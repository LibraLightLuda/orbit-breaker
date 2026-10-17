param([string]$GodotPath='D:\Antigravity\GodotGameProject\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$directory=Join-Path $projectRoot 'build/candidate/server'
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$pack=Join-Path $directory 'server-boot-test.pck'
$output=@(& $GodotPath --headless --path $projectRoot --export-pack 'Online Server' $pack 2>&1)
if($LASTEXITCODE -ne 0 -or ($output -join "`n") -match '(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):'){throw 'Dedicated server pack export failed'}
$listener=[System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback,0)
$listener.Start();$port=$listener.LocalEndpoint.Port;$listener.Stop()
$config=@{id='e'*32;code='E'*10;port=$port;directory=$directory;mode='solo';difficulty='normal';sector='ring';ship='striker'} | ConvertTo-Json -Compress
$encoded=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($config))
# Export templates disable --script; the dedicated feature must select its own main loop.
$output=@(& $GodotPath --headless --main-pack $pack --max-fps 60 --quit-after 30 -- --config $encoded 2>&1)
$text=$output -join "`n"
if($LASTEXITCODE -ne 0 -or $text -match '(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):' -or $text -notmatch 'ONLINE_SERVER_READY'){throw "Dedicated entry failed: $text"}
Remove-Item -LiteralPath $pack
Write-Output 'DEDICATED BOOT SELF-CHECK: embedded feature entry passed without --script'
