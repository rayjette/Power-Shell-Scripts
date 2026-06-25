Remove-Module WinEventTools -ErrorAction SilentlyContinue
. "$PSScriptRoot\..\_bootstrap.ps1"

Describe 'ConvertTo-WinEventTimeCreatedXPathExpression' {

    BeforeAll {

    }

    InModuleScope WinEventTools {

        It 'Returns null when no times provided' {

            $result = ConvertTo-WinEventTimeCreatedXPathExpression

            $result | Should -BeNullOrEmpty
        }

        It 'Builds StartTime only expression' {

            $start = Get-Date '2024-01-01'

            $result = ConvertTo-WinEventTimeCreatedXPathExpression -StartTime $start

            $result | Should -Match 'SystemTime'
            $result | Should -Match '>='
        }

        It 'Builds EndTime only expression' {

            $end = Get-Date '2024-01-02'

            $result = ConvertTo-WinEventTimeCreatedXPathExpression -EndTime $end

            $result | Should -Match 'SystemTime'
            $result | Should -Match '<='
        }

        It 'Builds range expression with AND' {

            $start = Get-Date '2024-01-01'
            $end   = Get-Date '2024-01-02'

            $result = ConvertTo-WinEventTimeCreatedXPathExpression `
                -StartTime $start `
                -EndTime $end

            $result | Should -Match 'AND'
        }

    }

}