#Requires -RunAsAdministrator

function Get-NTLMAuthenticationEvent {

    <#
    .SYNOPSIS
        Retrieves NTLM authentication events from the local system.

    .DESCRIPTION
        Retrieves NTLM authentication events from the 
        Microsoft-Windows-NTLM/Operational log on the local system
        and returns them as PowerShell objects.

        NTLM auditing must be enabled for this command to return data.

        Filtering parameters (User, Target, Source) support case-insensitive
        matching and PowerShell wildcard patterns.

        The Days, Hours, and TimeRange parameters are mutually exclusive.
        If no time parameters are specified, events from the last 7 days are returned.

        A specific time range can be provided using the StartTime and
        EndTime parameters.

    .PARAMETER Days
        Specifies the number of days to look back when retrieving NTLM
        events.

    .PARAMETER Hours
        Specifies the number of hours to look back when retrieving NTLM
        events.

    .PARAMETER StartTime
        Specifies the beginning of the time range used to retrieve NTLM events.

    .PARAMETER EndTime
        Specifies the end of the time range used to retrieve NTLM events.

    .PARAMETER Target
        Filters on the target system or service being authenticated to.  This is
        typically represented as a service principal name (SPN), such as
        Cifs/server or TERMSRV/hostname.

        Supports case-insensitive matching and wildcard patterns.

        Examples:
            -Target "cifs/server1"
            -Target "cifs/*"

    .PARAMETER Source
        Filters on the system initiating the NTLM authentication.  For outbound
        events this is the local system.  For inbound events this is the remote
        client (WorkstationName).

        Supports case-insensitive matching and wildcard patterns.

        Examples:
            -Source "WS01"
            -Source "WS-*"

    .PARAMETER User
        Filters on the authenticated user account (DomainName\UserName)
        contained in the NTLM event.  This represents the identity being
        validated, not necessarily the calling context.

        Supports case-insensitive matching and wildcard patters.

        Examples:
            -User "DOMAIN\User1"
            -User "*admin*"

    .PARAMETER IncludeRaw
        Includes the original event record in the output.

    .OUTPUTS
        Objects containing normalized NTLM authentication fields along with
        an EventData property that includes all original event fields.

    .EXAMPLE
        Get-NTLMAuthenticationEvent

        Retrieves NTLM authentication events from the last 7 days (default behavior)

    .EXAMPLE
        Get-NTLMAuthenticationEvent -Days 1

        Retrieves NTLM authentication events from the last 24 hours.

    .EXAMPLE
        Get-NTLMAuthenticationEvent -Hours 6

        Retrieves NTLM authentication events from the last 6 hours.

    .EXAMPLE
        Get-NTLMAuthenticationEvent -StartTime (Get-Date).AddHours(-12) -EndTime (Get-Date)

        Retrieves NTLM authentication events from a specific time range.

    .EXAMPLE
        Get-NTLMAuthenticationEvent -User "DOMAIN\User1"

        Retrieves NTLM events for a specific user (exact match).

    .EXAMPLE 
        Get-NTLMAuthenticationEvent -User "*admin*"

        Retrieves NTLM events for any user matching a wildcard pattern (case-insensitive).

    .EXAMPLE
        Get-NTLMAuthenticationEvent -Target "cifs/server1"

        Retrieves NTLM events targeting a specific service/server.

    .EXAMPLE
        Get-NTLMAuthenticationEvent -Target "cifs/*"

        Retrieves NTLM events targeting any CIFS/SMB service.

    .EXAMPLE
        Get-NTLMAuthenticationEvent -Source "WS01"

        Retrieves NTLM events originating from a specific source workstation.

    .EXAMPLE
        Get-NTLMAuthenticationEvent -Source "WS-*"

        Retrieves NTLM events from all workstations matching a naming pattern.

    .EXAMPLE
        Get-NTLMAuthenticationEvent -User "*svc*" -Target "cifs/*"

        Retrieves NTLM events involving service accounts accessing CIFS resources.

    .EXAMPLE
        Get-NTLMAuthenticationEvent -Source "WS-01" -User "DOMAIN\User1"

        Retrieves NTLM events for a specific user from a specific source system.

    .EXAMPLE
        Get-NTLMAuthenticationEvent -IncludeRaw

        Retrieves NTLM events and includes the raw event record in the output.

    .EXAMPLE
        Get-NTLMAuthenticationEvent -User "*admin*" -Hours 4

        Retrieves NTLM events from the last 4 hours involving accounts matching "*admin*".

    .EXAMPLE
        Get-NTLMAuthenticationEvent | Where-Object EventId -eq 8003

        Retrieves only incoming NTLM authentication audit events.

    .EXAMPLE
        Get-NTLMAuthenticationEvent | Group-Object User | Sort-Object Count -Descending

        Identifies the most frequently used NTLM accounts. 

    .NOTES
        The Microsoft-Windows-NTLM/Operational log must be enabled for
        this function to return data.

        NTLM auditing policies may also need to be configured depending
        on the environment.

        ProcessId is derived from the event ProcessId field when present,
        or CallerPID when ProcessId is not populated.

        Event fields containing the literal value "(NULL)" are normalized
        to $null in the output.
    #>

    [CmdletBinding(DefaultParameterSetName = 'Days')]
    param (
        [Parameter(ParameterSetName = 'Days')]
        [int]$Days = 7,

        [Parameter(ParameterSetName = 'Hours')]
        [int]$Hours,

        [Parameter(
            ParameterSetName = 'TimeRange',
            Mandatory = $true
        )]
        [DateTime]$StartTime,

        [Parameter(
            ParameterSetName = 'TimeRange',
            Mandatory = $true
        )]
        [DateTime]$EndTime,
        
        [string[]]$Target,

        [string[]]$Source,

        [string[]]$User,

        [switch]$IncludeRaw
    )

    begin {


        function Resolve-NTLMValue {
            <#
            .SYNOPSIS
                Normalizes NTLM event field values.

            .DESCRIPTION
                Converts common placeholder or null-like values found in
                NTLM event logs into $null.  This includes values such as
                "(NULL)", "NULL", "-", empty strings, and whitespace-only strings.

            .PARAMETER Value
                The raw string value from the event log.

            .OUTPUTS
                System.String or $null

            .NOTES
                This helper function standardizes event data fields so that
                downstream logic does not need to handle inconsistent null
                representations from Windows event logs.
            #>
            [CmdletBinding()]
            param (
                [AllowNull()]
                [string]$Value
            )

            # Normalize common NTLM "null-like" values
            if ([string]::IsNullOrWhiteSpace($Value)) {
                return $null
            }

            if ($Value -in '(NULL)', 'NULL', '-') {
                return $null
            }

            return $Value
        }


        function Resolve-IntValue {
            <#
            .SYNOPSIS
                Normalizes and converts NTLM event numeric fields.

            .DESCRIPTION
                Takes a raw value from an NTLM event field (such as ProcessId
                or CallerPID), normalizes it using Resolve-NTLMValue, and
                attempts to convert it to an integer.

                If the value is null, empty, or contains placeholder values
                such as "(NULL)", "NULL", or "-", the function returns $null.

            .PARAMETER Value
                The raw value form the event log field.

            .OUTPUTS
                System.Int32 or $null

            .NOTES
                This function does not implement fallback logic between
                multiple fields (e.g., ProcessId vs CallerPID).  That logic
                should remain in the calling code to preserve event-specific
                behavior.
            #>

            param (
                $Value
            )

            $val = Resolve-NTLMValue $Value
            if ($null -ne $val) {
                return [int]$val
            }

            return $null
        }


        function Resolve-User {
            <#
            .SYNOPSIS
                Builds a normalized NTLM user string.

            .DESCRIPTION
                Combines Domain and Username into a normalized identity string.
                Returns "DOMAIN\User" when both are present, or just "User"
                when only the username is available.

            .PARAMETER Domain
                The domain portion of the identity.

            .PARAMETER Username
                The username portion of the identity.

            .OUTPUTS
                System.String or $null
            #>

            param (
                $Domain,
                $Username
            )

            if ($Domain -and $Username) {
                return "$Domain\$Username"
            }

            if ($Username) {
                return $Username
            }

            return $null
        }


        if ($PSCmdlet.ParameterSetName -eq 'Days') {

            $EndTime = Get-Date
            $StartTime = $EndTime.AddDays(-$Days)

        }

        elseif ($PSCmdlet.ParameterSetName -eq 'Hours') {
            $EndTime = Get-Date
            $StartTime = $EndTime.AddHours(-$Hours)
        }

        elseif ($PSCmdlet.ParameterSetName -eq 'TimeRange') {

        }

        else {
            throw "Unexpected parameter set"
        }

        $filter = @{
            LogName     = 'Microsoft-Windows-NTLM/Operational'
            Id          = 8001, 8002, 8003, 8004
            StartTime   = $StartTime
            EndTime     = $EndTime
        }

    }

    process {

        Get-WinEvent -FilterHashtable $filter | ForEach-Object {

            # System metadata
            $timeCreated = $_.TimeCreated
            $eventId     = $_.Id
            $computer    = $_.MachineName

            # XML parsing
            $xml = [xml]$_.ToXml()

            $map = @{}
            foreach ($property in $xml.Event.EventData.Data) {
                $map[$property.Name] = $property.'#text'
            }
            
            # Event-specific normalization
            switch ($eventId) {

                8001 {

                    # Resolve domain
                    $domain = Resolve-NTLMValue $map.DomainName

                    # Resolve username
                    $username = Resolve-NTLMValue $map.UserName

                    # Build user
                    $normalizedUser = Resolve-User $domain $username

                    # Resolve process ID
                    $processId = Resolve-IntValue $map.ProcessId

                    if (-not $processId) {
                        $processId = Resolve-IntValue $map.CallerPID
                    }

                    # Final object
                    $normalized = [PSCustomObject]@{
                        User        = $normalizedUser
                        Domain      = $domain
                        Source      = $computer
                        Target      = Resolve-NTLMValue $map.TargetName
                        ProcessName = Resolve-NTLMValue $map.ProcessName
                        ProcessId   = $processId
                    }
                }

                8002 {

                    # Resolve domain
                    $domain = Resolve-NTLMValue $map.ClientDomainName

                    # Resolve username
                    $username = Resolve-NTLMValue $map.ClientUserName

                    # Build user
                    $normalizedUser = Resolve-User $domain $username

                    # Resolve process ID
                    $processId = Resolve-IntValue $map.ProcessId

                    if (-not $processId) {
                        $processId = Resolve-IntValue $map.CallerPID
                    }

                    # Resolve process name
                    $processName = Resolve-NTLMValue $map.ProcessName
                    
                    # Final object 
                    $normalized = [PSCustomObject]@{
                        User        = $normalizedUser
                        Domain      = $domain
                        Source      = $computer
                        Target      = Resolve-NTLMValue $map.TargetName
                        ProcessName = $processName
                        ProcessId   = $processId
                    }
                }

                8003 {

                    # Resolve domain
                    $domain = Resolve-NTLMValue $map.DomainName

                    # Resolve username
                    $username = Resolve-NTLMValue $map.UserName

                    # Fallbacks (important for 8003)
                    if (-not $username) {
                        $username = Resolve-NTLMValue $map.AccountName
                    }

                    if (-not $domain) {
                        $domain = Resolve-NTLMValue $map.AccountDomain
                    }

                    # Build user event if partial
                    $normalizedUser = Resolve-User $domain $username

                    # Resolve process ID
                    $processId = Resolve-IntValue $map.ProcessId

                    if (-not $processId) {
                        $processId = Resolve-IntValue $map.CallerPID
                    }

                    # Resolve process name
                    $processName = Resolve-NTLMValue $map.ProcessName

                    # Resolve source
                    $ws = Resolve-NTLMValue $map.WorkstationName
                    if (-not $ws) {
                        $ws = Resolve-NTLMValue $map.Workstation
                    }

                    $source = $ws

                    # Final object
                    $normalized = [PSCustomObject]@{
                        User        = $normalizedUser
                        Domain      = $domain
                        Source      = $source
                        Target      = $computer
                        ProcessName = $processName
                        ProcessId   = $processId
                    }                    
                }

                8004 {

                    # Resolve domain
                    $domain = Resolve-NTLMValue $map.DomainName

                    # Resolve username
                    $username = Resolve-NTLMValue $map.UserName

                    # Build user
                    $normalizedUser = Resolve-User $domain $username

                    # Resolve process ID 
                    $processId = Resolve-IntValue $map.ProcessId

                    if (-not $processId) {
                        $processId = Resolve-IntValue $map.CallerPID
                    }

                    # Resolve process name
                    $processName = Resolve-NTLMValue $map.ProcessName

                    # Resolve target
                    $target = Resolve-NTLMValue $map.SChannelName
                    if (-not $target) {
                        $target = $computer
                    }

                    # Resolve source
                    $ws = Resolve-NTLMValue $map.WorkstationName
                    if (-not $ws) {
                        $ws = Resolve-NTLMValue $map.Workstation
                    }

                    $source = $ws

                    # Final object
                    $normalized = [PSCustomObject]@{
                        User        = $normalizedUser
                        Domain      = $domain
                        Source      = $source
                        Target      = $target
                        ProcessName = $processName
                        ProcessId   = $processId
                    }
                }

                default {
                    continue
                }
            }

            # Result mapping
            $eventType = switch ($eventId) {
                8001    { 'Outgoing NTLM Authentication - Audit' }
                8002    { 'Outgoing NTLM Authentication - Blocked' }
                8003    { 'Incoming NTLM Authentication - Audit' }
                8004    { 'Incoming NTLM Authentication - Blocked' }
                default { 'Unknown' }
            }

            # Apply filters
            if ($User) {
                $match = $false
                foreach ($pattern in $User) {
                    if($normalized.User -like $pattern) {
                        $match = $true
                        break
                    }
                }
                if (-not $match) {
                    return
                }
            }

            if ($Target) {
                $match = $false
                foreach ($pattern in $Target) {
                    if ($normalized.Target -like $pattern) {
                        $match = $true
                        break
                    }
                }
                if (-not $match) {
                    return
                }
            }

            if ($Source) {
                $match = $false
                foreach ($pattern in $Source) {
                    if ($normalized.Source -like $pattern) {
                        $match = $true
                        break
                    }
                }
                if (-not $match) {
                    return
                }
            }

            # Final clean output object
            $output = [PSCustomObject]@{
                TimeCreated  = $timeCreated
                EventId      = $eventId
                EventType    = $eventType

                User         = $normalized.User
                Domain       = $normalized.Domain
                Source       = $normalized.Source
                Target       = $normalized.Target

                ProcessName  = $normalized.ProcessName
                ProcessId    = $normalized.ProcessId

                EventData    = [PSCustomObject]$map
            }

            if ($IncludeRaw) {
                Add-Member -InputObject $output -NotePropertyName RawEvent -NotePropertyValue $_
            }

            $output
        }
    }

    end {

    }
}