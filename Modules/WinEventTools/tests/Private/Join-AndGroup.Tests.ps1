Remove-Module WinEventTools -ErrorAction SilentlyContinue
. "$PSScriptRoot\..\_bootstrap.ps1"

Describe 'Join-AndGroup' {

    BeforeAll {

    }

    InModuleScope WinEventTools {

        It 'Combines multiple expressions using AND' {

            $result = Join-AndGroup -Expression @(
                '(EventID=4624)',
                '(EventID=4625)'
            )

            $result | Should -Be "(EventID=4624) AND (EventID=4625)"
        }

        It 'Returns single expression unchanged' {

            $result = Join-AndGroup -Expression '(EventID=4624)'

            $result | Should -Be "(EventID=4624)"
        }

        It 'Handles multiple complex expressions correctly' {

            $result = Join-AndGroup -Expression @(
                "(Data[@Name='User']='jsmith' OR Data[@Name='User']='mjones')",
                "(Data[@Name='LogonType']=10)"
            )

            $result | Should -Match 'AND'
            $result | Should -Match 'jsmith'
            $result | Should -Match 'LogonType'
        }

    }

}