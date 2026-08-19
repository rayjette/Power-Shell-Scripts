function Get-DhcpServerv4ScopeOption {
    <#
    .SYNOPSIS
        Gets IPv4 scope options.

    .DESCRIPTION
        Gets the IPv4 DHCP options configured for each scope on a DHCP server.

        Returns one object for each option configured at each scope, including the scope
        name, scope ID, option name, option ID, and option value.

    .PARAMETER ComputerName
        Specifies the DHCP server to query.  If omitted, the local DHCP server is queried.

    .OUTPUTS
        Dhcp.ScopeOption

        Returns one object for each DHCP option configured at each DHCP scope.

        Properties:
        - ScopeName
        - ScopeId
        - OptionName
        - OptionId
        - Value

    .EXAMPLE
        Get-DhcpServer4ScopeOption

        Gets the IPv4 DHCP options configured on the local DHCP server.

    .EXAMPLE
        Get-DhcpServer4ScopeOption -ComputerName 'DHCP01'

        Gets the IPv4 DHCP options configured on DHCP01.

    .NOTES
        Author: Raymond Jette
    #>
    
    [CmdletBinding()]
    param (
        [string]$ComputerName
    )

    $dhcpParameters = @{
        ErrorAction = 'Stop'
    }

    if ($PSBoundParameters.ContainsKey($ComputerName)) {
        $dhcpParameters.ComputerName = $ComputerName
    }

    $dhcpScopes = Get-DhcpServerv4Scope @dhcpParameters

    foreach ($scope in $dhcpScopes) {

        $options = Get-DhcpServerv4OptionValue -ScopeId $scope.ScopeId @dhcpParameters

        foreach ($option in $options) {
            [PSCustomObject]@{
                PSTypeName = 'DhcpServerv.ScopeOption'
                ScopeName  = $scope.Name
                ScopeId    = $scope.ScopeId
                OptionName = $option.Name
                OptionId   = $option.OptionId
                Value      = $option.Value
            }
        }
    }
}