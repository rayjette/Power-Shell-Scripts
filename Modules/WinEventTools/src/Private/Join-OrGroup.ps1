function Join-OrGroup {
    <#
    .SYNOPSIS
        Combines multiple XPath expressions into a logically grouped OR expression.

    .DESCRIPTION
        Accepts one or more pre-built XPath condition expressions and combine them
        using OR logic.

        When multiple expressions are provided, the function ensures correct logical
        grouping by wrapping the result in parentheses.

        When a single expression is provided, they are always combined into a logically
        grouped OR expression and wrapped in parentheses, even when only a single
        expression is present.

        This ensures consistent structure and simplifies composition when building
        larger XPath expressions.

    .PARAMETER Expression
        One or more XPath condition expressions.

        Each expression must already be a valid XPath fragment, such as:

            EventID=2624
            Data[@Name='TargetUserName']='jsmith'

    .EXAMPLE
        Join-OrGroup -Expression @(
            'EventID=2624',
            'EventID=4625'
        )

        Output:
            (EventID=4624 OR EventID=4625)

    .EXAMPLE
        Join-OrGroup -Expression 'EventID=4624'

        Output:
            (EventID=4624)

    .OUTPUTS
        System.String
        Returns a single XPath expression string with correct OR grouping.
    #>

    param(
        [string[]]$Expression
    )

    return "($($Expression -join ' OR '))"
}