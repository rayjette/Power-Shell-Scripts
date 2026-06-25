Remove-Module WinEventTools -ErrorAction SilentlyContinue
. "$PSScriptRoot\..\_bootstrap.ps1"

Describe 'Join-OrGroup' {

    BeforeAll {

    }

    InModuleScope WinEventTools {

        It 'Combines multiple expressions using OR' {

            $result = Join-OrGroup -Expression @(
                'EventID=4624',
                'EventID=4625'
            )

            $result | Should -Be "(EventID=4624 OR EventID=4625)"
        }

        It 'Wraps a single expression in parentheses' {

            $result = Join-OrGroup -Expression 'EventID=4624'

            $result | Should -Be "(EventID=4624)"
        }

        It 'Handles multiple arbitrary expressions correctly' {

            $result = Join-OrGroup -Expression @(
                "Data[@Name='User']='jsmith'",
                "Data[@Name='LogonType']=10"
            )

            $result | Should -Match 'OR'
            $result | Should -Match 'jsmith'
            $result | Should -Match 'LogonType'
        }

    }

}