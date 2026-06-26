# Get-NTLMAuthenticationEvent.Tests.ps1

BeforeAll {
    $ScriptsRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    . (Join-Path $ScriptsRoot "Security\Get-NTLMAuthenticationEvent.ps1")
}

Describe "Get-NTLMAuthenticationEvent" {

    Context "Parameter validation" {

        BeforeEach {
            Mock Get-WinEvent { @() }
        }

        It "Runs with Days parameter set" {
            { Get-NTLMAuthenticationEvent -Days 1 } | Should -Not -Throw
        }

        It "Accepts valid TimeRange parameters" {
            $start = (Get-Date).AddHours(-1)
            $end   = Get-Date

            { Get-NTLMAuthenticationEvent -StartTime $start -EndTime $end } | Should -Not -Throw
        }

        It "Allows StartTime greater than EndTime" {
            $start = Get-Date
            $end   = (Get-Date).AddHours(-1)

            { 
                Get-NTLMAuthenticationEvent -StartTime $start -EndTime $end 
            } | Should -Not -Throw
        }
    }

    Context "Event processing" {

        BeforeEach {
            Mock Get-WinEvent {

                $event = [pscustomobject]@{
                    TimeCreated = Get-Date
                    Id          = 8003
                    MachineName = "SERVER01"
                }

                $event | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
@"
<Event>
  <EventData>
    <Data Name="DomainName">DOMAIN</Data>
    <Data Name="UserName">testuser</Data>
    <Data Name="WorkstationName">WS01</Data>
    <Data Name="ProcessName">lsass.exe</Data>
    <Data Name="ProcessId">1234</Data>
  </EventData>
</Event>
"@
                }

                return $event
            }
        }

        It "Returns parsed NTLM events" {
            $result = Get-NTLMAuthenticationEvent -StartTime (Get-Date).AddHours(-1) -EndTime (Get-Date)
            $result | Should -Not -BeNullOrEmpty
        }

        It "Returns expected properties" {
            $result = Get-NTLMAuthenticationEvent -StartTime (Get-Date).AddHours(-1) -EndTime (Get-Date)
            $obj = $result | Select-Object -First 1

            $obj.User    | Should -Match "testuser"
            $obj.Source  | Should -Match "WS01"
            $obj.EventId | Should -Be 8003
        }

        It "Invokes Get-WinEvent" {
            Get-NTLMAuthenticationEvent -StartTime (Get-Date).AddHours(-1) -EndTime (Get-Date)
            Should -Invoke Get-WinEvent -Times 1
        }
    }

    Context "Filtering" {

        BeforeEach {
            Mock Get-WinEvent {

                $event = [pscustomobject]@{
                    TimeCreated = Get-Date
                    Id          = 8003
                    MachineName = "SERVER01"
                }

                $event | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
@"
<Event>
  <EventData>
    <Data Name="DomainName">DOMAIN</Data>
    <Data Name="UserName">adminuser</Data>
    <Data Name="WorkstationName">WS01</Data>
  </EventData>
</Event>
"@
                }

                return $event
            }
        }

        It "Filters matching users" {
            $result = Get-NTLMAuthenticationEvent -User "*admin*" -StartTime (Get-Date).AddHours(-1) -EndTime (Get-Date)
            $result | Should -Not -BeNullOrEmpty
        }

        It "Filters non-matching users" {
            $result = Get-NTLMAuthenticationEvent -User "nomatch*" -StartTime (Get-Date).AddHours(-1) -EndTime (Get-Date)
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Empty results" {

        BeforeEach {
            Mock Get-WinEvent { @() }
        }

        It "Returns empty when no events exist" {
            $result = Get-NTLMAuthenticationEvent -StartTime (Get-Date).AddHours(-1) -EndTime (Get-Date)
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Error handling" {

        BeforeEach {
            Mock Get-WinEvent { throw "Access denied" }
        }

        It "Bubbles up errors from Get-WinEvent" {
            {
                Get-NTLMAuthenticationEvent -StartTime (Get-Date).AddHours(-1) -EndTime (Get-Date)
            } | Should -Throw
        }
    }
}
