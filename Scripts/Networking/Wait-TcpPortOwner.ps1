function Wait-TcpPortOwner {
    <#
    .SYNOPSIS
        Waits for a TCP connection matching specified criteria and returns
        the owning process, service, and connection details.

    .DESCRIPTION
        Wait-TcpPortOwner continuously monitors active TCP connections until a 
        connection matching the supplied filter criteria is detected.

        At least one of the following filters must be specified:

        - LocalAddress
        - LocalPort
        - RemoteAddress
        - RemotePort

        When a matching connection is found, the function returns information
        about the owning process, associated services, executable path,
        connection state, and optionally the process command line.

        This function is useful for troubleshooting, identifying which process
        initiates network activity, monitoring application startup behavior,
        and validating network communications.

    .PARAMETER LocalAddress
        Specifies the local IP address that the connection must match.

    .PARAMETER LocalPort
        Specifies the local TCP port that the connection must match.

    .PARAMETER RemoteAddress
        Specifies the remote IP address that the connection must match.
    
    .PARAMETER RemotePort
        Specifies the remote TCP port that the connection must match.

    .PARAMETER PollingInterval
        Specifies the interval, in milliseconds, between connection scans.

        Default: 1000

    .PARAMETER TimeoutSeconds
        Specifies the maximum amount of time to wait before terminating with
        an error.

    .PARAMETER IncludeCommandLine
        Includes the process command line in the output.

        Retrieving process command lines may require elevated privileges.

    .OUTPUTS
        System.Management.Automation.PSCustomObject

        Returns a custom object containing process, service, and connection
        information about the detected TCP connection.


    .EXAMPLE
        Wait-TcpPortOwner -RemotePort 443

        Waits until any TCP connection to remote port 443 is detected and
        returns information about the owning process.

    .EXAMPLE
        Wait-TcpPortOwner -LocalPort 8443 -TimeoutSeconds 30

        Waits up to 30 seconds for a connection using local port 8443.

    .EXAMPLE
        Wait-TcpPortOwner -RemoteAddress 10.10.10.5

        Waits until a connection to the specified remote host is observed.

    .EXAMPLE
        Wait-TcpPortOwner `
            -RemotePort 443 `
            -IncludeCommandLine `
            -Verbose

        Waits for HTTPS traffic and returns detailed process information,
        including the command line.

    .NOTES
        Author: Raymond Jette

        The function uses Get-NetTCPConnection to identify matching
        connections and CIM/WMI classes to retrieve process and service
        information.

        Requires:
        - Windows
        - NetTCPIP PowerShell module
    #>
    
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$LocalAddress,

        [Parameter()]
        [ValidateRange(1,65535)]
        [int]$LocalPort,

        [Parameter()]
        [string]$RemoteAddress,

        [Parameter()]
        [ValidateRange(1,65535)]
        [int]$RemotePort,

        [Parameter()]
        [ValidateRange(10,60000)]
        [int]$PollingInterval = 1000,

        [Parameter()]
        [ValidateRange(1,86400)]
        [int]$TimeoutSeconds,

        [Parameter()]
        [switch]$IncludeCommandLine
    )

    begin {

        $ConnectionFilters = @(
            'LocalAddress'
            'LocalPort'
            'RemoteAddress'
            'RemotePort'
        )

        if (-not ($ConnectionFilters | Where-Object { $PSBoundParameters.ContainsKey($_) })) {
            throw 'You must specify at least one connection filter.'
        }

        Write-Verbose 'Monitoring with the following parameters:'

        $PSBoundParameters.GetEnumerator() |
            Sort-Object Key |
            ForEach-Object {
                Write-Verbose "$($_.Key) = $($_.Value)"
            }

        if ($TimeoutSeconds) {
            $StopTime = (Get-Date).AddSeconds($TimeoutSeconds)
        }

        $FilterScript = {
            (-not $PSBoundParameters.ContainsKey('LocalAddress')  -or $_.LocalAddress  -eq $LocalAddress)  -and
            (-not $PSBoundParameters.ContainsKey('LocalPort')     -or $_.LocalPort     -eq $LocalPort)     -and
            (-not $PSBoundParameters.ContainsKey('RemoteAddress') -or $_.RemoteAddress -eq $RemoteAddress) -and
            (-not $PSBoundParameters.ContainsKey('RemotePort')    -or $_.RemotePort    -eq $RemotePort)
        }
    }

    process {

        do {

            if ($StopTime -and (Get-Date) -gt $StopTime) {
                throw "Timed out waiting for matching TCP activity after $TimeoutSeconds seconds."
            }

            $Connection =
                Get-NetTCPConnection -ErrorAction SilentlyContinue |
                Where-Object $FilterScript |
                Select-Object -First 1

            if (-not $Connection) {
                Start-Sleep -Milliseconds $PollingInterval
            }

        } until ($Connection)

        Write-Verbose 'Matching TCP connection detected.'

        $ProcessId = $Connection.OwningProcess

        $ProcessInfo = Get-CimInstance `
            -ClassName Win32_Process `
            -Filter "ProcessId=$ProcessId" `
            -ErrorAction SilentlyContinue

        $ProcessObject = Get-Process `
            -Id $ProcessId `
            -ErrorAction SilentlyContinue

        $ServiceInfo = Get-CimInstance `
            -ClassName Win32_Service `
            -Filter "ProcessId=$ProcessId" `
            -ErrorAction SilentlyContinue

        [PSCustomObject]@{
            PSTypeName = 'TcpPortOwnerInfo'

            DetectionTime = Get-Date
            ComputerName  = $env:COMPUTERNAME

            FilterLocalAddress  = $LocalAddress
            FilterLocalPort     = $LocalPort

            FilterRemoteAddress = $RemoteAddress
            FilterRemotePort    = $RemotePort

            ProcessName = $ProcessInfo.Name
            ProcessId   = $ProcessId

            ExecutablePath = $ProcessInfo.ExecutablePath

            ProcessStartTime = $ProcessObject.StartTime

            CommandLine = if ($IncludeCommandLine) {
                $ProcessInfo.CommandLine
            }
            else {
                $null
            }

            Services = @($ServiceInfo.Name)

            LocalAddress = $Connection.LocalAddress
            LocalPort    = $Connection.LocalPort

            RemoteAddress = $Connection.RemoteAddress
            RemotePort    = $Connection.RemotePort

            State = $Connection.State
        }
    }
}