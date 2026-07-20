#Requires -Modules ActiveDirectory

Function Get-ADFsmoRoleHolder {
    <#
    .SYNOPSIS
        Retrieves the Domain Controllers that currently hold Active Directory FSMO roles.

    .DESCRIPTION
        Retrieves the current holders of all Active Directory FSMO roles for the current forest and domain and returns the information as a PowerShell object.

    .EXAMPLE
        Get-ADFsmoRoleHolder

        Retrieves the FSMO role holder for the current domain and forest.

    .OUTPUTS
        System.Management.Automation.PSCustomObject

        Returns an object containing the current FSMO role holders for the Active Directory forest and domain.

    .NOTES
        Author: Raymond Jette
    #>

    [OutputType([System.Management.Automation.PSCustomObject])]
    [CmdletBinding()] 
    param()

    try {
        Write-Verbose -Message 'Retrieving forest information.'
        $Forest = Get-ADForest -ErrorAction 'Stop'

        Write-Verbose -Message 'Retrieving domain information.'
        $Domain = Get-ADDomain -ErrorAction 'Stop'

        [PSCustomObject][Ordered]@{
            ForestName           = $Forest.Name
            DomainName           = $Domain.DNSRoot
            SchemaMaster         = $Forest.SchemaMaster
            DomainNamingMaster   = $Forest.DomainNamingMaster
            InfrastructureMaster = $Domain.InfrastructureMaster
            RIDMaster            = $Domain.RIDMaster
            PDCEmulator          = $Domain.PDCEmulator
        }
    } catch {
            $PSCmdlet.ThrowTerminatingError($_)
    }
}