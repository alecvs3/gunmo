# Runs the headless multiplayer smoke test in eight scenarios:
#   A  listen host + client with simulated 80 ms latency + client with the wrong build
#   B  dedicated server + shooting client (simulated 60 ms) + observing client
#   C  the wave loop: quick 2-wave match, ready-up, victory, restart, defeat (host + client)
#   D  shop: purchases checked by the host, shotgun pellets, credits, wave modifiers
#   E  Gun Game: host + client + 2 bots; names, bot kills, a winner both sides agree on, restart
#   F  stress: 8 players (6 bots) vs 40 enemies; host tick time and bandwidth within budget
#   G  latency: own-input response, smoothing delay and hitches clean and under simulated lag,
#      host input buffer; checked against shared/network/latency_budget.tres
#   H  fairness: a client with 160 ms round trip vs 2 bots; bot hits must be where the
#      client's own screen had it (fair dodging)
#   S  soak (opt-in, only with -Only S): the stress scene for 10 minutes; memory, objects and
#      nodes must not keep growing. Run it before a release or after big changes.
# A-E only check behaviour, so they run at the same time (each on its own port). F, G and H
# measure timing, so each runs alone afterwards: other processes would skew their numbers.
# Usage (from the repo root):
#   .\tests\net\run_smoke.ps1 -Godot "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
#   -Only A,E   just those scenarios (letters)
#   -Only S -SoakSeconds 1800   a longer soak
# or set the GODOT environment variable once and run it without -Godot.
# Exit code 0 = every role passed. Logs go to %TEMP%\gunmo_net_smoke (or -LogDir).
param(
    [string]$Godot = $env:GODOT,
    [int]$Port = 7790,
    [int]$TimeoutSeconds = 120,
    [string]$LogDir = (Join-Path $env:TEMP "gunmo_net_smoke"),
    [string[]]$Only = @(),
    [int]$SoakSeconds = 600
)

if (-not $Godot -or -not (Test-Path $Godot)) {
    Write-Error "Pass -Godot <path to the Godot *console* exe> or set the GODOT environment variable."
    exit 2
}

$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
New-Item -ItemType Directory -Force $LogDir | Out-Null

# Late roles start a moment after the others, once their host is listening.
function Role([string]$Name, [string]$Sim = "", [switch]$Late) {
    return @{ Name = $Name; Sim = $Sim; Late = $Late.IsPresent }
}

$scenarios = @(
    @{ Id = "A"; Title = "listen host, lagged client, wrong-build client"; Alone = $false
       Script = "res://tests/net/net_smoke.gd"; Metrics = ""
       Roles = @((Role "host"), (Role "badclient" -Late), (Role "client" "80,10,2" -Late)) },
    @{ Id = "B"; Title = "dedicated server, shooting client, observer"; Alone = $false
       Script = "res://tests/net/net_smoke.gd"; Metrics = ""
       Roles = @((Role "dedicated"), (Role "shooter" "60,10,0" -Late), (Role "observer" -Late)) },
    @{ Id = "C"; Title = "wave loop (ready-up, victory, restart, defeat)"; Alone = $false
       Script = "res://tests/net/wave_smoke.gd"; Metrics = ""
       Roles = @((Role "wavehost"), (Role "waveclient"), (Role "botwavehost")) },
    @{ Id = "D"; Title = "shop, credits, weapons, wave modifiers"; Alone = $false
       Script = "res://tests/net/shop_smoke.gd"; Metrics = ""
       Roles = @((Role "shophost"), (Role "shopclient")) },
    @{ Id = "E"; Title = "Gun Game with bots (names, ladder, winner, restart)"; Alone = $false
       Script = "res://tests/net/gun_smoke.gd"; Metrics = ""
       Roles = @((Role "gunhost"), (Role "gunclient"), (Role "botduel")) },
    @{ Id = "F"; Title = "stress (8 players vs 40 enemies, performance budget)"; Alone = $true
       Script = "res://tests/net/stress.gd"; Metrics = "STRESS"
       Roles = @((Role "stresshost"), (Role "stressclient")) },
    @{ Id = "G"; Title = "latency budget (clean and with 80 ms simulated lag)"; Alone = $true
       Script = "res://tests/net/latency.gd"; Metrics = "LATENCY"
       Roles = @((Role "latencyhost"), (Role "latencyclient" -Late)) },
    @{ Id = "H"; Title = "fairness under 160 ms round trip (fair dodging)"; Alone = $true
       Script = "res://tests/net/fairness.gd"; Metrics = "FAIRNESS"
       Roles = @((Role "fairhost"), (Role "fairclient" -Late)) },
    @{ Id = "S"; Title = "soak ($SoakSeconds s of stress, memory and node counts)"; Alone = $true
       Script = "res://tests/net/stress.gd"; Metrics = "STRESS"; Optional = $true
       Extra = "$SoakSeconds"; Timeout = $SoakSeconds + 120
       Roles = @((Role "stresshost"), (Role "stressclient")) }
)
for ($i = 0; $i -lt $scenarios.Count; $i++) { $scenarios[$i].Port = $Port + $i }
if ($Only.Count) { $scenarios = @($scenarios | Where-Object { $Only -contains $_.Id }) }
else { $scenarios = @($scenarios | Where-Object { -not $_.Optional }) }

