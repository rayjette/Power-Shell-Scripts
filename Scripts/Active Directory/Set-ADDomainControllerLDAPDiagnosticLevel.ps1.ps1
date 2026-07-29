#Requires -RunAsAdministrator

Function Set-ADDomainControllerLDAPInterfaceDiagnosticLevel {
    <#
    .SYNOPSIS
        Configures the LDAP Interface Events diagnostic logging level on a domain controller.

    .DESCRIPTION
        Configures the Active Directory Domain Services (NTDS) LDAP Interface Events
        diagnostic logging level on a domain controller.

        This function modifies the following registry value:

        HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Diagnostics
        "16 LDAP Interface Events"

        LDAP Interface Events diagnostic logging is used to troubleshoot LDAP
        server-side operations handled by Active Directory Domain Services, including
        LDAP binding, connection, and protocol-related issues.

        This setting applies only to domain controllers running Active Directory
        Domain Services.  It does not enable LDAP client logging on workstations or
        member servers.

        Changes take effect immediately and do not require a restart of the domain
        controller.

        Higher diagnostic levels generate additional events and should generally be
        enabled only during troubleshooting.

    .PARAMETER Level
        Specifies the LDAP Interface Events diagnostic logging level.

        Valid values:

        0 - Disabled
        1 - Minimal diagnostic logging
        2 - Basic diagnostic logging
        3 - Additional diagnostic logging
        4 - Verbose diagnostic logging
        5 - Maximum diagnostic logging

    .EXAMPLE
        Set-ADDomainControllerLDAPDiagnosticLevel -Level 2

        Enables basic LDAP Interface Events diagnostic logging.

    .EXAMPLE
        Set-ADDomainControllerLDAPDiagnosticLevel -Level 0

        Disables LDAP Interface Events diagnostic logging.

    .EXAMPLE
        Set-ADDomainControllerLDAPDiagnosticLevel -Level 5 -WhatIf

        Shows the change that would occur without modifying the registry.

    .NOTES
        Author: Raymond Jette
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(0, 5)]
        [int]$Level
    )

    begin {
        $registryPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Diagnostics'
        $registryValueName = '16 LDAP Interface Events'
    }

    process {

        # Verify this computer is a domain controller
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem

        # DomainRole 4 = Backup Domain Controller
        # DomainRole 5 = Primary Domain Controller
        if ($computerSystem.DomainRole -notin 4,5) {
            throw 'This function must be run on a domain controller.'
        }

        Write-Verbose "Configuring LDAP Interface Events diagnostic level on $env:COMPUTERNAME."

        # Retrieve current diagnostic level
        $currentLevel = Get-ItemPropertyValue `
            -Path $registryPath `
            -Name $registryValueName `
            -ErrorAction SilentlyContinue

        if ($null -eq $currentLevel) {
            Write-Verbose "Registry value '$registryValueName' does not exist. It will be created."
            $currentLevel = 0
        }

        if ($currnetLevel -eq $Level) {
            Write-Verbose "LDAP Interface Events Diagnostic level is already set to $Level."
        }
        elseif ($PSCmdlet.ShouldProcess(
            "$env:COMPUTERNAME\$registryValueName",
            "Set LDAP Interface Events diagnostic level from $currentLevel to $Level"
        )) {

            Set-ItemProperty `
                -Path $registryPath `
                -Name $registryValueName `
                -Value $Level `
                -Type DWord

            Write-Verbose "LDAP Interface Events diagnostic level changed from $currentLevel to $Level."
        }

        [PSCustomObject]@{
            PSTypeName   = 'ADDomainControllerLDAPDiagnosticLevel'
            ComputerName = $env:COMPUTERNAME
            PreviousLevel = $currentLevel
            CurrentLevel  = $Level
            Changed       = ($currentLevel -ne $Level)
        }
    }
}