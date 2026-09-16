param([string]$GodotPath)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not $GodotPath) { $GodotPath=Join-Path $taskRoot 'work\tools\godot\Godot_v4.7.2-stable_win64.exe' }
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Godot 4.7.2 executable not found. Pass -GodotPath or open project.godot in Godot.' }
$env:APPDATA=Join-Path $taskRoot 'work\play-data'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
& $GodotPath --path $PSScriptRoot
