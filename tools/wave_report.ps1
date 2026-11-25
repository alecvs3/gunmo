# Prints the wave difficulty curve as a markdown table: for every wave, the budget, enemies by
# type, total and effective health, peak alive (the max_alive cap), spawn time and modifiers.
# Pure numbers from the same code the host runs; no window. Paste it before/after in balance PRs.
# Usage (from anywhere in the repo):
#   .\tools\wave_report.ps1                 default schedule, seed 1
#   .\tools\wave_report.ps1 -Seed 7         another match seed (enemy mix and modifiers change)
#   .\tools\wave_report.ps1 -Players 4      waves for 4 players (they grow with the team; default 2)
#   .\tools\wave_report.ps1 -Schedule res://modes/waves/data/other.tres
param(
    [int]$Seed = 1,
    [int]$Players = 2,
    [string]$Schedule = "res://modes/waves/data/default_waves.tres",
    [string]$Godot = ""
)

$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "find_godot.ps1")
$exe = Find-Godot $Godot
if (-not $exe) {
    Write-Host "Godot 4.7.2 (console exe) not found. Pass -Godot <path> or set GODOT." -ForegroundColor Red
    exit 2
}

$output = @(& $exe --headless --path $root -s tools/wave_report.gd -- --schedule $Schedule --seed $Seed --players $Players 2>&1 |
    ForEach-Object { "$_" })
$code = $LASTEXITCODE
$start = [array]::FindIndex([string[]]$output, [Predicate[string]] { param($line) $line -like "Wave report:*" })
if ($code -ne 0 -or $start -lt 0) {
    $output | ForEach-Object { Write-Host $_ }
    exit 1
}
# Only the report: Godot's exit messages about scripts still cached at shutdown are noise.
$output[$start..($output.Count - 1)] | Where-Object { $_ -like "Wave report:*" -or $_ -like "|*" } |
    ForEach-Object { Write-Output $_ }
exit 0
