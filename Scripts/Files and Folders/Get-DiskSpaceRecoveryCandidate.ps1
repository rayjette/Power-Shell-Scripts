#Requires -RunAsAdministrator

function Get-DiskSpaceRecoveryCandidate {
    <#
    .SYNOPSIS
        Identifies potential disk space recovery opportunities on a Windows system.

    .DESCRIPTION
        Scans the local computer for locations, files, and Windows features that commonly consume significant disk space and may contain recoverable storage.

        The function analyzes known recovery candidates such as temporary files, recycle bins, shadow copies, Windows servicing data, log files, crash dumps, and other large storage consumers.  Results are returned as objects that can be sorted, filtered, or exported for further analysis.

        This function does not delete any data and performs no remediation actions.

    .PARAMETER DeepScan
        Performs additional analysis operations that may require increased processing time or disk I/O.

        Deep scan operations may significantly increase execution time and can generate additional disk I/O.

        Examples of deep scan analysis include identifying large files, large directories, duplicate files, and other storage consumers that require broader inspection of the file system.
  
    .EXAMPLE
        Get-DiskSpaceRecoveryCandidate

        Identifies potential disk space recovery opportunities on the local system.

    .EXAMPLE
        Get-DiskSpaceRecoveryCandidate |
            Sort-Object PotentialRecoveryGB -Descending

        Displays recovery candidates ordered by the largest potential space savings.

    .INPUTS
        None.

    .OUTPUTS
        DiskSpaceRecoveryCandidate

        Represents a portential disk space recovery oppotunity discovered during analysis of the local computer.

    .NOTES
        Author: Raymond Jette
    #>

    [CmdletBinding(DefaultParameterSetName='Standard')]
    param (

        [Parameter(
            ParameterSetName = 'DeepScan'
        )]
        [switch]$DeepScan
    )
    
    begin {

        function New-DiskSpaceRecoveryCandidate {

            param(
                [string]$Category,
                [string]$SubCategory,
                [string]$Name,
                [string[]]$Location,
                [decimal]$PotentialRecoveryGB,
                [string]$Recommendation
            )

            [PSCustomObject]@{
                PSTypeName          = 'DiskSpaceRecoveryCandidate'

                Category            = $Category
                SubCategory         = $SubCategory
                Name                = $Name
                Location            = $Location
                PotentialRecoveryGB = $PotentialRecoveryGB
                Recommendation      = $Recommendation
            }
        }


        function Get-LocationSizeGB {

            param(
                [Parameter(Mandatory)]
                [string]$Location
            )

            if (-not (Test-Path -Path $Location -ErrorAction SilentlyContinue)) {
                return $null
            }

            try {

                $item = Get-Item -Path $Location -Force -ErrorAction Stop

                if ($item.PSIsContainer) {

                    $bytes = (
                        Get-ChildItem `
                            -Path $Location `
                            -File `
                            -Recurse `
                            -Force `
                            -ErrorAction SilentlyContinue `
                            -Attributes !ReparsePoint |
                        Measure-Object -Property Length -Sum
                    ).Sum

                }
                else {
                    $bytes = $item.Length
                }

                if ($null -eq $bytes) {
                    return $null
                }

                [Math]::Round($bytes / 1GB, 2)
            }
            catch {
                Write-Verbose "Unable to determine size for '$Location'. $($_.Exception.Message)"
                return
            }
        }



        function Get-RecoveryCandidateSize {

            param(
                [Parameter(Mandatory)]
                [string[]]$Path
            )

            $locations = @()
            $totalGB = [decimal]0

            foreach ($item in $Path) {

                $size = Get-LocationSizeGB -Location $item

                if ($null -eq $size) {
                    continue
                }
                
                $locations += $item
                $totalGB += $size
            }

            if ($locations.Count -eq 0) {
                return
            }

            [pscustomobject]@{
                Locations = $locations
                SizeGB    = [math]::Round($totalGB,2)
            }
        }


        function Find-WindowsTempRecoveryCandidate {

            $location = Join-Path -Path $env:windir -ChildPath 'Temp'

            $result = Get-RecoveryCandidateSize -Path $location

            if ($null -eq $result) {
                return
            }

            New-DiskSpaceRecoveryCandidate `
                -Category 'Temporary Files' `
                -SubCategory 'Windows Temp' `
                -Name 'Windows Temporary Files' `
                -Location $result.Locations `
                -PotentialRecoveryGB $result.SizeGB `
                -Recommendation 'Delete temporary files.'
        }


        function Find-UserTempRecoveryCandidate {

            $profiles = Get-ChildItem `
                -Path 'C:\Users' `
                -Directory `
                -Force `
                -ErrorAction SilentlyContinue

            if ($null -eq $profiles) {
                return
            }

            foreach ($profile in $profiles) {

                $location = Join-Path `
                    -Path $profile.FullName `
                    -ChildPath 'AppData\Local\Temp'

                $result = Get-RecoveryCandidateSize -Path $location

                if ($null -eq $result) {
                    continue
                }

                New-DiskSpaceRecoveryCandidate `
                    -Category 'Temporary Files' `
                    -SubCategory 'User Temp' `
                    -Name "User Temporary Files - $($profile.Name)" `
                    -Location $result.Locations `
                    -PotentialRecoveryGB $result.SizeGB `
                    -Recommendation 'Delete user temporary files.'
            }
        }


        function Find-WindowsUpdateCacheRecoveryCandidate {

            $location = Join-Path -Path $env:windir -ChildPath 'SoftwareDistribution\Download'

            $result = Get-RecoveryCandidateSize -Path $location

            if ($null -eq $result) {
                return
            }

            New-DiskSpaceRecoveryCandidate `
                -Category 'Windows Update' `
                -SubCategory 'Update Cache' `
                -Name 'Windows Update Download Cache' `
                -Location $result.Locations `
                -PotentialRecoveryGB $result.SizeGB `
                -Recommendation 'Clean up downloaded Windows Update files.'
        }


        function Find-DeliveryOptimizationRecoveryCandidate {

            $status = Get-DeliveryOptimizationStatus -ErrorAction SilentlyContinue |
                Where-Object { $_ -is [psobject] -and $_.PSObject.Properties['FileSizeInCache'] }

            if (-not $status) {
                return
            }

            $cacheSizeBytes = ($status | Measure-Object -Property FileSizeInCache -Sum).Sum

            if ($null -eq $cacheSizeBytes) {
                return
            }

            $PotentialRecoveryGB = [Math]::Round($cacheSizeBytes / 1GB, 2)

            $location = 'Delivery Optimized Cache'

            New-DiskSpaceRecoveryCandidate `
                -Category 'Temporary Files' `
                -SubCategory 'Delivery Optimization Cache' `
                -Name 'Delivery Optimization Cache' `
                -Location $location `
                -PotentialRecoveryGB $PotentialRecoveryGB `
                -Recommendation 'Review and clear Delivery Optimization cache files using supported Windows cleanup methods.'
        } 


        function Find-WindowsErrorReportingRecoveryCandidate {

            $locations = @(
                (Join-Path $env:ProgramData -ChildPath 'Microsoft\Windows\WER')
            )

            $userProfiles = Get-ChildItem -Path 'C:\Users' -Directory -Force -ErrorAction SilentlyContinue
            
            foreach ($profile in $userProfiles) {
                $locations += Join-Path `
                    -Path $profile.FullName `
                    -ChildPath 'AppData\Local\Microsoft\Windows\WER'
            }

           $result = Get-RecoveryCandidateSize -Path $locations

           if ($null -eq $result) {
            return
           }

            New-DiskSpaceRecoveryCandidate `
                -Category 'Windows Diagnostics' `
                -SubCategory 'Error Reporting' `
                -Name 'Windows Error Reporting Data' `
                -Location $result.Locations `
                -PotentialRecoveryGB $result.SizeGB `
                -Recommendation 'Review and remove old Windows Error Reporting data if no longer required.'
        }


        function Find-CrashDumpRecoveryCandidate {

            $locations = @(
                (Join-Path -Path $env:windir -ChildPath 'MEMORY.DMP')
                (Join-Path -Path $env:windir -ChildPath 'Minidump')
                (Join-Path -Path $env:windir -ChildPath 'LiveKernelReports')
            )

            $result = Get-RecoveryCandidateSize -Path $locations

            if ($null -eq $result) {
                return
            }

            New-DiskSpaceRecoveryCandidate `
                -Category 'Windows Diagnostics' `
                -SubCategory 'Crash Dumps' `
                -Name 'Windows Crash Dump Files' `
                -Location $result.Locations `
                -PotentialRecoveryGB $result.SizeGB `
                -Recommendation 'Review and remove crash dump files if they are no longer required for troubleshooting.'
        }


        function Find-RecycleBinRecoveryCandidate {

            $locations = Get-PSDrive -PSProvider FileSystem |
                Where-Object {
                    $null -ne $_.Free
                } |
                ForEach-Object {
                    Join-Path -Path $_.Root -ChildPath '$Recycle.Bin'
                }

            $result = Get-RecoveryCandidateSize -Path $locations

            if ($null -eq $result) {
                return
            }

            New-DiskSpaceRecoveryCandidate `
                -Category 'User Data' `
                -SubCategory 'Recycle Bin' `
                -Name 'Recycle Bin Contents' `
                -Location $result.Locations `
                -PotentialRecoveryGB $result.SizeGB `
                -Recommendation 'Review and empty Recycle Bin contents if they are no longer required.'
        }


        function Find-ShadowCopyRecoveryCandidate {

            $shadowStorage = Get-CimInstance `
                -ClassName win32_ShadowStorage `
                -ErrorAction SilentlyContinue

            if ($null -eq $shadowStorage) {
                return
            }

            $locations = @()
            $totalBytes = [decimal]0

            foreach ($storage in $shadowStorage) {

                if ($null -ne $storage.Volume) {
                    $locations += $storage.Volume
                }

                if ($null -ne $storage.UsedSpace) {
                    $totalBytes += $storage.UsedSpace
                }
            }

            if ($locations.Count -eq 0) {
                return
            }

            New-DiskSpaceRecoveryCandidate `
                -Category 'System Storage' `
                -SubCategory 'Volume Shadow Copy' `
                -Name 'Shadow Copy Storage' `
                -Location $locations `
                -PotentialRecoveryGB ([Math]::Round($totalBytes / 1GB, 2)) `
                -Recommendation 'Review shadow copy retention and remove unnecessary shadow copies if appropriate.'

        }


        function Find-WindowsComponentStoreRecoveryCandidate {

            $location = Join-Path -Path $env:windir -ChildPath 'WinSxS'

            # Parse DISM output to determine the reported size of component store
            # backups and disabled features.  DISM does not expose this information
            # through CIM or a PowerShell cmdlet.
            $dismOutput = & DISM.exe /Online /Cleanup-Image /AnalyzeComponentStore 2>$null

            if ($null -eq $dismOutput) {
                return
            }

            $PotentialRecoveryGB = $null

            foreach ($line in $dismOutput) {

                if ($line -match 'Backups and Disabled Features\s*:\s*(\d+\.\d+)\s*GB') {
                    $PotentialRecoveryGB = [decimal]$matches[1]
                    break
                }
            }

            if ($null -eq $PotentialRecoveryGB) {
                return
            }

            New-DiskSpaceRecoveryCandidate `
                -Category 'System Storage' `
                -SubCategory 'Component Store' `
                -Name 'Windows Component Store' `
                -Location $location `
                -PotentialRecoveryGB ([Math]::Round($PotentialRecoveryGB, 2)) `
                -Recommendation 'Use DISM component cleanup to remove superseded Windows components when appropriate.'
        }


        function Find-HibernationFileRecoveryCandidate {

            $location = Join-Path -Path $env:SystemDrive -ChildPath 'hiberfil.sys'

            $result = Get-RecoveryCandidateSize -Path $location

            if ($null -eq $result) {
                return
            }

            New-DiskSpaceRecoveryCandidate `
                -Category 'System Configuration' `
                -SubCategory 'Hibernation' `
                -Name 'Hibernation File' `
                -Location $result.Locations `
                -PotentialRecoveryGB $result.SizeGB `
                -Recommendation 'Disable hibernation if the feature is not required to reclaim the hibernation file space.'
        }


        function Find-PageFileRecoveryCandidate {

            $pageFiles = Get-CimInstance -ClassName Win32_PageFileUsage -ErrorAction SilentlyContinue

            if ($null -eq $pageFiles) {
                return
            }

            $locations = @()
            $totalGB = [decimal]0

            foreach ($pageFile in $pageFiles) {

                if ($null -eq $pageFile.AllocatedBaseSize) {
                    continue
                }

                $locations += $pageFile.Name
                $totalGB += ([decimal]$pageFile.AllocatedBaseSize / 1024)
            }

            if ($locations.Count -eq 0) {
                return
            }

            New-DiskSpaceRecoveryCandidate `
                -Category 'System Configuration' `
                -SubCategory 'Virtual Memory' `
                -Name 'Paging File' `
                -Location $locations `
                -PotentialRecoveryGB ([Math]::Round($totalGB,2)) `
                -Recommendation 'Review virtual memory configuration before reducing paging file size.'
        }


        function Find-WindowsInstallerCacheRecoveryCandidate {

            $location = Join-Path -Path $env:windir -ChildPath 'Installer'

            $result = Get-RecoveryCandidateSize -Path $location

            if ($null -eq $result) {
                return
            }

            New-DiskSpaceRecoveryCandidate `
                -Category 'System Storage' `
                -SubCategory 'Windows Installer Cache' `
                -Name 'Windows Installer Cache' `
                -Location $result.Locations `
                -PotentialRecoveryGB $result.SizeGB `
                -Recommendation 'Do not manually remove files.  Use Windows Installer analysis tools to identify orphaned installer packages.'
        }


        function Find-WindowsLogRecoveryCandidate {

            $locations = @(
                (Join-Path -Path $env:windir -ChildPath 'Logs')
                (Join-Path -Path $env:windir -ChildPath 'System32\LogFiles')
            )

            $result = Get-RecoveryCandidateSize -Path $locations

            if ($null -eq $result) {
                return
            }

            New-DiskSpaceRecoveryCandidate `
                -Category 'Windows Diagnostics' `
                -SubCategory 'Log Files' `
                -Name 'Windows Log Files' `
                -Location $result.Locations `
                -PotentialRecoveryGB $result.SizeGB `
                -Recommendation 'Review log files and retention settings before removing diagnostic data.'
        }


        function Find-WindowsOldRecoveryCandidate {

            $location = Join-Path -Path $env:SystemDrive -ChildPath 'Windows.old'

            $result = Get-RecoveryCandidateSize -Path $location

            if ($null -eq $result) {
                return
            }

            New-DiskSpaceRecoveryCandidate `
                -Category 'Windows Update' `
                -SubCategory 'Previous Installation' `
                -Name 'Windows.old' `
                -Location $result.Locations `
                -PotentialRecoveryGB $result.SizeGB `
                -Recommendation 'Remove previous Windows installation files using supported cleanup methods.'
        }


        function Find-WindowsUpgradeTempRecoveryCandidate {

            $locations = @(
                Join-Path -Path $env:SystemDrive -ChildPath '$WINDOWS.~BT'
                Join-Path -Path $env:SystemDrive -ChildPath '$WINDOWS.~WS'
            )

            $result = Get-RecoveryCandidateSize -Path $locations

            if ($null -eq $result) {
                return
            }

            New-DiskSpaceRecoveryCandidate `
                -Category 'Windows Upgrade' `
                -SubCategory 'Upgrade Temporary Files' `
                -Name 'Windows Upgrade Temporary Files' `
                -Location $result.Locations `
                -PotentialRecoveryGB $result.SizeGB `
                -Recommendation 'Remove Windows upgrade temporary files using supported cleanup methods.'
        }


        function Find-WindowsSearchIndexRecoveryCandidate {

            $location = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\Search'

            $result = Get-RecoveryCandidateSize -Path $location

            if ($null -eq $result) {
                return
            }

            New-DiskSpaceRecoveryCandidate `
                -Category 'System Configuration' `
                -SubCategory 'Search Index' `
                -Name 'Windows Search Index Database' `
                -Location $result.Locations `
                -PotentialRecoveryGB $result.SizeGB `
                -Recommendation 'Review Windows Search indexing configuration before rebuilding or reducing the index.'
        }


        function Find-IISLogRecoveryCandidate {

            $location = Join-Path $env:SystemDrive -ChildPath 'inetpub\logs\LogFiles'

            $result = Get-RecoveryCandidateSize -Path $location

            if ($null -eq $result) {
                return
            }

            New-DiskSpaceRecoveryCandidate `
                -Category 'Application Data' `
                -SubCategory 'IIS Logs' `
                -Name 'IIS Log Files' `
                -Location $result.Locations `
                -PotentialRecoveryGB $result.SizeGB `
                -Recommendation 'Review IIS log retention settings and remove logs older than the required retention period.'
        }


        function Find-WindowsSetupLogRecoveryCandidate {

            $locations = @(
                (Join-Path -Path $env:windir -ChildPath 'Panther')
                (Join-Path -Path $env:windir -ChildPath 'Logs\MoSetup')
                (Join-Path -Path $env:SystemDrive -ChildPath '$SysReset')
            )

            $result = Get-RecoveryCandidateSize -Path $locations

            if ($null -eq $result) {
                return
            }

            New-DiskSpaceRecoveryCandidate `
                -Category 'Windows Upgrade' `
                -SubCategory 'Setup Logs' `
                -Name 'Windows Setup and Upgrade Logs' `
                -Location $result.Locations `
                -PotentialRecoveryGB $result.SizeGB `
                -Recommendation 'Review and remove obsolete Windows setup and upgrade logs if they are no longer needed for troubleshooting.'
        }


        function Find-WindowsDefenderRecoveryCandidate {

            $location = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\Windows Defender\Scans'

            $result = Get-RecoveryCandidateSize -Path $location

            if ($null -eq $result) {
                return
            }

            New-DiskSpaceRecoveryCandidate `
                -Category 'Security' `
                -SubCategory 'Microsoft Defender' `
                -Name 'Microsoft Defender Scan History' `
                -Location $result.Locations `
                -PotentialRecoveryGB $result.SizeGB `
                -Recommendation 'Review Microsoft Defender scan history and remove obsolete scan data using supported Windows Defender maintenance methods.'
        }


        function Find-BrowserCacheRecoveryCandidate {

                $browsers = @(
                    @{
                        Name        = 'Microsoft Edge'
                        ProfileRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data'
                        CacheFolder = 'Cache'
                    },
                    @{
                        Name        = 'Google Chrome'
                        ProfileRoot = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data'
                        CacheFolder = 'Cache'
                    },
                    @{
                        Name        = 'Mozilla Firefox'
                        ProfileRoot = Join-Path $env:LOCALAPPDATA 'Mozilla\Firefox\Profiles'
                        CacheFolder = 'cache2'
                    }
                )

                foreach ($browser in $browsers) {

                    if (-not (Test-Path -Path $browser.ProfileRoot)) {
                        continue
                    }

                    $locations = @(
                        Get-ChildItem `
                            -Path $browser.ProfileRoot `
                            -Directory `
                            -Force `
                            -ErrorAction SilentlyContinue |
                        ForEach-Object {

                            $cachePath = Join-Path `
                                -Path $_.FullName `
                                -ChildPath $browser.CacheFolder

                            if (Test-Path $cachePath) {
                                $cachePath
                            }
                        }
                    )

                    if ($locations.Count -eq 0) {
                        continue
                    }

                    $result = Get-RecoveryCandidateSize -Path $locations

                    if ($null -eq $result) {
                        continue
                    }

                    New-DiskSpaceRecoveryCandidate `
                        -Category 'Application Cache' `
                        -SubCategory 'Web Browser' `
                        -Name "$($browser.Name) Cache" `
                        -Location $result.Locations `
                        -PotentialRecoveryGB $result.SizeGB `
                        -Recommendation 'Clear the browser cache using the browser''s built-in settings if disk space recovery is required.'
                }
        }


        function Find-UserDownloadsRecoveryCandidate {

            $userProfiles = Get-ChildItem `
                -Path (Join-Path $env:SystemDrive 'Users') `
                -Directory `
                -Force `
                -ErrorAction SilentlyContinue

            if ($null -eq $userProfiles) {
                return
            }

            foreach ($profile in $userProfiles) {

                $location = Join-Path `
                    -Path $profile.FullName `
                    -ChildPath 'Downloads'

                $result = Get-RecoveryCandidateSize -Path $location

                if ($null -eq $result) {
                    continue
                }

                New-DiskSpaceRecoveryCandidate `
                    -Category 'User Data' `
                    -SubCategory 'Downloads' `
                    -Name "Downloads ($($profile.Name))" `
                    -Location $result.Locations `
                    -PotentialRecoveryGB $result.SizeGB `
                    -Recommendation 'Review and remove unneeded files from the Downloads folder.'
            }
        }


        function Find-ArchivedEventLogRecoveryCandidate {

            $location = Join-Path `
                -Path $env:windir `
                -ChildPath 'System32\winevt\Logs'

            if (-not (Test-Path -Path $location -ErrorAction SilentlyContinue)) {
                return
            }

            $archivedLogs = Get-ChildItem `
                -Path $location `
                -Filter 'Archive-*.evtx' `
                -File `
                -Force `
                -ErrorAction SilentlyContinue

            if ($null -eq $archivedLogs) {
                return
            }

            $totalBytes = [decimal]0
            $locations = @()

            foreach ($log in $archivedLogs) {

                if ($null -eq $log.Length) {
                    continue
                }

                $totalBytes += $log.Length
                $locations += $log.FullName
            }

            if ($locations.Count -eq 0) {
                return
            }

            New-DiskSpaceRecoveryCandidate `
                -Category 'Windows Diagnostics' `
                -SubCategory 'Archived Event Logs' `
                -Name 'Archived Windows Event Logs' `
                -Location $locations `
                -PotentialRecoveryGB ([Math]::Round($totalBytes / 1GB, 2)) `
                -Recommendation 'Review archived event logs and remove historical log files if they are no longer required.'
        }


        function Find-LargeWindowsEventLogRecoveryCandidate {

            $minimumSizeBytes = 1GB

            $eventLogs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.FileSize -ge $minimumSizeBytes
                }

            foreach ($log in $eventLogs) {

                if ($null -eq $log.LogFilePath) {
                    continue
                }

                New-DiskSpaceRecoveryCandidate `
                    -Category 'Windows Diagnostics' `
                    -SubCategory 'Event Log' `
                    -Name $log.LogName `
                    -Location $log.LogFilePath `
                    -PotentialRecoveryGB ([Math]::Round($log.FileSize / 1GB, 2)) `
                    -Recommendation 'Review event log retention and maximum size settings. Archive logs before clearing if historical data is required.'
            }


            $locations = @()
            $totalBytes = [decimal]0

            foreach ($log in $eventLogs) {

                if ($null -eq $log.LogFilePath) {
                    continue
                }

                $locations += $log.LogFilePath
                $totalBytes += $log.FileSize
            }
        }


    }

    process {

        # Standard Disk Space Recovery Checks

        Write-Verbose 'Scanning Windows temporary files.'
        Find-WindowsTempRecoveryCandidate

        Write-Verbose 'Scanning user temporary files.'
        Find-UserTempRecoveryCandidate

        Write-Verbose 'Scanning Windows Update download cache.'
        Find-WindowsUpdateCacheRecoveryCandidate

        Write-Verbose 'Scanning Delivery Optimization cache.'
        Find-DeliveryOptimizationRecoveryCandidate

        Write-Verbose 'Scanning Windows Error Reporting data.'
        Find-WindowsErrorReportingRecoveryCandidate

        Write-Verbose 'Scanning Windows crash dump files.'
        Find-CrashDumpRecoveryCandidate

        Write-Verbose 'Scanning Recycle Bin contents.'
        Find-RecycleBinRecoveryCandidate

        Write-Verbose 'Scanning Volume Shadow Copy storage.'
        Find-ShadowCopyRecoveryCandidate

        Write-Verbose 'Scanning hibernation file.'
        Find-HibernationFileRecoveryCandidate

        Write-Verbose 'Scanning paging file configuration.'
        Find-PageFileRecoveryCandidate

        Write-Verbose 'Scanning Windows Installer cache.'
        Find-WindowsInstallerCacheRecoveryCandidate

        Write-Verbose 'Scanning Windows log files.'
        Find-WindowsLogRecoveryCandidate

        Write-Verbose 'Scanning previous Windows installation.'
        Find-WindowsOldRecoveryCandidate

        Write-Verbose 'Scanning Windows upgrade temporary files.'
        Find-WindowsUpgradeTempRecoveryCandidate

        Write-Verbose 'Scanning Windows Search index.'
        Find-WindowsSearchIndexRecoveryCandidate

        Write-Verbose 'Scanning IIS log files.'
        Find-IISLogRecoveryCandidate

        Write-Verbose 'Scanning Windows setup and upgrade logs.'
        Find-WindowsSetupLogRecoveryCandidate

        Write-Verbose 'Scanning Microsoft Defender scan history.'
        Find-WindowsDefenderRecoveryCandidate

        Write-Verbose 'Scanning web browser caches.'
        Find-BrowserCacheRecoveryCandidate

        Write-Verbose 'Scanning user Downloads folder'
        Find-UserDownloadsRecoveryCandidate

        Write-Verbose 'Scanning archived Windows event logs.'
        Find-ArchivedEventLogRecoveryCandidate

        Write-Verbose 'Scanning for large Windows event logs.'
        Find-LargeWindowsEventLogRecoveryCandidate
        
        # Deep-Scan Disk Space Recovery Checks
        if ($PSCmdlet.ParameterSetName -eq 'DeepScan') {
            
            Write-Verbose 'Analyzing the Windows component store.'
            Find-WindowsComponentStoreRecoveryCandidate
        }

    }
}