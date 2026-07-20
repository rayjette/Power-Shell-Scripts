Function ConvertFrom-SPNString {
    <#
    .SYNOPSIS
        Converts a Service Principal Name (SPN) string into a structured object.

    .DESCRIPTION
        This function parses a Service Principal Name (SPN) string into its individual components:

            - ServiceClass
            - Host
            - InstanceOrPort
            - ServiceName

        SPN's generally follow this format:

            ServiceClass/Host[:InstanceOrPort][/ServiceName]

        The value after the colman may represent either a numeric port or a named service instance.  For example, SQL Server SPNs commonly use both formats:

            MSSQLSvc/sql01.contoso.com:1433
            MSSQLSvc/sql01.contoso.com:SQLINSTANCE

    .PARAMETER ServicePrincipalName
        The SPN string(s) to be parsed.

    .EXAMPLE
        ConvertFrom-SPNString -ServicePrincipalName 'HTTP/web01.contoso.com'

        Parses a basic SPN containing only the service class and host.

    .EXAMPLE
        ConvertFrom-SPNString -ServicePrincipalName 'MSSQLSvc/sql01.contoso.com:1433'

        Parses an SPN where the value after the colon is a numeric port.

    .EXAMPLE
        ConvertFrom-SPNString -ServicePrincipalName 'MSSQLSvc/sql01.contoso.com:SQLINSTANCE'

        Parses an SPN where the value after the colon is a named service instance.

    .EXAMPLE
        ConvertFrom-SPNString -ServicePrincipalName 'HTTP/web01.contoso.com:8080/MyApplication'

        Parses an SPN containing a port and service name.

    .OUTPUTS
        System.Management.Automation.PSCustomObject.

    .NOTES
        Author: Raymond Jette
    #>

    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param (
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('SPN')]
        [string[]] $ServicePrincipalName
    )

    BEGIN {

        # SPN format:
        #   ServiceClass/Host
        #   ServiceClass/Host:InstanceOrPort
        #   ServiceClass/Host/ServiceName
        #   ServiceClass/Host:InstanceOrPort/ServiceName
        #
        # The value after ':' may be a numeric port or an instance name.
        $pattern = '^(?<ServiceClass>[^/:]+)/(?<Host>[^/:]+)(?::(?<InstanceOrPort>[^/]+))?(?:/(?<ServiceName>.+))?$'

    }

    PROCESS {

        foreach ($spn in $ServicePrincipalName) {

            if ($spn -match $pattern) {

                [PSCustomObject]@{
                    ServicePrincipalName = $spn
                    ServiceClass         = $matches.ServiceClass
                    Host                 = $matches.Host
                    InstanceOrPort       = $matches['InstanceOrPort']
                    ServiceName          = $matches['ServiceName']
                }

            } else {

                Write-Error `
                    -Message 'Invalid SPN format.' `
                    -Category InvalidData `
                    -ErrorId InvalidSPN `
                    -TargetObject $spn

            }
        }
    }
}