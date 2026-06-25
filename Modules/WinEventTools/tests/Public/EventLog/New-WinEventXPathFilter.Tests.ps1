Remove-Module WinEventTools -ErrorAction SilentlyContinue
. "$PSScriptRoot\..\..\_bootstrap.ps1"

Describe 'New-WinEventXPathFilter' {

    BeforeAll {

    }

    It 'Runs without throwing' {
        { New-WinEventXPathFilter } | Should -Not -Throw
    }

    It 'Builds XPath for EventID' {
        $result = New-WinEventXPathFilter -EventID 4624

        $result | Should -Match 'EventID=4624'
    }

    It 'Builds XPath for multiple EventID values (OR logic)' {
        $result = New-WinEventXPathFilter -EventID 4624,4625

        $result | Should -Match 'EventID=4624'
        $result | Should -Match 'EventID=4625'
        $result | Should -Match 'OR'
    }

    It 'Builds XPath for DataFilter (single value)' {
        $result = New-WinEventXPathFilter -DataFilter @{
            TargetUserName = 'jsmith'
        }

        $result | Should -Match "Data\[@Name='TargetUserName'\]='jsmith'"
    }

    It 'Builds XPath for DataFilter (multiple values OR)' {
        $result = New-WinEventXPathFilter -DataFilter @{
            TargetUserName = 'jsmith','mjones'
        }

        $result | Should -Match 'jsmith'
        $result | Should -Match 'mjones'
        $result | Should -Match 'OR'
    }

    It 'Builds XPath with StartTime' {
        $start = (Get-Date).AddHours(-1)

        $result = New-WinEventXPathFilter -StartTime $start

        $result | Should -Match 'TimeCreated'
        $result | Should -Match '>='
    }

    It 'Builds XPath with EndTime' {
        $end = Get-Date

        $result = New-WinEventXPathFilter -EndTime $end

        $result | Should -Match 'TimeCreated'
        $result | Should -Match '<='
    }

    It 'Returns an XPath string when EventID is provided' {
        $result = New-WinEventXPathFilter -EventID 4624

        $result | Should -Not -BeNullOrEmpty
        $result | Should -Match 'EventID=4624'
}

}