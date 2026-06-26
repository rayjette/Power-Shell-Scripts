# Load Private functions
$privateFunctions = Get-ChildItem -Path "$PSScriptRoot\src\Private\*.ps1" -Recurse -ErrorAction SilentlyContinue

foreach ($file in $privateFunctions) {
    . $file.FullName
}

# Load Public functions
$publicFunctions = Get-ChildItem -Path "$PSScriptRoot\src\Public\*.ps1" -Recurse -ErrorAction SilentlyContinue

foreach ($file in $publicFunctions) {
    . $file.FullName
}


# Export only Public functions
$functionNames = foreach ($file in $publicFunctions) {
    [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
}

Export-ModuleMember -Function $functionNames
