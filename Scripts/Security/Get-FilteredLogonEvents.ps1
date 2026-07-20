#Requires -RunAsAdministrator


function Get-FilteredLogonEvents {
    <#
    .SYNOPSIS
        Retrieves successful and failed Windows Logon events from the security event log.

    .DESCRIPTION
        Queries the Security event log for Event ID 4624 (successful logons)
        and Event ID 4625 (failed logons), returning structured objects that represent
        authentication activity.
        
        Filtering behavior:
        - Filters are applied during query execution using XPath for performance.
        - Some filters (such as exclusions) are enforced after retrieval
          due to limitations in XPath expression semantics.

    .PARAMETER UserName
        Filters events by TargetUserName field.

    .PARAMETER LogonType
        Includes only the specified Logon types.

    .PARAMETER ExcludeLogonType
        Excludes the specified Logon types.

    .PARAMETER StartTime
        Returns only events occurring  on or after the specified date and time.

    .OUTPUTS
        System.Management.Automation.PSCustomObject

        Objects returned have a PSTypeName of:
        WindowsSecurityAuthenticationEvent

    .EXAMPLE
        Get-FilteredLogonEvents

        Returns all successful and failed logon events.

    .EXAMPLE
        Get-FilteredLogonEvents -UserName Administrator

        Returns Logon events for the Administrator account.

    .EXAMPLE
        Get-FilteredLogonEvents -LogonType RemoteInteractive

        Returns RDP Logon events.

    .NOTES
        Author: Raymond Jette
        Date: 6/17/2026

        Requires permission to read the Security event Log.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(ParameterSetName = 'All')]
        [Parameter(ParameterSetName = 'Include')]
        [Parameter(ParameterSetName = 'Exclude')]
        [string]$UserName,

        [Parameter(ParameterSetName = 'Include')]
        [ValidateSet(
            'Interactive',
            'Network',
            'Batch',
            'Service',
            'Unlock',
            'NetworkCleartext',
            "NewCredentials",
            "RemoteInteractive",
            "CachedInteractive"
        )]
        [string[]]$LogonType,
        
        [Parameter(ParameterSetName = 'Exclude')]
        [ValidateSet(
            'Interactive',
            'Network',
            'Batch',
            'Service',
            'Unlock',
            'NetworkCleartext',
            "NewCredentials",
            "RemoteInteractive",
            "CachedInteractive"
        )]
        [string[]]$ExcludeLogonType,

        [Parameter(ParameterSetName = 'All')]
        [Parameter(ParameterSetName = 'Include')]
        [Parameter(ParameterSetName = 'Exclude')]
        [datetime]$StartTime
    )

    function New-LogonEventQuery {
        param(
            [hashtable]$LogonTypeMap, 

            [string]$UserName,

            [string[]]$IncludeLogonType,

            [string[]]$ExcludeLogonType,

            [Nullable[datetime]]$StartTime
        )

        # DESIGN:
        # Builds XPath query for Security log retrieval.
        #
        # Responsibilities:
        # - Apply filters that XPath handles correctly and effeciently:
        #   - EventID
        #   - StartTime
        #   - Exact username match
        #   - Included logon types
        #
        # Known limitation:
        # - Exclusion logic using "!=" combined with OR does not behave
        #   correctly in XPath.  Final enforcement occurs later in PowerShell.
        $systemFilters = @(
            "(EventID=4624 or EventID=4625)"
        )

        if ($StartTime) {
            $startUtc = $StartTime.ToUniversalTime().ToString("o")
            $systemFilters += "TimeCreated[@SystemTime >= '$startUtc']"
        }

        $eventDataFilters = @()

        # Exact username filtering
        #if ($UserName -and ($UserName -notmatch '[\*\?]')) {
        if ($UserName) {
            $eventDataFilters += "Data[@Name='TargetUserName']='$UserName'"
        }

        # Include logon types (OR semantics)
        foreach ($type in $IncludeLogonType) {
            $eventDataFilters += "Data[@Name='LogonType']='$($logonTypeMap[$type])'"
        }

        # NOTE:
        # this exclusion logic is NOT fully correct in XPath de to OR  semantics.
        # It reains here but is reinforced alter in Test-LogonEventMatch.
        foreach ($type in $ExcludeLogonType) {
            $eventDataFilters += "Data[@Name='LogonType']!='$($logonTypeMap[$type])'"
        }

        $xpathQuery = "*[System[$($systemFilters -join ' and ')]]"


        if ($eventDataFilters.Count -gt 0) {
            $xpathQuery = "*[System[$($systemFilters -join ' and ') ] and EventData[$($eventDataFilters -join ' or ')]]"
        }


        return [System.Diagnostics.Eventing.Reader.EventLogQuery]::new(
            "Security",
            [System.Diagnostics.Eventing.Reader.PathType]::LogName,
            $xpathQuery
        )
    }


    function ConvertFrom-LogonEvent {
        param(
            [System.Diagnostics.Eventing.Reader.EventRecord]$Event,

            [hashtable]$LogonTypeReverseMap
        )

        # Converts raw EventRecord XML into a structured object.
        # Maintains a normalized schema for downstream processing.
        
        $xml = [xml]$Event.ToXml()

        $data = @{}
        foreach ($d in $xml.Event.EventData.Data) {
            $data[$d.Name] = $d.'#text'
        }

        $logonTypeRaw = $data['LogonType']

        $logonTypeValue = $null
        if (-not [string]::IsNullOrWhiteSpace($logonTypeRaw) -and 
                [int]::TryParse($logonTypeRaw, [ref]$logonTypeValue)) {
            
            # do nothing.
        }
        else {
            $logonTypeValue = $null
        }

        $logonTypeName = if ($logonTypeValue) {
            $LogonTypeReverseMap[$logonTypeValue]
        }
        else {
            $null
        }

        $targetUser = $data['TargetUserName']

        $resultType = if ($Event.Id -eq 4624) {
            'Success'
        }
        else {
            'Failure'
        }

        [PSCustomObject]@{
            PSTypeName              = 'WindowsSecurityAuthenticationEvent'

            # Internal use
            LogonTypeValue          = $logonTypeValue

            # Output properties
            TimeCreated             = $Event.TimeCreated
            Result                  = $resultType
            Account                 = $targetUser
            Domain                  = $data['TargetDomainName']
            SubjectAccount          = $data['SubjectUserName']
            SubjectDomain           = $data['SubjectDomainName']
            LogonType               = $logonTypeName
            Workstation             = $data['WorkstationName']
            IPAddress               = $data['IpAddress']
            LogonProcess            = $data['LogonProcessName']
            AuthenticationPackage   = $data['AuthenticationPackageName']
            FailureReason           = $data['FailureReason']
            Status                  = $data['Status']
            SubStatus               = $data['SubStatus']
            ProcessName             = $data['ProcessName']
            ProcessId               = $data['ProcessId']
            LogonGuid               = $data['LogonGuid']
            TargetLogonId           = $data['TargetLogonId']
            TransmittedServices     = $data['TransmittedServices']
            LmPackageName           = $data['LmPackageName']
            KeyLength               = $data['KeyLength']
        }
    }


    function Test-LogonEventMatch {
        param(
            [PSCustomObject]$LogonEvent,

            [int[]]$ExcludeLogonTypes
        )

        # Post-retrieval filtering stage.
        #
        # Responsibility:
        # - Enforce exclusion logic that XPath does not reliably handle
        #
        # This function exists due to XPath limitations and is expected
        # to be removed once exclusion logic is correctly handled in XPath.
        if ($ExcludeLogonTypes -and $null -ne $LogonEvent.LogonTypeValue) {
            if ($ExcludeLogonTypes -contains $LogonEvent.LogonTypeValue) {
                return $false
            }
        }

        return $true
    }

    # Logon type mappings (string -> numberic)
    $logonTypeMap = @{
            "Interactive"         = 2
            "Network"             = 3
            "Batch"               = 4
            "Service"             = 5
            "Unlock"              = 7
            "NetworkCleartext"    = 8
            "NewCredentials"      = 9
            "RemoteInteractive"   = 10
            "CachedInteractive"   = 11
    }

    # Reverse mapping (numeric -> string)
    $logonTypeReverseMap = @{}
    foreach ($entry in $logonTypeMap.GetEnumerator()) {
        $logonTypeReverseMap[$entry.value] = $entry.key
    }

    # Normalize excluded types to numeric values
    $includeLogonTypes = foreach ($lt in $LogonType) {
        $logonTypeMap[$lt]
    }
 
    $excludeLogonTypes = @(
    foreach ($lt in $ExcludeLogonType) {
        $logonTypeMap[$lt]
    }
)

    $shouldFilterExclude = $excludeLogonTypes.Count -gt 0

    try {
        $query = New-LogonEventQuery `
            -LogonTypeMap $logonTypeMap `
            -UserName $UserName `
            -IncludeLogonType $LogonType `
            -ExcludeLogonType $ExcludeLogonType `
            -StartTime $StartTime
    }
    catch {
        throw "Failed to create Security event log query. $($_.Exception.Message)"
    }
    
    $reader = [System.Diagnostics.Eventing.Reader.EventLogReader]::new($query)

    try {
        while ($event = $reader.ReadEvent()) {

            try {
                $logonEvent = ConvertFrom-LogonEvent `
                    -Event $event `
                    -LogonTypeReverseMap $logonTypeReverseMap

                if ( Test-LogonEventMatch -LogonEvent $logonEvent -ExcludeLogonTypes $excludeLogonTypes ) {
                    $logonEvent
                }
            }
            finally {
                $event.Dispose()
            }
        
        }
    }
    finally {
        $reader.Dispose()
    }
}