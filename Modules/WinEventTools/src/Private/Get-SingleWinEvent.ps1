    function Get-SingleWinEvent {
        <#
        .SYNOPSIS
            Retrieves a single Windows Event Log record.

        .DESCRIPTION
            Queries the Windows Event Log using the specified log name and event ID,
            returning the first matching event record.

            This function enforces a strict contract:
            - Returns exactly one event when a match is found
            - Throws an exception if no matching event exists

            When multiple events match the criteria, the first returned event returned
            by Get-WinEvent is used.

            This function is intended for internal module use where a valid event
            record is required for further processing.

        .PARAMETER LogName
            The name of the Windows Event Log to query.

        .PARAMETER EventId
            The event ID to retrieve.

        .OUTPUTS
            System.Diagnostics.Eventing.Reader.EventLogRecord

        .NOTES
            Private helper function. Not intended for public use.
        #>

        param (
            [Parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string]$LogName,

            [Parameter(Mandatory = $true)]
            [ValidateScript({
                if ($_ -ge 0) { return $true }
                throw "EventId must be greater than or equal to 0."
            })]
            [int]$EventId
        )

        $filter = @{
            LogName = $LogName
            Id      = $EventId
        }

        $eventRecord = Get-WinEvent -FilterHashtable $filter -MaxEvents 1

        if ($null -eq $eventRecord) {
            throw "No event found for LogName '$LogName' with EventId '$EventId'."
        }

        return $eventRecord

    }