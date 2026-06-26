function Format-EventStructure {
    <#
    .SYNOPSIS
        Formats the output of ConvertTo-WinEventStructure into a human-readable string.

    .DESCRIPTION
        Takes a structured event representation produced by ConvertTo-WinEventStructure
        and generates a formatted string for inspection and analysis.

        The output is organized into sections:

        - System
        - EventData
        - UserData

        This function is part of the presentation layer and does not modify or
        validate the input structure.

    .PARAMETER EventStructure
        The structured event object produced by ConvertTo-WinEventStructure.
        The object must contain System, EventData, and UserData properties.


    .OUTPUTS
        System.String

    .NOTES
        Intended for internal use.  Consumers should typically use
        Get-WinEventStructure instead of calling this function directly.
    #>

    param (
        [pscustomobject]$EventStructure
    )

    if (-not $EventStructure) {
        throw "EventStructure cannot be null."
    }

    $output = @()

    # System
    $output += "=== System ==="

    foreach ($key in $EventStructure.System.Keys | Sort-Object) {
        $value = $EventStructure.System[$key]
        $output += "{0, -30} : {1}" -f $key, $value
    }

    # EventData
    $output += ""
    $output += "=== EventData ==="

    foreach ($key in $EventStructure.EventData.Keys | Sort-Object) {
        $output += "{0, -30} : {1}" -f $key,
            $EventStructure.EventData[$key]
    }

    # UserData
    $output += ""
    $output += "=== UserData ==="

    if ($EventStructure.UserData.Wrapper) {
        $output += "Wrapper: $($EventStructure.UserData.Wrapper)"
    }
    else {
        $output += "Wrapper: <none>"
    }

    if ($EventStructure.UserData.Fields.Count -gt 0) {
        foreach ($key in $EventStructure.UserData.Fields.Keys | Sort-Object) {
            $value = $EventStructure.UserData.Fields[$key]
            $output += "{0, -30} : {1}" -f $key, $value
        }
    }
    else {
        $output += "Fields : <none>"
    }
  

    # ======================
    # RETURN OUTPUT
    # ======================
    $output -join "`n"
}