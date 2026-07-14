function Wait-TcpPortOwner {

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