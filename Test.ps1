param([switch]$Visual,[switch]$Stress,[string]$GodotPath)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not $GodotPath) { $GodotPath=Join-Path $taskRoot 'work\tools\godot\Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Godot 4.7.2 executable not found. Pass -GodotPath.' }
$env:APPDATA=Join-Path $taskRoot 'work\test-data'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$testFile='res://tests/run_tests.gd'
if ($Stress) { $testFile='res://tests/stress_test.gd' }
if ($Visual) {
    & $GodotPath --path $PSScriptRoot --script res://tests/ui_test.gd
} else {
    & $GodotPath --headless --path $PSScriptRoot --script $testFile
}
if ($LASTEXITCODE -ne 0) { throw 'Tests failed. See output above.' }
