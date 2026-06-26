$root = $PSScriptRoot
while ($root -and -not (Test-Path (Join-Path $root "src"))) {
    $root = Split-Path $root -Parent
}

Import-Module (Join-Path $root "WinEventTools.psm1") -Force