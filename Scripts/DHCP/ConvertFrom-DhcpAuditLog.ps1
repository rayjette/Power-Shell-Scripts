function ConvertFrom-DhcpAuditLog {
    <#
    .SYNOPSIS
        Converts a Windows DHCP audit log into structured PowerShell objects.

    .DESCRIPTION
        Reads a Windows DHCP audit log and converts its entries into structured
        PowerShell objects.

        The function locates the CSV header in the audit log, parses each record,
        converts the event ID to an integer, resolves the event ID to a descriptive
        event name, and converts the date and time into a DateTime value.

        Event IDs that are not recognized are assigned an EventName of 'Unknown'.
        The original CSV record is preserved in the Raw property.

    .PARAMETER Path
        Specifies the path to the Windows DHCP audit log file.

    .OUTPUTS
        DhcpAuditLog.Entry

        Returns one DhcpAuditLog.Entry object for each DHCP audit log record.
        The object contains parsed event information, a Timestamp property
        containing a DateTime value, and the original CSV record in the Raw property.

    .EXAMPLE
        ConvertFrom-DhcpAuditLog -Path 'C:\Windows\System32\dhcp\DhcpSrvLog-Wed.Log'

        Converts the DHCP audit log into structured objects.

    .EXAMPLE
        ConvertFrom-DhcpAuditLog -Path 'C:\Windows\System32\dhcp\DhcpSrvLog-Wed.log' |
            Where-Object EventName -eq 'LeaseRenewed'

        Returns DHCP lease renewal events from the audit log.

    .EXAMPLE
        ConvertFrom-DhcpAuditLog -Path 'C:\Windows\System32\dhcp\DhcpSrvLog-Wed.log' |
            Where-Object EventName -eq 'LeaseRenewed' |
            Select-Object Timestamp, IPAddress, HostName, MACAddress

        Returns the timestamp and client information for DHCP lease renewal events.

    .NOTES
        Author: Raymond Jette

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    # Maps DHCP audit log event IDs to descriptive event names.
    $eventNameById = @{
        0  = 'LogStarted'
        1  = 'LogStopped'
        2  = 'LogPausedLowDiskSpace'
        10 = 'LeaseAssigned'
        11 = 'LeaseRenewed'
        12 = 'LeaseReleased'
        13 = 'AddressConflictDetected'
        14 = 'AddressPoolExhausted'
        15 = 'LeaseDenied'
        16 = 'LeaseDeleted'
        17 = 'LeaseExpiredDnsRecordNotDeleted'
        18 = 'LeaseExpiredDnsDeleted'
        20 = 'BootpLeaseAssigned'
        21 = 'BootpDynamicLeaseAssigned'
        22 = 'BootpAddressPoolExhausted'
        23 = 'BootpAddressDeleted'
        24 = 'IpAddressCleanupStarted'
        25 = 'IpAddressCleanupStatistics'
        30 = 'DnsUpdateRequest'
        31 = 'DnsUpdateFailed'
        32 = 'DnsUpdateSuccessful'
        33 = 'NapPacketDropped'
        34 = 'DnsUpdateQueueLimitExceeded'
        35 = 'DnsUpdateRequestFailed'
        36 = 'FailoverPacketDropped'
        50 = 'AuditLogStarted'
        51 = 'AuditLogStopped'
        55 = 'DhcpServerAuthorized'
        56 = 'DhcpServerNotAuthorized'
        57 = 'DhcpServerAlreadyExists'
        58 = 'DhcpServerDomainNotFound'
        59 = 'DhcpServerAuthorizationCheckFailed'
        60 = 'DhcpFailoverStateChanged'
        61 = 'DhcpFailoverCommunicationError'
        62 = 'DhcpFailoverCommunicationRestored'
    }

    # DHCP audit log contains header information before the CSV data.
    $headerFound = $false
    
    $csvLines = foreach ($line in Get-Content -LiteralPath $Path -ErrorAction Stop) {
        if (-not $headerFound) {
            if ($line -like 'ID,Date,Time,*') {
                $headerFound = $true
            }
            else {
                continue
            }
        }

        $line
    }

    if (-not $headerFound) {
        throw "Unable to locate DHCP audit log header."
    }

    foreach ($entry in ($csvLines | ConvertFrom-Csv)) {

        $eventId = [int]$entry.ID

        $eventName = if ($eventNameById.ContainsKey($eventID)) {
            $eventNameById[$eventId]
        } else {
            'Unknown'
        }

        try {
            $timestamp = [datetime]::ParseExact(
                "$($entry.Date) $($entry.Time)",
                'MM/dd/yy HH:mm:ss',
                [CultureInfo]::InvariantCulture
            )
        }
        catch {
            throw "Unable to parse DHCP audit log timestamp '$($entry.Date) $($entry.Time)'."
        }

        [pscustomobject]@{
            PSTypeName = 'DhcpAuditLog.Entry'

            EventId              = [int]$entry.ID
            EventName            = $eventName
            Description          = $entry.Description

            Timestamp            = $timestamp

            IPAddress            = $entry.'IP Address'
            HostName             = $entry.'Host Name'
            MACAddress           = $entry.'MAC Address'
            UserName             = $entry.'User Name'

            TransactionId        = $entry.TransactionID
            QResult              = $entry.QResult
            ProbationTime        = $entry.ProbationTime
            CorrelationId        = $entry.CorrelationID
            DhcId                = $entry.Dhcid

            VendorClassHex       = $entry.'VendorClass(Hex)'
            VendorClassAscii     = $entry.'VendorClass(ASCII)'
            UserClassHex         = $entry.'UserClass(Hex)'
            UserClassAscii       = $entry.'UserClass(ASCII)'

            RelayAgentInformation = $entry.RelayAgentInformation
            DnsRegError           = $entry.DnsRegError

            Raw                  = $entry
        }
    }
}