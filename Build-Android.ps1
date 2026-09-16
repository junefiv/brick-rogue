param([string]$GodotPath)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not $GodotPath) { $GodotPath=Join-Path $taskRoot 'work\tools\godot\Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Godot 4.7.2 executable not found. Pass -GodotPath.' }
$env:APPDATA=Join-Path $taskRoot 'work\build-data'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$apkPath=Join-Path (Split-Path $PSScriptRoot -Parent) 'RogueBreaker-Android.apk'
& $GodotPath --headless --path $PSScriptRoot --export-debug Android $apkPath
if ($LASTEXITCODE -ne 0) { throw 'Android export failed. Check Godot export templates, Java 17 and Android SDK settings.' }
Get-Item -LiteralPath $apkPath | Select-Object FullName,Length,LastWriteTime
