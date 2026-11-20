# Runs the headless multiplayer smoke test: a host, a client and a client with the wrong build.
# Usage (from the repo root):
#   .\tests\net\run_smoke.ps1 -Godot "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
# or set the GODOT environment variable once and run it without -Godot.
# Exit code 0 = all three passed. Logs go to %TEMP%\gunmo_net_smoke.
param(
    [string]$Godot = $env:GODOT,
    [int]$Port = 7790,
    [int]$TimeoutSeconds = 90
)

if (-not $Godot -or -not (Test-Path $Godot)) {
    Write-Error "Pass -Godot <path to the Godot *console* exe> or set the GODOT environment variable."
    exit 2
}

$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$logDir = Join-Path $env:TEMP "gunmo_net_smoke"
New-Item -ItemType Directory -Force $logDir | Out-Null

function Start-Role([string]$Role) {
    $arguments = @("--headless", "--path", "`"$projectRoot`"", "-s", "res://tests/net/net_smoke.gd", "--", $Role, "$Port")
    Start-Process -FilePath $Godot -ArgumentList $arguments -NoNewWindow -PassThru `
        -RedirectStandardOutput (Join-Path $logDir "$Role.log") `
        -RedirectStandardError (Join-Path $logDir "$Role.err.log")
}

$roles = @("host", "badclient", "client")
$processes = @()
$processes += Start-Role "host"
Start-Sleep -Seconds 2
$processes += Start-Role "badclient"
$processes += Start-Role "client"

$processes | Wait-Process -Timeout $TimeoutSeconds -ErrorAction SilentlyContinue
$processes | Where-Object { -not $_.HasExited } | Stop-Process -Force

$failed = $false
foreach ($role in $roles) {
    $result = Select-String -Path (Join-Path $logDir "$role.log") -Pattern "SMOKE (PASS|FAIL)" | Select-Object -Last 1
    if ($result -and $result.Line -match "SMOKE PASS") {
        Write-Host $result.Line -ForegroundColor Green
    } else {
        $line = if ($result) { $result.Line } else { "SMOKE FAIL ${role}: no result (crashed or timed out)" }
        Write-Host "$line  (log: $logDir\$role.log)" -ForegroundColor Red
        $failed = $true
    }
}
if ($failed) { exit 1 }
exit 0
