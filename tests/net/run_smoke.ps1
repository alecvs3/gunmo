# Runs the headless multiplayer smoke test in eight scenarios:
#   A  listen host + client with simulated 80 ms latency + client with the wrong build
#   B  dedicated server + shooting client (simulated 60 ms) + observing client
#   C  the wave loop: quick 2-wave match, ready-up, victory, restart, defeat (host + client)
#   D  shop: purchases checked by the host, shotgun pellets, credits from kills, wave modifiers
#   E  Gun Game: host + client + 2 bots; names, bot kills, a winner both sides agree on, restart
#   F  stress: 8 players (6 bots) vs 40 enemies; host tick time and bandwidth within budget
#   G  latency: own-input response, smoothing delay and hitches clean and under simulated lag,
#      host input buffer; checked against shared/network/latency_budget.tres
#   H  fairness: a client with 160 ms round trip vs 2 bots; bot hits must be where the
#      client's own screen had it (fair dodging)
# Usage (from the repo root):
#   .\tests\net\run_smoke.ps1 -Godot "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
# or set the GODOT environment variable once and run it without -Godot.
# Exit code 0 = every role passed. Logs go to %TEMP%\gunmo_net_smoke (or -LogDir).
param(
    [string]$Godot = $env:GODOT,
    [int]$Port = 7790,
    [int]$TimeoutSeconds = 120,
    [string]$LogDir = (Join-Path $env:TEMP "gunmo_net_smoke")
)

if (-not $Godot -or -not (Test-Path $Godot)) {
    Write-Error "Pass -Godot <path to the Godot *console* exe> or set the GODOT environment variable."
    exit 2
}

$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$logDir = $LogDir
New-Item -ItemType Directory -Force $logDir | Out-Null

function Start-Role([string]$Role, [int]$RolePort, [string]$Sim = "", [string]$Script = "res://tests/net/net_smoke.gd") {
    $arguments = @("--headless", "--path", "`"$projectRoot`"", "-s", $Script, "--", $Role, "$RolePort")
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

Write-Host "Scenario C: wave loop (ready-up, victory, restart, defeat)"
$c = @()
$c += Start-Role "wavehost" ($Port + 2) "" "res://tests/net/wave_smoke.gd"
$c += Start-Role "waveclient" ($Port + 2) "" "res://tests/net/wave_smoke.gd"
Wait-Roles $c
$passC = Test-Roles @("wavehost", "waveclient")

Write-Host "Scenario D: shop, credits, weapons, wave modifiers"
$d = @()
$d += Start-Role "shophost" ($Port + 3) "" "res://tests/net/shop_smoke.gd"
$d += Start-Role "shopclient" ($Port + 3) "" "res://tests/net/shop_smoke.gd"
Wait-Roles $d
$passD = Test-Roles @("shophost", "shopclient")

Write-Host "Scenario E: Gun Game with bots (names, ladder, winner, restart)"
$e = @()
$e += Start-Role "gunhost" ($Port + 4) "" "res://tests/net/gun_smoke.gd"
$e += Start-Role "gunclient" ($Port + 4) "" "res://tests/net/gun_smoke.gd"
Wait-Roles $e
$passE = Test-Roles @("gunhost", "gunclient")
$winners = @("gunhost", "gunclient") | ForEach-Object {
    $line = Select-String -Path (Join-Path $logDir "$_.log") -Pattern "winner id (-?\d+)" | Select-Object -Last 1
    if ($line) { $line.Matches[0].Groups[1].Value } else { "none" }
}
if ($winners[0] -ne $winners[1] -or $winners[0] -eq "none") {
    Write-Host "SMOKE FAIL gun game: host saw winner $($winners[0]), client saw $($winners[1])" -ForegroundColor Red
    $passE = $false
} else {
    Write-Host "Both sides agree on the winner ($($winners[0]))" -ForegroundColor Green
}

Write-Host "Scenario F: stress (8 players vs 40 enemies, performance budget)"
$f = @()
$f += Start-Role "stresshost" ($Port + 5) "" "res://tests/net/stress.gd"
$f += Start-Role "stressclient" ($Port + 5) "" "res://tests/net/stress.gd"
Wait-Roles $f
$passF = Test-Roles @("stresshost", "stressclient")
foreach ($role in @("stresshost", "stressclient")) {
    Select-String -Path (Join-Path $logDir "$role.log") -Pattern "STRESS METRIC (\S+) (\S+)" | ForEach-Object {
        Write-Host ("  {0,-28} {1}" -f $_.Matches[0].Groups[1].Value, $_.Matches[0].Groups[2].Value)
    }
}

Write-Host "Scenario G: latency budget (clean and with 80 ms simulated lag)"
$g = @()
$g += Start-Role "latencyhost" ($Port + 6) "" "res://tests/net/latency.gd"
Start-Sleep -Seconds 1
$g += Start-Role "latencyclient" ($Port + 6) "" "res://tests/net/latency.gd"
Wait-Roles $g
$passG = Test-Roles @("latencyhost", "latencyclient")
foreach ($role in @("latencyhost", "latencyclient")) {
    Select-String -Path (Join-Path $logDir "$role.log") -Pattern "LATENCY METRIC (\S+) (\S+)" | ForEach-Object {
        Write-Host ("  {0,-38} {1}" -f $_.Matches[0].Groups[1].Value, $_.Matches[0].Groups[2].Value)
    }
}

Write-Host "Scenario H: fairness under 160 ms round trip (fair dodging)"
$h = @()
$h += Start-Role "fairhost" ($Port + 7) "" "res://tests/net/fairness.gd"
Start-Sleep -Seconds 1
$h += Start-Role "fairclient" ($Port + 7) "" "res://tests/net/fairness.gd"
Wait-Roles $h
$passH = Test-Roles @("fairhost", "fairclient")
Select-String -Path (Join-Path $logDir "fairclient.log") -Pattern "FAIRNESS METRIC (\S+) (\S+)" | ForEach-Object {
    Write-Host ("  {0,-38} {1}" -f $_.Matches[0].Groups[1].Value, $_.Matches[0].Groups[2].Value)
}

if ($passA -and $passB -and $passC -and $passD -and $passE -and $passF -and $passG -and $passH) { exit 0 }
exit 1
