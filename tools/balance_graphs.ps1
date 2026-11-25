# Difficulty, progression and strain on paper: runs every team (novice, average, expert at 1-4
# players, plus the named teams) through the waves the host spawns for a seed, prints one team's
# table as markdown, writes tools/balance/data.js and opens the graph page (tools/balance/graphs.html).
# Pure numbers from the same rules the game uses; no window. Paste the table in balance PRs.
# Usage (from anywhere in the repo):
#   .\tools\balance_graphs.ps1                       seed 1, the model's reference team
#   .\tools\balance_graphs.ps1 -Seed 7               another match seed
#   .\tools\balance_graphs.ps1 -Team res://modes/waves/data/progression/mixed_squad.tres
#   .\tools\balance_graphs.ps1 -NoOpen               don't open the page
param(
    [int]$Seed = 1,
    [string]$Team = "",
    [switch]$NoOpen,
    [string]$Godot = ""
)

$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "find_godot.ps1")
$exe = Find-Godot $Godot
if (-not $exe) {
    Write-Host "Godot 4.7.2 (console exe) not found. Pass -Godot <path> or set GODOT." -ForegroundColor Red
    exit 2
}

$out = Join-Path $PSScriptRoot "balance\data.js"
$userArgs = @("--seed", $Seed, "--out", $out)
if ($Team) { $userArgs += @("--team", $Team) }
$output = @(& $exe --headless --path $root -s tools/balance_graphs.gd -- @userArgs 2>&1 |
    ForEach-Object { "$_" })
$code = $LASTEXITCODE
$start = [array]::FindIndex([string[]]$output, [Predicate[string]] { param($line) $line -like "Balance report:*" })
if ($code -ne 0 -or $start -lt 0) {
    $output | ForEach-Object { Write-Host $_ }
    exit 1
}
$output[$start..($output.Count - 1)] | Where-Object { $_ -like "Balance report:*" -or $_ -like "Team:*" -or $_ -like "|*" } |
    ForEach-Object { Write-Output $_ }
if (-not $NoOpen) { Start-Process (Join-Path $PSScriptRoot "balance\graphs.html") }
exit 0
