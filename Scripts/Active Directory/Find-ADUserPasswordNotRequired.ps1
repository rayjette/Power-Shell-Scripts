#Requires -Modules ActiveDirectory

function Find-ADUserPasswordNotRequired {
    <#
    .SYNOPSIS
        Finds Active Directory user accounts configured with the PasswordNotRequired account setting.

    .DESCRIPTION
        Returns Active Directory user accounts where the PasswordNotRequired account setting is enabled.  This setting indicates that Active Directory does not require a password for the account.  Accounts with this configuration should be reviewed to determine whether the setting is intentional.

    .PARAMETER SearchBase
        Specifies the organizational unit or container to search within.

    .OUTPUTS
        Microsoft.ActiveDirectory.Management.ADUser

    .EXAMPLE
        Find-ADUserPasswordNotRequired
        Searches for all user accounts with the PasswordNotRequired account setting enabled.

    .EXAMPLE
        Find-ADUserPasswordNotRequired -SearchBase "OU=Users,DC=example,DC=com"
        This example searches for user accounts with the PasswordNotRequired account setting enabled in the specified organizational unit.

    .NOTES
        Author: Raymond Jette
    #>
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [string]$SearchBase
    )

    $getADUserParams = @{
        Filter      = 'PasswordNotRequired -eq $true'
    }

    if ($SearchBase) {
        $getADUserParams.SearchBase = $SearchBase
    }
    
    Get-ADUser @getADUserParams

}