function Start-Role($Scenario, $Role) {
    $arguments = @("--headless", "--path", "`"$projectRoot`"", "-s", $Scenario.Script, "--",
        $Role.Name, "$($Scenario.Port)")
    if ($Role.Sim) { $arguments += $Role.Sim }
    if ($Scenario.Extra) { $arguments += $Scenario.Extra }
    Start-Process -FilePath $Godot -ArgumentList $arguments -NoNewWindow -PassThru `
        -RedirectStandardOutput (Join-Path $LogDir "$($Role.Name).log") `
        -RedirectStandardError (Join-Path $LogDir "$($Role.Name).err.log")
}

# Starts every role of these scenarios (late ones after a short pause) and waits for all.
function Invoke-Batch($Batch) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $processes = @()
    foreach ($late in @($false, $true)) {
        $starting = @($Batch | ForEach-Object { $s = $_; $s.Roles | Where-Object { $_.Late -eq $late } |
            ForEach-Object { @{ Scenario = $s; Role = $_ } } })
        if ($late -and $starting.Count) { Start-Sleep -Seconds 2 }
        foreach ($item in $starting) { $processes += Start-Role $item.Scenario $item.Role }
    }
    $timeout = ($Batch | ForEach-Object { if ($_.Timeout) { $_.Timeout } else { $TimeoutSeconds } } |
        Measure-Object -Maximum).Maximum
    $processes | Wait-Process -Timeout $timeout -ErrorAction SilentlyContinue
    $processes | Where-Object { -not $_.HasExited } | Stop-Process -Force
    return $watch.Elapsed.TotalSeconds
}

function Test-Scenario($Scenario) {
    $ok = $true
    foreach ($role in $Scenario.Roles) {
        $log = Join-Path $LogDir "$($role.Name).log"
        $result = Select-String -Path $log -Pattern "SMOKE (PASS|FAIL)" | Select-Object -Last 1
        if ($result -and $result.Line -match "SMOKE PASS") {
            Write-Host $result.Line -ForegroundColor Green
        } else {
            $line = if ($result) { $result.Line } else { "SMOKE FAIL $($role.Name): no result (crashed or timed out)" }
            Write-Host "$line  (log: $log)" -ForegroundColor Red
            $ok = $false
        }
        if ($Scenario.Metrics) {
            Select-String -Path $log -Pattern "$($Scenario.Metrics) METRIC (\S+) (\S+)" | ForEach-Object {
                Write-Host ("  {0,-38} {1}" -f $_.Matches[0].Groups[1].Value, $_.Matches[0].Groups[2].Value)
            }
        }
    }
    if ($Scenario.Id -eq "E") { $ok = (Test-GunGameWinner) -and $ok }
    return $ok
}

function Test-GunGameWinner {
    $winners = @("gunhost", "gunclient") | ForEach-Object {
        $line = Select-String -Path (Join-Path $LogDir "$_.log") -Pattern "winner id (-?\d+)" | Select-Object -Last 1
        if ($line) { $line.Matches[0].Groups[1].Value } else { "none" }
    }
    if ($winners[0] -ne $winners[1] -or $winners[0] -eq "none") {
        Write-Host "SMOKE FAIL gun game: host saw winner $($winners[0]), client saw $($winners[1])" -ForegroundColor Red
        return $false
    }
    Write-Host "Both sides agree on the winner ($($winners[0]))" -ForegroundColor Green
    $feeds = @("gunhost", "gunclient") | ForEach-Object {
        $line = Select-String -Path (Join-Path $LogDir "$_.log") -Pattern "kill feed tail (\S*)" | Select-Object -Last 1
        if ($line) { $line.Matches[0].Groups[1].Value } else { "none" }
    }
    if ($feeds[0] -ne $feeds[1] -or $feeds[0] -eq "none") {
        Write-Host "SMOKE FAIL gun game: kill feeds differ: host $($feeds[0]), client $($feeds[1])" -ForegroundColor Red
        return $false
    }
    Write-Host "Both sides show the same kill feed ($($feeds[0]))" -ForegroundColor Green
    return $true
}

$allOk = $true
$together = @($scenarios | Where-Object { -not $_.Alone })
$batches = @()
if ($together.Count) { $batches += , $together }
foreach ($scenario in @($scenarios | Where-Object { $_.Alone })) { $batches += , @($scenario) }
foreach ($batch in $batches) {
    $names = ($batch | ForEach-Object { "$($_.Id) ($($_.Title))" }) -join ", "
    Write-Host "Scenario $names"
    Start-Sleep -Seconds 2  # let the previous batch's processes finish exiting
    $seconds = Invoke-Batch $batch
    foreach ($scenario in $batch) { $allOk = (Test-Scenario $scenario) -and $allOk }
    Write-Host ("  took {0:N0} s" -f $seconds)
}

if ($allOk) { exit 0 }
exit 1
