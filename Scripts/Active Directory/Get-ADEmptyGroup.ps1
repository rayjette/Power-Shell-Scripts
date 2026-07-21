#Requires -Modules ActiveDirectory

Function Get-ADEmptyGroup {
    <#
    .SYNOPSIS
        Returns Active Directory groups that contain no members.

    .DESCRIPTION
        By default, the command searches the default naming context of the target Active Directory domain.  The search can be limited by specifying a SearchBase.

        A group is considered empty when it does not contain any direct members.  Groups that contain other groups as members are considered non-empty.

    .PARAMETER SearchBase
        Specifies the distinguished name of the Active Directory container to organizational unit to search within.

    .PARAMETER GroupCategory
        Specifies the group category of the Active Directory groups to return.
        
        Valid values are:
        - Security
        - Distribution

    .EXAMPLE
        Get-ADEmptyGroup
        Finds all empty Active Directory groups in the entire directory.

    .EXAMPLE
        Get-ADEmptyGroup -SearchBase 'OU=MyGroups,DC=MyDomain,DC=com'
        Finds all empty Active Directory groups within the specified OU.

    .EXAMPLE
        Get-ADEmptyGroup -GroupCategory Security
        Finds all empty Active Directory security groups.

    .EXAMPLE
        Get-ADEmptyGroup -GroupCategory Distribution
        Finds all empty Active Directory distribution groups.

    .EXAMPLE
        Get-ADEmptyGroup -SearchBase 'OU=MyGroups,DC=MyDomain,DC=com' -GroupCategory Security

        Finds all empty security groups within the specified OU.

    .INPUTS
        None.  Get-ADEmptyGroup does not accept input from the pipeline.

    .OUTPUTS
        Microsoft.ActiveDirectory.Management.ADGroup

    .NOTES
        Author: Raymond Jette
        Requires: ActiveDirectory PowerShell module
    #>

    [CmdletBinding()]
    param 
    (
        [ValidateNotNullOrEmpty()]
        [string]$SearchBase,

        [ValidateSet('Security', 'Distribution')]
        [string]$GroupCategory
    )

    # Retrieve the Member property with the initial query to avoid
    # querying each group individually with Get-ADGroupMember.
    $getADGroupParams = @{
        Filter      = '*'
        Properties  = 'Member'
        ErrorAction = 'Stop'
    }

    if ($PSBoundParameters.ContainsKey('GroupCategory')) {
        $getADGroupParams['Filter'] = "GroupCategory -eq '$GroupCategory'"
    }

    if ($PSBoundParameters.ContainsKey('SearchBase')) {
        $getADGroupParams['SearchBase'] = $SearchBase
    }

    try {
        Write-Verbose 'Retrieving Active Directory groups'
        $groups = Get-ADGroup @getADGroupParams
        Write-Verbose "Retrieved $($groups.Count) Active Directory groups"

        Write-Verbose 'Selecting groups with no direct members'
        $groups | Where-Object {
            -not $_.Member
        }
    } catch {
        $PSCmdlet.WriteError($_)
    }
}