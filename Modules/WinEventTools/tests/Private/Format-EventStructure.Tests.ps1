# Requires -Modules Pester

Remove-Module WinEventTools -ErrorAction SilentlyContinue
. "$PSScriptRoot\..\_bootstrap.ps1"

InModuleScope WinEventTools {

    Describe 'Format-EventStructure' {

        It 'returns a string' {

            $structure = [pscustomobject]@{
                System = @{ EventID = '1000' }
                EventData = @{}
                UserData = @{ Wrapper = $null; Fields = @{} }
            }

            $result = Format-EventStructure -EventStructure $structure

            $result | Should -BeOfType [string]
        }

        It 'includes the System section header' {

            $structure = [pscustomobject]@{
                System = @{ EventID = '1000' }
                EventData = @{}
                UserData = @{ Wrapper = $null; Fields = @{} }
            }

            $result = Format-EventStructure -EventStructure $structure

            $result | Should -Match '=== System ==='
        }

        It 'formats System properties correctly' {

            $structure = [pscustomobject]@{
                System = @{ EventID = '1000' }
                EventData = @{}
                UserData = @{ Wrapper = $null; Fields = @{} }
            }

            $result = Format-EventStructure -EventStructure $structure

            $result | Should -Match 'EventID'
            $result | Should -Match '1000'
        }

        It 'includes the EventData section header' {

            $structure = [pscustomobject]@{
                System = @{}
                EventData = @{ Field1 = 'Value1' }
                UserData = @{ Wrapper = $null; Fields = @{} }
            }

            $result = Format-EventStructure -EventStructure $structure

            $result | Should -Match '=== EventData ==='
        }

        It 'formats EventData fields correctly' {

            $structure = [pscustomobject]@{
                System = @{}
                EventData = @{ Field1 = 'Value1' }
                UserData = @{ Wrapper = $null; Fields = @{} }
            }

            $result = Format-EventStructure -EventStructure $structure

            $result | Should -Match 'Field1'
            $result | Should -Match 'Value1'
        }

        It 'includes the UserData section header' {

            $structure = [pscustomobject]@{
                System = @{}
                EventData = @{}
                UserData = @{ Wrapper = 'WrapperName'; Fields = @{ FieldA = 'Alpha' } }
            }

            $result = Format-EventStructure -EventStructure $structure

            $result | Should -Match '=== UserData ==='
        }

        It 'formats UserData wrapper correctly' {

            $structure = [pscustomobject]@{
                System = @{}
                EventData = @{}
                UserData = @{ Wrapper = 'WrapperName'; Fields = @{} }
            }

            $result = Format-EventStructure -EventStructure $structure

            $result | Should -Match 'Wrapper: WrapperName'
        }

        It 'formats UserData fields correctly' {

            $structure = [pscustomobject]@{
                System = @{}
                EventData = @{}
                UserData = @{ Wrapper = 'WrapperName'; Fields = @{ FieldA = 'Alpha' } }
            }

            $result = Format-EventStructure -EventStructure $structure

            $result | Should -Match 'FieldA'
            $result | Should -Match 'Alpha'
        }

        It 'shows <none> when no UserData fields exist' {

            $structure = [pscustomobject]@{
                System = @{}
                EventData = @{}
                UserData = @{ Wrapper = $null; Fields = @{} }
            }

            $result = Format-EventStructure -EventStructure $structure

            $result | Should -Match 'Fields : <none>'
        }
    }
}