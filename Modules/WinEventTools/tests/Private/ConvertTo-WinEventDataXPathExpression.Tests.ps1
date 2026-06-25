Remove-Module WinEventTools -ErrorAction SilentlyContinue
. "$PSScriptRoot\..\_bootstrap.ps1"

Describe 'ConvertTo-WinEventDataXPathExpression' {

    BeforeAll {

    }

    InModuleScope WinEventTools {

        It 'Builds expression for single string value' {

            $result = ConvertTo-WinEventDataXPathExpression `
                -FieldName 'TargetUserName' `
                -Values 'jsmith'

            $result | Should -Be "(Data[@Name='TargetUserName']='jsmith')"
        }

        It 'Builds expression for multiple string values (OR logic)' {

            $result = ConvertTo-WinEventDataXPathExpression `
                -FieldName 'TargetUserName' `
                -Values @('jsmith','mjones')

            $result | Should -Match 'jsmith'
            $result | Should -Match 'mjones'
            $result | Should -Match 'OR'
        }

        It 'Handles numeric values without quotes' {

            $result = ConvertTo-WinEventDataXPathExpression `
                -FieldName 'LogonType' `
                -Values @(10)

            $result | Should -Be "(Data[@Name='LogonType']=10)"
        }

        It 'Handles mixed values correctly' {

            $result = ConvertTo-WinEventDataXPathExpression `
                -FieldName 'TestField' `
                -Values @('jsmith', 10)

            $result | Should -Match 'jsmith'
            $result | Should -Match '10'
            $result | Should -Match 'OR'
        }

        It 'Uses XPath string literal conversion for complex strings' {

            $value = 'Bob''s "Admin" Account'

            $result = ConvertTo-WinEventDataXPathExpression `
                -FieldName 'TargetUserName' `
                -Values $value

            $result | Should -Match 'concat\('
        }

    }

}