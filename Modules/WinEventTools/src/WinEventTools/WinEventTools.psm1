
# Load Public functions
$publicFunctions = Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -Recurse -ErrorAction SilentlyContinue

foreach ($file in $publicFunctions) {
    . $file.FullName
}

# Load Private functions
$privateFunctions = Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -Recurse -ErrorAction SilentlyContinue

foreach ($file in $privateFunctions) {
    . $file.FullName
}

# Export only Public functions
$functionNames = foreach ($file in $publicFunctions) {
    [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
}

Export-ModuleMember -Function $functionNames
