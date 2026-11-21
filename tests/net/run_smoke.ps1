# Runs the headless multiplayer smoke test in two scenarios:
#   A  listen host + client with simulated 80 ms latency + client with the wrong build
#   B  dedicated server + shooting client (simulated 60 ms) + observing client
# Usage (from the repo root):
#   .\tests\net\run_smoke.ps1 -Godot "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
# or set the GODOT environment variable once and run it without -Godot.
# Exit code 0 = every role passed. Logs go to %TEMP%\gunmo_net_smoke.
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

function Start-Role([string]$Role, [int]$RolePort, [string]$Sim = "") {
    $arguments = @("--headless", "--path", "`"$projectRoot`"", "-s", "res://tests/net/net_smoke.gd", "--", $Role, "$RolePort")
    if ($Sim) { $arguments += $Sim }
    Start-Process -FilePath $Godot -ArgumentList $arguments -NoNewWindow -PassThru `
        -RedirectStandardOutput (Join-Path $logDir "$Role.log") `
        -RedirectStandardError (Join-Path $logDir "$Role.err.log")
}

function Wait-Roles($Processes) {
    $Processes | Wait-Process -Timeout $TimeoutSeconds -ErrorAction SilentlyContinue
    $Processes | Where-Object { -not $_.HasExited } | Stop-Process -Force
}

function Test-Roles([string[]]$Roles) {
    $ok = $true
    foreach ($role in $Roles) {
        $result = Select-String -Path (Join-Path $logDir "$role.log") -Pattern "SMOKE (PASS|FAIL)" | Select-Object -Last 1
        if ($result -and $result.Line -match "SMOKE PASS") {
            Write-Host $result.Line -ForegroundColor Green
        } else {
            $line = if ($result) { $result.Line } else { "SMOKE FAIL ${role}: no result (crashed or timed out)" }
            Write-Host "$line  (log: $logDir\$role.log)" -ForegroundColor Red
            $ok = $false
        }
    }
    return $ok
}

Write-Host "Scenario A: listen host, lagged client, wrong-build client"
$a = @()
$a += Start-Role "host" $Port
Start-Sleep -Seconds 2
$a += Start-Role "badclient" $Port
$a += Start-Role "client" $Port "80,10,2"
Wait-Roles $a
$passA = Test-Roles @("host", "badclient", "client")

Write-Host "Scenario B: dedicated server, shooting client, observer"
$b = @()
$b += Start-Role "dedicated" ($Port + 1)
Start-Sleep -Seconds 2
$b += Start-Role "shooter" ($Port + 1) "60,10,0"
$b += Start-Role "observer" ($Port + 1)
Wait-Roles $b
$passB = Test-Roles @("dedicated", "shooter", "observer")

if ($passA -and $passB) { exit 0 }
exit 1
