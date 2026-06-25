# Requires -Modules Pester

Remove-Module WinEventTools -ErrorAction SilentlyContinue
. "$PSScriptRoot\..\..\_bootstrap.ps1"

InModuleScope WinEventTools {

    Describe 'Get-WinEventStructure' {

        BeforeAll {
            # Fake XML used for all tests
            $xml = @"
<Event>
  <System>
    <EventID>1000</EventID>
  </System>
  <EventData>
    <Data Name="Field1">Value1</Data>
  </EventData>
</Event>
"@

            $script:fakeEvent = [pscustomobject]@{}
            $script:fakeEvent | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                return $xml
            }
        }

        Context 'Default behavior (object output)' {

            It 'returns a structured object' {

                Mock Get-SingleWinEvent { return $script:fakeEvent }

                $result = Get-WinEventStructure -LogName Test -EventId 1000

                $result | Should -BeOfType [object]
                $result.System.EventID | Should -Be '1000'
                $result.EventData.Field1 | Should -Be 'Value1'
            }
        }

        Context 'Formatted output' {

            It 'returns a formatted string' {

                Mock Get-SingleWinEvent { return $script:fakeEvent }

                $result = Get-WinEventStructure -LogName Test -EventId 1000 -AsFormattedString

                $result | Should -BeOfType [string]
                $result | Should -Match '=== System ==='
                $result | Should -Match '=== EventData ==='
            }
        }

        Context 'Formatted output with RawXml' {

            It 'includes the RawXml section' {

                Mock Get-SingleWinEvent { return $script:fakeEvent }

                $result = Get-WinEventStructure -LogName Test -EventId 1000 -AsFormattedString -IncludeRawXml

                $result | Should -Match '=== RawXml ==='
                $result | Should -Match '<Event>'
            }
        }

        Context 'Parameter validation' {

            It 'throws when IncludeRawXml is used without AsFormattedString' {

                # Absolute path to module
                $modulePath = Join-Path $PSScriptRoot '..\..\..\src\WinEventTools\WinEventTools.psm1'

                $ps = [powershell]::Create()

                $scriptBlock = @"
Import-Module '$modulePath' -Force
Get-WinEventStructure -LogName Test -EventId 1000 -IncludeRawXml
"@

                $null = $ps.AddScript($scriptBlock)

                $ps.Invoke()

                $ps.HadErrors | Should -BeTrue
            }
        }
    }
}
