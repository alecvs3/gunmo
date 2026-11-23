# Finds the Godot 4.7 console exe, for scripts in tools/ (dot-source this file).
# Order: the path passed in, the GODOT environment variable, PATH, then the usual folders.
function Find-Godot([string]$Preferred = "") {
    if ($Preferred -and (Test-Path $Preferred)) { return (Resolve-Path $Preferred).Path }
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
