function New-WinEventXPathFilter {
    <#
    .SYNOPSIS
        Builds an XPath query for filtering Windows Event Logs using Get-WinEvent.

    .DESCRIPTION
        Generates a valid XPath expression for querying Windows Event Logs.

        The function supports a structured filtering model consisting of:

            1. System Filter (fixed schema)
                - EventID (int array)
                - StartTime (datetime)
                - EndTime (datetime)

            2. Data Filter (dynamic schema)
                - Hashtable of EventData field filters
                - Each key represents an EventData field name
                - Each value may be:
                    - a single value
                    - or an array of values

        OUTPUT FORMATS
            The function supports two output formats:

                - Compact (default)
                    A single-line XPath expression suitable for direct use with Get-WinEvent.

                - Pretty
                    A multi-line formatted XPath expression intended for debugging.

       LOGICAL MODEL

            A. Within a single field (DataFilter values):
                - Multiple values are combined using OR logic.

                Example:
                    TargetUserName = 'jsmith', 'mjones'

                Becomes:
                    (TargetUserName='jsmith' OR TargetUserName='mjones')

            B. Between different fields:
            - Fields are combined using AND logic.

                Example:
                    TargetUserName AND LogonType

                Becomes:
                    (User condition) AND (LogonType condition)

            C. System vs EventData:
            - System filters and EventData filters are independent blocks
            - Both blocks are combined using AND logic

        FINAL XPATH STRUCTURE:

        *[
            System[ ... ]
            AND
            EventData[ ... ]
        ]
       
    .PARAMETER EventID
        One or more Event IDs to filter on.
        Multiple values are combined using OR logic.

    .PARAMETER StartTime
        Start of the range filter (inclusive).

    .PARAMETER EndTime
        End of time range filter (inclusive).

    .PARAMETER DataFilter
        Hashtable of EventData filters.

        key = EventData field name
        Value = single value or array of values

        Example:
            @{
                TargetUsername = 'jsmith', 'mjones'
                LogonType      = 10, 2
            }

    .PARAMETER Format
        Specifies output formatting mode.

        Valid values:

        - compact (default)
            Returns a single-line XPath expression suitable for execution.
        
        - Pretty
            Returns a multi-line formatted XPath expression with indentation,
            used for debugging and readability.

    .EXAMPLE
        New-WinEventXPath -EventID 4624 -DataFilter @{
            TargetUserName = 'jsmith', 'mjones'
            LogonType      = 10
        }

    .OUTPUTS
        System.String
        Returns an XPath query string in either Compact or Pretty format.
    #>

    param (
        [int[]]$EventID,

        [string[]]$ProviderName,

        [datetime]$StartTime,
        [datetime]$EndTime,

        [hashtable]$DataFilter,

        [ValidateSet('Compact', 'Pretty')]
        [string]$Format = 'Compact'
    )

    # SYSTEM
    $systemExpressions = @()

    # EventID
    if ($EventID -and $EventID.Count -gt 0) {

        $eventIdExpressions = foreach ($id in $EventID) {
            "EventID=$id"
        }

        $systemExpressions += Join-OrGroup -Expression $eventIdExpressions
    }

    # providerName 
    if ($ProviderName -and $ProviderName.Count -gt 0) {
        
        $providerExpressions = foreach ($name in $ProviderName) {
            $formattedName = ConvertTo-XPathStringLiteral -Value $name
            "Provider[@Name=$formattedName]"
        }

        $systemExpressions += Join-OrGroup -Expression $providerExpressions

    }

    $timeParams = @{}

    if ($StartTime) {
        $timeParams.StartTime = $StartTime
    }

    if ($EndTime) {
        $timeParams.EndTime = $EndTime
    }

    if ($timeParams.Count -gt 0) {
        $timeExpression = ConvertTo-WinEventTimeCreatedXPathExpression @timeParams
    }

    if ($timeExpression) {
        $systemExpressions += $timeExpression
    }

    # Combine System
    if ($systemExpressions.Count -gt 0) {
        $systemBlock = Join-AndGroup -Expression $systemExpressions
        $systemBlock = "System[$systemBlock]"
    }

    # EVENTDATA
    $eventDataExpressions = @()

    if ($DataFilter -and $DataFilter.Count -gt 0) {
        foreach ($key in $DataFilter.Keys) {

            $values = $DataFilter[$key]

            # Normalize scaler -> array
            if ($values -isnot [System.Collections.IEnumerable] -or $values -is [string]) {
                $values = @($values)
            }

            $expr = ConvertTo-WinEventDataXPathExpression -FieldName $key -Values $values
            $eventDataExpressions += $expr
        }
    }

    # Combine EventData
    if ($eventDataExpressions.Count -gt 0) {
        $eventDataBlock = Join-AndGroup -Expression $eventDataExpressions
        $eventDataBlock = "EventData[$eventDataBlock]"
    }

    $finalExpressions = @()

    if ($systemBlock) {
        $finalExpressions += $systemBlock
    }

    if ($eventDataBlock) {
        $finalExpressions += $eventDataBlock
    }

    if ($finalExpressions.Count -gt 0) {
        $final = Join-AndGroup -Expression $finalExpressions
        $xpath = "*[$final]"
    }

    # NOTE:
    # Pretty formatting is best-effort and intended for readability/debugging only.
    # This version avoids fragile global string replacements by formatting known blocks.
    if ($Format -eq 'Pretty' -and $finalExpressions.Count -gt 0) {

        $pretty = @()
        $pretty += "*["

        if ($systemBlock) {
            $pretty += "    System["
            $pretty += "        $($systemBlock -replace '^System\[|\]$','')"
            $pretty += "    ]"
        }

        if ($systemBlock -and $eventDataBlock) {
            $pretty += "    AND"
        }

        if ($eventDataBlock) {
            $pretty += "    EventData["
            $pretty += "        $($eventDataBlock -replace '^EventData\[|\]$','')"
            $pretty += "    ]"
        }

        $pretty += "]"

        $xpath = ($pretty -join "`n")
    }

    return $xpath

}