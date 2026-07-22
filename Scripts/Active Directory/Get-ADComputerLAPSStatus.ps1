#Requires -Modules ActiveDirectory

function Get-ADComputerLAPSStatus {
    <#
    .SYNOPSIS
        Retrieves Microsoft LAPS configuration status for Active Directory computer accounts.

    .DESCRIPTION
        The Get-ADComputerLAPSStatus cmdlet evaluates Active Directory computer accounts to determine their Microsoft LAPS configuration status.

        The cmdlet supports both Microsoft LAPS implementations:

        - Windows LAPS
        - Legacy Microsoft LAPS

        The cmdlet does not retrieve or expose LAPS passwords. It only evaluates LAPS-related
        Active Directory attributes required to determine configuration status.

        The cmdlet returns structured objects that can be used for reporting, filtering, and
        further analysis.

    .PARAMETER ComputerName
        Specifies one or more Active Directory computer identities to evaluate.

        The identity can be a computer name, distinguished name, GUID, or security identifier.

    .PARAMETER SearchBase
        Specifies the Active Directory container or organizational unit where computer accounts
        should be searched.

        If not specified, the default search scope is the default naming context of the current domain.

    .PARAMETER ExcludeDisabled
        Excludes disabled Active Directory computer accounts from the results.

        By default, disabled computer accounts are included.

    .EXAMPLE
        Get-ADComputerLAPSStatus

        Retrieves LAPS status information for all Active Directory computer accounts.

    .EXAMPLE
        Get-ADComputerLAPSStatus -ExcludeDisabled

        Retrieves LAPS status information only for enabled computer accounts.

    .EXAMPLE
        Get-ADComputerLAPSStatus -SearchBase "OU=Workstations,DC=contoso,DC=com"

        Retrieves LAPS status information for computers located in the specified OU.

    .EXAMPLE
        Get-ADComputerLAPSStatus -ComputerName "PC001", "PC002"

        Retrieves LAPS status information for the specified computer accounts.

    .EXAMPLE
        Get-ADComputer -Filter "Enabled -eq 'True'" |
            Get-ADComputerLAPSStatus

        Retrieves LAPS status information for computer accounts supplied through the pipeline.

    .OUTPUTS
        System.Management.Automation.PSCustomObject

        Properties include:

        - ComputerName
        - DistinguishedName
        - Enabled
        - OperatingSystem
        - LAPSStatus
        - LAPSProvider
        - WindowsLAPSExpirationTime
        - LegacyLAPSExpirationTime
        - Reason

    .NOTES
        Requires the ActiveDirectory PowerShell module.

        The account running this cmdlet requires permission to read Active Directory computer
        objects and LAPS-related attributes.

    .LINK
        https://learn.microsoft.com/windows-server/manage/windows-laps/windows-laps-overview
    #>

    [CmdletBinding(DefaultParameterSetName = 'Query')]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ParameterSetName = 'Pipeline'
        )]
        [Microsoft.ActiveDirectory.Management.ADComputer]
        $InputObject,

        [Parameter(
            Mandatory,
            ParameterSetName = 'Identity'
        )]
        [string[]]
        $ComputerName,

        [Parameter(
            ParameterSetName = 'Query'
        )]
        [string]
        $SearchBase,

        [Parameter()]
        [switch]
        $ExcludeDisabled
    )

    begin {

        $properties = @(
            'Name'
            'DistinguishedName'
            'Enabled'
            'OperatingSystem'
        )

        $schema = (Get-ADRootDSE).schemaNamingContext

        $lapsAttributes = @(
            'msLAPS-PasswordExpirationTime'
            'ms-Mcs-AdmPwdExpirationTime'
        )

        # Tracks only LAPS attributes that actually exist in the domain schema.
        # This prevents requesting attributes that are not installed.
        $supportedLAPSAttributes = @()

        foreach ($attribute in $lapsAttributes) {

            $exists = Get-ADObject `
                -SearchBase $schema `
                -LDAPFilter "(lDAPDisplayName=$attribute)"

            if ($exists) {
                $properties += $attribute
                $supportedLAPSAttributes += $attribute
            }
        }
    }

    process {

        switch ($PSCmdlet.ParameterSetName) {

            'Pipeline' {

                # Pipeline objects may not contain the LAPS properties unless
                # the caller requested them with Get-ADComputer.
                $missingProperties = $supportedLAPSAttributes | Where-Object {
                    $_ -notin $InputObject.PSObject.Properties.Name
                }

                if ($missingProperties) {

                    $computers = Get-ADComputer `
                        -Identity $InputObject `
                        -Properties $properties
                }
                else {
                    $computers = $InputObject
                }
            }

            'Identity' {

                $computers = foreach ($name in $ComputerName) {

                    Get-ADComputer `
                        -Identity $name `
                        -Properties $properties
                }
            }

            'Query' {

                $parameters = @{
                    Filter     = '*'
                    Properties = $properties
                }

                if ($SearchBase) {
                    $parameters.SearchBase = $SearchBase
                }

                $computers = Get-ADComputer @parameters
            }
        }

        foreach ($computer in $computers) {

            if ($ExcludeDisabled -and -not $computer.Enabled) {
                continue
            }

            $windowsLAPSExpirationTime = $null
            $legacyLAPSExpirationTime = $null

            $lapsProviders = @()
            $lapsStatus = 'NotConfigured'
            $reasons = @()

            if ($computer.'msLAPS-PasswordExpirationTime') {

                $lapsProviders += 'WindowsLAPS'
                $windowsLAPSExpirationTime = $computer.'msLAPS-PasswordExpirationTime'

                $reasons += 'Windows LAPS password expiration time is configured'
            }

            if ($computer.'ms-Mcs-AdmPwdExpirationTime') {

                $lapsProviders += 'LegacyLAPS'
                $legacyLAPSExpirationTime = $computer.'ms-Mcs-AdmPwdExpirationTime'

                $reasons += 'Legacy LAPS password expiration time is configured'
            }

            if ($lapsProviders.Count -gt 0) {
                $lapsStatus = 'Configured'
            }

            [PSCustomObject]@{
                ComputerName              = $computer.Name
                DistinguishedName          = $computer.DistinguishedName
                ComputerEnabled                    = $computer.Enabled
                OperatingSystem            = $computer.OperatingSystem
                LAPSStatus                 = $lapsStatus
                LAPSProvider               = $lapsProviders
                WindowsLAPSExpirationTime  = $windowsLAPSExpirationTime
                LegacyLAPSExpirationTime  = $legacyLAPSExpirationTime
                Reason                     = $reasons
            }
        }
    }
}