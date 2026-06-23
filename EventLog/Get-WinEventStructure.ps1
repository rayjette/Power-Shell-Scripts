function Get-WinEventStructure {

    <#
    .SYNOPSIS
        Retrieves the structural representation of a Windows Event Log entry.

    .DESCRIPTION
        Obtains a single event from the specified log and event ID, and produces
        a structured representation to support field discovery and analysis.

        The structure includes:
        - All System property names present in the event
        - EventData fields (if present)
        - UserData fields and wrappers (if present)

        System properties are included with their values as present in the event instance.

        Payload fields (EventData and UserData) are included with their discovered
        field names and corresponding values from the event instance.
        
        Supports both EventData and UserData payloads.  An error is thrown if a
        matching event cannot be found.

    .PARAMETER LogName
        Specifies the name of the Windows Event Log to query.

    .PARAMETER EventID
        Specifies the event ID to retrieve.

    .PARAMETER IncludeRawXml
        Includes the raw XML representation of the event in the output.

    .OUTPUTS
        PSCustomObject
    #>

    [CmdletBinding()]
    param (
        # LogName:
        # Required to uniquely identify the event source.  Event IDs are not globally unique
        # Only basic validation is applied; existence is validated at runtime.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LogName,

        # EventId:
        # Must be a non-negative integer (Event ID 0 is valid).
        # Using [Nullable[int]] to prevent $null from coercing to 0.
        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if ($_ -ge 0) { return $true }
            throw "EventId must be greater than or equal to 0." 
        })]
        [Nullable[int]]$EventId,

        # IncludeRawXml:
        # Optional diagnostic switch to expose raw XML without affecting default output.
        [Parameter()]
        [switch]$IncludeRawXml
    )


    function Get-EventRecord {

        <#
        .SYNOPSIS
            Returns a single event record matching the given log name and event ID, or throws
            if none exist.

        .DESCRIPTION
            Retrieves a single event record for the specified log name and event ID.
            The function enforces correctness by throwing if no matching event is returned.
            When multiple matches exist, the first returned event is used.
        #>
        param (
            [string]$LogName,
            [int]$EventId
        )

        $filter = @{
            LogName = $LogName
            Id      = $EventId
        }

        $event = Get-WinEvent -FilterHashtable $filter -MaxEvents 1

        if ($null -eq  $event) {
            throw "No event found for LogName '$LogName' with EventId '$EventId'."
        }

        return $event 

    }


    function ConvertTo-EventStructure {

        <#
        .SYNOPSIS
            Converts an event record into a structured representation.

        .DESCRIPTION
            Takes a raw event record and extracts its structural components,
            including System properties, EventData, and UserData.
            The function assumes the event can be converted to valid XML and
            throws if the structure cannot be processed.
        #>

        [CmdletBinding()]
        param (
            [System.Diagnostics.Eventing.Reader.EventLogRecord]$event
        )

        $xml = [xml]$event.ToXml()

        # Output container (normalized shape)
        $eventStructure = @{
            EventData = @{}
            UserData = @{
                Wrapper = $null
                Fields = @{}
            }
        }

        # Extract payload (EventData or UserData)
        
        # decide which payload exists in the event
        if ($xml.Event.EventData) {

            foreach ($prop in $xml.Event.EventData.Data) {
                $eventStructure.EventData[$prop.Name] = $prop.InnerText
            }

        }
        elseif ($xml.Event.UserData) {

            $wrapper = $xml.Event.UserData.ChildNodes[0]

            foreach ($node in $wrapper.ChildNodes) {
                $eventStructure.UserData.Fields[$node.Name] = $node.InnerText
            }

        }
        else {
            # neither exists (both remain empty)
        }

        $system = @{}

        foreach ($node in $xml.Event.System.ChildNodes) {

            # Case 1: Node has attributes
            if ($node.Attributes) {

                foreach ($attr in $node.Attributes) {
    
                    $propertyName = "$($node.LocalName)$($attr.Name)"

                    $system[$propertyName] = $attr.Value

                }
            }

            # Case 2: Node has text value
            elseif ($node.InnerText -and $node.InnerText.Trim() -ne '') {

                $system[$node.LocalName] = $node.InnerText
            }

        }

        $eventStructure.System = $system

        return $eventStructure
    }


    # ======================
    # RETRIEVE EVENT
    # ======================

    $event = Get-EventRecord -LogName $LogName -EventId $EventId


    # ======================
    # BUILD STRUCTURE
    # ======================  
    $eventStructure = ConvertTo-EventStructure -event $event


    # ======================
    # FORMAT OUTPUT
    # ======================

    $output = @()

    # System
    $output += "=== System ==="

    foreach ($key in $eventStructure.System.Keys | Sort-Object) {
        $value = $eventStructure.System[$key]
        $output += "{0, -30} : {1}" -f $key, $value
    }

    # EventData
    $output += ""
    $output += "=== EventData ==="

    foreach ($key in $eventStructure.EventData.Keys | Sort-Object) {
        $output += "{0, -30} : {1}" -f $key,
            $eventStructure.EventData[$key]
    }

    # UserData
    $output += ""
    $output += "=== UserData ==="

    if ($eventStructure.UserData.Wrapper) {
        $output += "Wrapper: $($eventStructure.UserData.Wrapper)"
    }
    else {
        $output += "Wrapper: <none>"
    }

    if ($eventStructure.UserData.Fields.Count -gt 0) {
        foreach ($key in $eventStructure.UserData.Fields.Keys | Sort-Object) {
            $value = $eventStructure.UserData.Fields[$key]
            $output += "{0, -30} : {1}" -f $key, $value
        }
    }
    else {
        $output += "Fields : <none>"
    }
  

    # Raw XML
    if ($IncludeRawXml) {
        $output += ""
        $output += "=== RawXml ==="
        $output += $event.ToXml()
    }

    # ======================
    # RETURN OUTPUT
    # ======================
    $output -join "`n"

}