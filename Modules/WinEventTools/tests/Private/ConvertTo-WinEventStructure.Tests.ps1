# Requires -Modules Pester

Remove-Module WinEventTools -ErrorAction SilentlyContinue
. "$PSScriptRoot\..\_bootstrap.ps1"

InModuleScope WinEventTools {

    Describe 'ConvertTo-WinEventStructure' {

        Context 'When EventData is present' {

            It 'extracts EventData fields correctly' {

                $xml = @"
<Event>
  <System>
    <EventID>1000</EventID>
  </System>
  <EventData>
    <Data Name="Field1">Value1</Data>
    <Data Name="Field2">Value2</Data>
  </EventData>
</Event>
"@

                $fakeEvent = New-Object psobject
                $fakeEvent | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                    return $xml
                }

                $result = ConvertTo-WinEventStructure -EventRecord $fakeEvent

                $result.EventData.Field1 | Should -Be 'Value1'
                $result.EventData.Field2 | Should -Be 'Value2'
            }
        }

        Context 'When UserData is present' {

            It 'extracts UserData fields and wrapper correctly' {

                $xml = @"
<Event>
  <System>
    <EventID>2000</EventID>
  </System>
  <UserData>
    <MyWrapper>
      <FieldA>Alpha</FieldA>
      <FieldB>Beta</FieldB>
    </MyWrapper>
  </UserData>
</Event>
"@

                $fakeEvent = New-Object psobject
                $fakeEvent | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                    return $xml
                }

                $result = ConvertTo-WinEventStructure -EventRecord $fakeEvent

                $result.UserData.Wrapper         | Should -Be 'MyWrapper'
                $result.UserData.Fields.FieldA  | Should -Be 'Alpha'
                $result.UserData.Fields.FieldB  | Should -Be 'Beta'
            }
        }

        Context 'When extracting System properties' {

            It 'extracts system fields and attributes correctly' {

                $xml = @"
<Event>
  <System>
    <Provider Name="TestProvider" />
    <EventID>3000</EventID>
  </System>
</Event>
"@

                $fakeEvent = New-Object psobject
                $fakeEvent | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                    return $xml
                }

                $result = ConvertTo-WinEventStructure -EventRecord $fakeEvent

                $result.System.ProviderName | Should -Be 'TestProvider'
                $result.System.EventID      | Should -Be '3000'
            }
        }
   
        Context 'When EventRecord is null' {

            It 'throws an exception' {

                { ConvertTo-WinEventStructure -EventRecord $null } | Should -Throw
            }
        }
        
        Context 'When EventRecord does not support ToXml' {

            It 'throws an exception' {

                $badObject = [pscustomobject]@{}

                { ConvertTo-WinEventStructure -EventRecord $badObject } | Should -Throw
            }
        }

    }
}