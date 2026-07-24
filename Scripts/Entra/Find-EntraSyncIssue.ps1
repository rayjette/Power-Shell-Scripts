#Requires -Modules ActiveDirectory

function Find-EntraSyncIssue {
    <#
    .SYNOPSIS
        Finds Active Directory user objects that have Microsoft Entra synchronization issues.

    .DESCRIPTION
        The Find-EntraSyncIssue cmdlet evaluates Active Directory user objects for conditions that can prevent or interfere with synchronization to Microsoft Entra ID.

        Version 1 detects duplicate attribute values for attributes that are expected to be unique for successful synchronization.

        The cmdlet returns one object for each synchronization issue that is detected.  Each returned object identifies the issue, the affected attribute, the conflicting value, and the Active Directory objects involved.

        The cmdlet is intended to help administrators identify and remediate synchronization issues before or during Microsoft Entra Connect Synchronization.

    .OUTPUTS
        EntraSyncIssue

        Returns one object for each synchronization issue that is detected.

        Properties include:

        - IssueType             The category of synchronization issue.
        - Attribute             The attribute associated with the issue.
        - Value                 The conflicting or invalid value.
        - ObjectCount           Number of affected objects.
        - AffectedObjects       The Active Directory objects involved.
        - Recommendation        Suggested remediation.

    .PARAMETER SearchBase
        Specifies the Active Directory container or organizational unit where user accounts should be searched.

        If not specified, the default search scope is the default naming context of the current domain.

    .PARAMETER ExcludeDisabled
        Excludes disabled Active Directory user accounts from evaluation.

        By default, disabled user accounts are included.

    .EXAMPLE
        Find-EntraSyncIssue

        Evaluates Active Directory user accounts in the default search scope for
        Microsoft Entra synchronization issues.

    .EXAMPLE
        Find-EntraSyncIssue -ExcludeDisabled

        Evaluates only enabled Active Directory user accounts for Microsoft Entra
        synchronization issues.

    .EXAMPLE
        Find-EntraSyncIssue -SearchBase "OU=Users,DC=contoso,DC=com"

        Evaluates Active Directory user accounts in the specified organizational
        unit for Microsoft Entra synchronization issues.

    .NOTES
        Author: Raymond Jette
        
        Requires the ActiveDirectory PowerShell module.

        The account running this cmdlet require permission to read Active Directory user objects and the attributes evaluated for Microsoft Entra synchronization.

    .LINKS
        https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$SearchBase,

        [Parameter()]
        [switch]$ExcludeDisabled
    )


    function New-EntraSyncIssue {
        [OutputType('EntraSyncIssue')]

        param(
            [Parameter(Mandatory)]
            [string]$IssueType,

            [Parameter(Mandatory)]
            [string]$Attribute,

            [Parameter()]
            [string]$Value,

            [Parameter(Mandatory)]
            [object[]]$AffectedObjects,

            [Parameter(Mandatory)]
            [string]$Recommendation
        )

        [PSCustomObject]@{
            PSTypeName      = 'EntraSyncIssue'
            IssueType       = $IssueType
            Attribute       = $Attribute
            Value           = $Value
            ObjectCount     = $AffectedObjects.Count
            AffectedObjects = $AffectedObjects
            Recommendation  = $Recommendation
        }
    }


    function Test-DuplicateAttribute {

        [OutputType('EntraSyncIssue')]

        param(
            [Parameter(Mandatory)]
            [object[]]$Users,

            [Parameter(Mandatory)]
            [string]$Attribute,

            [Parameter(Mandatory)]
            [string]$Recommendation
        )

        $duplicateAttributes =
            $Users.Where({
                -not [string]::IsNullOrWhiteSpace($_.$Attribute)
            }) |
            Group-Object -Property $Attribute |
            Where-Object { $_.Count -gt 1 }
        
        $duplicateAttributes.ForEach({

            New-EntraSyncIssue `
                -IssueType 'DuplicateAttribute' `
                -Attribute $Attribute `
                -Value $_.Name `
                -AffectedObjects (
                    $_.Group | Select-Object `
                        Name,
                        SamAccountName,
                        DistinguishedName,
                        ObjectGUID
                ) `
                -Recommendation $Recommendation

        })
    }


    function Test-DuplicateProxyAddress {
        
        [OutputType('EntraSyncIssue')]

        param(
            [Parameter(Mandatory)]
            [object[]]$Users
        )

        # proxyAddresses is a multi-valued Active Directory attribute.
        # Each proxy address must be evaluated independently.

        $proxyAddresses = foreach ($User in $Users) {

            foreach ($ProxyAddress in $User.proxyAddresses) {

                $comparisonAddress = $ProxyAddress.ToLowerInvariant()

                [PSCustomObject]@{
                    ProxyAddress      = $ProxyAddress
                    Comparison        = $comparisonAddress
                    User              = $User
                }
            }
        }

        $duplicateProxyAddresses = $proxyAddresses |
            Group-Object -Property Comparison |
            Where-Object Count -gt 1

        $duplicateProxyAddresses.ForEach({

            New-EntraSyncIssue `
                -IssueType 'DuplicateAttribute' `
                -Attribute 'proxyAddresses' `
                -Value $_.Name `
                -AffectedObjects (
                    $_.Group.User |
                    Sort-Object ObjectGUID -Unique |
                    Select-Object `
                        Name,
                        SamAccountName,
                        DistinguishedName,
                        ObjectGUID
                ) `
                -Recommendation 'Ensure each proxyAddresses value is assigned to only one user.'
        })
    }


    function Test-MissingProxyAddress {

        [OutputType('EntraSyncIssue')]

        param(
            [Parameter(Mandatory)]
            [object[]]$Users
        )

        $Users.Where({
            -not $_.proxyAddresses -or $_.proxyAddresses.Count -eq 0
        }).ForEach({

            New-EntraSyncIssue `
                -IssueType 'MissingAttribute' `
                -Attribute 'proxyAddresses' `
                -AffectedObjects (
                    $_ | Select-Object `
                        Name,
                        SamAccountName,
                        DistinguishedName,
                        ObjectGUID
                ) `
                -Recommendation 'Assign at least one proxyAddresses value to the mail-enabled user before synchronization.'

        })

    }


    function Test-MissingPrimarySmtpAddress {

        [OutputType('EntraSyncIssue')]

        param(
            [Parameter(Mandatory)]
            [object[]]$Users
        )

        $Users.Where({

            -not ($_.proxyAddresses -cmatch '^SMTP:')

        }).ForEach({

            New-EntraSyncIssue `
                -IssueType 'MissingAttribute' `
                -Attribute 'proxyAddresses' `
                -Value 'Primary SMTP address missing' `
                -AffectedObjects (
                    $_ | Select-Object `
                        Name,
                        SamAccountName,
                        DistinguishedName,
                        ObjectGUID
                ) `
                -Recommendation 'Assign a primary SMTP address using an uppercase SMTP: proxy address.'
        })
    }


    function Test-MissingAttribute {
        
        [OutputType('EntraSyncIssue')]

        param(
            [Parameter(Mandatory)]
            [object[]]$Users,

            [Parameter(Mandatory)]
            [string]$Attribute,

            [Parameter(Mandatory)]
            [string]$Recommendation
        )

        $Users.Where({
            [string]::IsNullOrWhiteSpace($_.$Attribute)
        }).ForEach({

            New-EntraSyncIssue `
                -IssueType 'MissingAttribute' `
                -Attribute $Attribute `
                -AffectedObjects (
                    $_ | Select-Object `
                        Name,
                        SamAccountName,
                        DistinguishedName,
                        ObjectGUID
                ) `
                -Recommendation $Recommendation
        })
    }


    function Get-MailEnabledUser {

        [OutputType('Microsoft.ActiveDirectory.Management.ADUser')]

        param(
            [Parameter(Mandatory)]
            [object]$Users
        )

        $Users.Where({
            -not [string]::IsNullOrWhiteSpace($_.msExchRecipientTypeDetails)
        })

    }


    $adParams = @{
        Filter     = '*'
        Properties = @(
            'Enabled'
            'mail'
            'mailNickname'
            'proxyAddresses'
            'UserPrincipalName'
            'DistinguishedName'
            'ObjectGUID'
            'msExchRecipientTypeDetails'
        )
    }

    if ($PSBoundParameters.ContainsKey('SearchBase')) {
        $adParams.SearchBase = $SearchBase
    }

    try {
        $users = @(Get-ADUser @adParams -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve Active Directory users. $($_.Exception.Message)"
    }

    Write-Verbose "Retrieved $($users.Count) Active Directory user objects."

    if ($ExcludeDisabled) {
        $users = $users.Where({ $_.Enabled })

        Write-Verbose "Filtered to $($users.Count) enabled Active Directory user objects."
    }

    Write-Verbose 'Identifying mail-enabled users.'

    $mailEnabledUsers = Get-MailEnabledUser -Users $users

    Write-Verbose "Identified $($mailEnabledUsers.Count) mail-enabled users."
    
    Write-Verbose 'Checking for duplicate UserPrincipalName values.'

    Test-DuplicateAttribute `
        -Users $users `
        -Attribute 'UserPrincipalName' `
        -Recommendation 'Ensure each UserPrincipalName value is assigned to only one user.'

    Write-Verbose 'Checking for duplicate mail values.'

    Test-DuplicateAttribute `
        -Users $users `
        -Attribute 'mail' `
        -Recommendation 'Ensure each mail value is assigned to only one user'

    Write-Verbose 'Checking for duplicate proxyAddresses values.'

    Test-DuplicateProxyAddress `
        -Users $users

    Write-Verbose 'Checking for duplicate mailNickname values.'

    Test-DuplicateAttribute `
        -Users $users `
        -Attribute 'mailNickname' `
        -Recommendation 'Ensure each mailNickname value is assigned to only one user.'

    Write-Verbose 'Checking for missing UserPrincipalName values.'

    Test-MissingAttribute `
        -Users $users `
        -Attribute 'UserPrincipalName' `
        -Recommendation 'Populate the UserPrincipalName attribute before synchronization.'

    Write-Verbose 'Checking for missing mailNickname values.'

    Test-MissingAttribute `
        -Users $mailEnabledUsers `
        -Attribute 'mailNickname' `
        -Recommendation 'Populate the mailNickname values.'

    Write-Verbose 'Checking for missing proxyAddress values on mail-enabled users.'

    Test-MissingProxyAddress `
        -Users $mailEnabledUsers

    Write-Verbose 'Checking for missing primary SMTP addresses on mail-enabled users.'

    Test-MissingPrimarySmtpAddress `
        -Users $mailEnabledUsers
}