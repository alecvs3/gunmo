# Runs every check and prints a short summary: only what failed, and why.
#   import (retried: Godot 4.7.2's import sometimes crashes) -> GUT tests -> gdlint ->
#   gdformat --check -> (with -Smoke) the multiplayer smoke test
# Usage (from anywhere in the repo):
#   .\tools\check.ps1                 everything except the smoke test (about 1 minute)
#   .\tools\check.ps1 -Smoke          also the smoke scenarios A-F (about 6 more minutes)
#   .\tools\check.ps1 -Only tests     one step: import, tests, lint, format or smoke
#   .\tools\check.ps1 -Fix            run gdformat (fixes formatting) before checking
# Godot is found from -Godot, the GODOT environment variable, PATH, or the usual folders.
# gdtoolkit is found on PATH or run through Python. Exit code 0 = every step passed.
param(
    [string]$Godot = "",
    [switch]$Smoke,
    [ValidateSet("", "import", "tests", "lint", "format", "smoke")]
    [string]$Only = "",
    [switch]$Fix,
    [string]$LogDir = (Join-Path $env:TEMP "gunmo_check")
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Force $LogDir | Out-Null
$results = [ordered]@{}

function Find-Godot {
    if ($Godot -and (Test-Path $Godot)) { return (Resolve-Path $Godot).Path }
    if ($env:GODOT -and (Test-Path $env:GODOT)) { return $env:GODOT }
    foreach ($name in @("godot_console", "godot")) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
    }
    $folders = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Godot"),
        "C:\Tools\Godot",
        (Join-Path $HOME "Godot"),
        (Join-Path $HOME "Downloads")
    )
    foreach ($folder in $folders) {
        if (-not (Test-Path $folder)) { continue }
        $found = Get-ChildItem $folder -Recurse -Depth 2 -Filter "Godot_v4.7*_console.exe" `
            -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

# gdlint/gdformat on PATH, or the same tools through Python (pip's Scripts folder is often
# not on PATH on Windows).
function Invoke-GdTool([string]$Tool, [string[]]$Arguments) {
    if (Get-Command $Tool -ErrorAction SilentlyContinue) {
        $output = & $Tool @Arguments 2>&1
    } else {
        $module = @{ gdlint = "gdtoolkit.linter"; gdformat = "gdtoolkit.formatter" }[$Tool]
        $output = & python -m $module @Arguments 2>&1
    }
    return @{ Code = $LASTEXITCODE; Output = @($output | ForEach-Object { "$_" }) }
}

function Wants([string]$Step) {
    if ($Only) { return $Only -eq $Step }
    if ($Step -eq "smoke") { return $Smoke.IsPresent }
    return $true
}

function Step-Import([string]$Exe) {
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        & $Exe --headless --path $root --import *> (Join-Path $LogDir "import.log")
        if ($LASTEXITCODE -eq 0) { return @{ Ok = $true; Detail = "" } }
    }
    return @{ Ok = $false; Detail = "crashed 3 times (log: $LogDir\import.log)" }
}

function Step-Tests([string]$Exe) {
    $xml = Join-Path $LogDir "gut.xml"
    Remove-Item $xml -ErrorAction SilentlyContinue
    & $Exe --headless --path $root -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit `
        "-gjunit_xml_file=$xml" *> (Join-Path $LogDir "gut.log")
    $log = Get-Content (Join-Path $LogDir "gut.log") -ErrorAction SilentlyContinue
    $errors = @($log | Where-Object { $_ -match "SCRIPT ERROR|Parse Error|Failed to load" } |
        Select-Object -First 5)
    if (-not (Test-Path $xml)) {
        return @{ Ok = $false; Detail = "no results (log: $LogDir\gut.log)"; Lines = $errors }
    }
    [xml]$report = Get-Content $xml
    $cases = @($report.SelectNodes("//testcase"))
    $failed = @($report.SelectNodes("//testcase[failure]"))
    $lines = @($failed | ForEach-Object {
        $text = "$($_.failure.InnerText)"
        if (-not $text.Trim()) { $text = "$($_.failure.message)" }
        $message = ($text -replace "\e\[[0-9;]*m", "" -replace "\s+", " ").Trim()
        "$($_.classname) :: $($_.name): $message"
    }) + $errors
    $summary = "$($cases.Count - $failed.Count)/$($cases.Count) passed"
    return @{ Ok = ($failed.Count -eq 0 -and $errors.Count -eq 0); Detail = $summary; Lines = $lines }
}

function Step-Lint {
    $run = Invoke-GdTool "gdlint" @($root)
    $problems = @($run.Output | Where-Object { $_ -match "^\S.*:\d+: Error:" -or $_ -match "No terminal" })
    if ($run.Code -eq 0) { return @{ Ok = $true; Detail = "clean" } }
    $detail = if ($problems.Count) { "$($problems.Count) problem(s)" } else { "failed" }
    $lines = @($problems + @($run.Output | Select-Object -Last 1)) | Select-Object -Unique
    return @{ Ok = $false; Detail = $detail; Lines = $lines }
}

function Step-Format {
    if ($Fix) { Invoke-GdTool "gdformat" @($root) | Out-Null }
    $run = Invoke-GdTool "gdformat" @("--check", $root)
    if ($run.Code -eq 0) { return @{ Ok = $true; Detail = "clean" } }
    $files = @($run.Output | Where-Object { $_ -match "would reformat" })
    return @{
        Ok = $false
        Detail = "$($files.Count) file(s) need formatting (run with -Fix)"
        Lines = $files
    }
}

function Step-Smoke([string]$Exe) {
    $smokeLogs = Join-Path $LogDir "smoke"
    $output = & (Join-Path $root "tests\net\run_smoke.ps1") -Godot $Exe -LogDir $smokeLogs *>&1
    $ok = $LASTEXITCODE -eq 0
    $passed = @($output | Where-Object { "$_" -match "SMOKE PASS" }).Count
    $failures = @($output | Where-Object { "$_" -match "SMOKE FAIL" } | ForEach-Object { "$_" })
    return @{ Ok = $ok; Detail = "$passed roles passed (logs: $smokeLogs)"; Lines = $failures }
}

$exe = Find-Godot
$needsGodot = (Wants "import") -or (Wants "tests") -or (Wants "smoke")
if ($needsGodot -and -not $exe) {
    Write-Host "Godot 4.7.2 (console exe) not found. Pass -Godot <path> or set GODOT." -ForegroundColor Red
    exit 2
}

if (Wants "import") { $results["import"] = Step-Import $exe }
if ((Wants "tests") -and -not ($results["import"] -and -not $results["import"].Ok)) {
    $results["tests"] = Step-Tests $exe
}
if (Wants "lint") { $results["lint"] = Step-Lint }
if (Wants "format") { $results["format"] = Step-Format }
if (Wants "smoke") { $results["smoke"] = Step-Smoke $exe }

$allOk = $true
foreach ($name in $results.Keys) {
    $result = $results[$name]
    $mark = if ($result.Ok) { "PASS" } else { "FAIL" }
    $color = if ($result.Ok) { "Green" } else { "Red" }
    Write-Host ("{0,-6} {1,-7} {2}" -f $mark, $name, $result.Detail) -ForegroundColor $color
    if (-not $result.Ok) {
        $allOk = $false
        foreach ($line in @($result.Lines | Select-Object -First 15)) { Write-Host "         $line" }
    }
}
if ($allOk) { exit 0 }
exit 1
