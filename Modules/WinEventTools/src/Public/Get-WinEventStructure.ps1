function Get-WinEventStructure {
    <#
    .SYNOPSIS
        Retrieves a structural representation of a Windows Event Log entry.

    .DESCRIPTION
        Retrieves a single event from the specified log and event ID, and produces
        a structured, human-readable representation of the event.

        The output is designed to support field discovery and analysis by exposing:

        - System properties present in the event
        - EventData fields (if present)
        - UserData fields and wrapper (if present)

        System properties are extracted directly from the event and include both
        element values and attribute values.

        Payload data is handled as follows:
        - EventData fields are extracted by name and value
        - UserData fields are extracted along with their wrapper element name

        If no matching event is found, the function throws an exception.

        By default, this function returns a structured object suitable for
        programmatic use.  When the -AsFormattedString switch is specified,
        the function returns a formatted, human-readable string representation.

    .PARAMETER LogName
        Specifies the name of the Windows Event Log to query.

    .PARAMETER EventId
        Specifies the event ID to retrieve. Must be greater than or equal to 0.

    .PARAMETER IncludeRawXml
        Includes the raw XML representation of the event in the formatted output.
        This parameter has no effect unless -AsFormattedString is specified.

    .PARAMETER AsFormattedString
        Returns a formatted string representation of the event structure.
        By default, the function returns a structured object.

    .OUTPUTS
        PSCustomObject
            Default output (structured event data)
        
        System.String
            When -AsFormattedString is specified
    #>

    [CmdletBinding(DefaultParameterSetName = 'Object')]
    param (
        # LogName:
        # Required to uniquely identify the event source.  Event IDs are not globally unique
        # Only basic validation is applied; existence is validated at runtime.
        [Parameter(Mandatory = $true, ParameterSetName = 'Object')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Formatted')]
        [ValidateNotNullOrEmpty()]
        [string]$LogName,

        # EventId:
        # Must be a non-negative integer (Event ID 0 is valid).
        [Parameter(Mandatory = $true, ParameterSetName ='Object')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Formatted')]
        [ValidateScript({
            if ($_ -ge 0) { return $true }
            throw "EventId must be greater than or equal to 0." 
        })]
        [int]$EventId,

        # IncludeRawXml:
        # Optional switch to include raw XML in formatted output.
        [Parameter(ParameterSetName = 'Formatted')]
        [switch]$IncludeRawXml,

        [Parameter(Mandatory = $true, ParameterSetName = 'Formatted')]
        [switch]$AsFormattedString
    )

    # Retrieve event
    $eventRecord = Get-SingleWinEvent -LogName $LogName -EventId $EventId


    # Build structure
    $eventStructure = ConvertTo-WinEventStructure -EventRecord $eventRecord

    # Return object directly for Object parameter set
    if ($PSCmdlet.ParameterSetName -eq 'Object') {
        return $eventStructure
    }

    # Format output
    $output = Format-EventStructure -EventStructure $eventStructure

    # Include RawXml if requested
    if ($IncludeRawXml) {
        $output += ""
        $output += "=== RawXml ==="
        $output += $eventRecord.ToXml()
    }

    return $output

}