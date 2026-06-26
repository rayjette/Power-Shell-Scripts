function Join-AndGroup {
    <#
    .SYNOPSIS
        Combine multiple XPath expressions into a single AND expression.

    .DESCRIPTION
        Accepts one or more pre-built, parenthesized XPath condition expressions
        and combines them using AND logic.

        The function performs a simple join operation using the "AND" operator.

        If multiple expressions are provided, they are joined with " AND " between them.

        If a single expression is provided, it is returned unchanged without modification.

        This function does not add additional parentheses and assumes that each
        input expression is already properly grouped.

        The function does not modify the internal structure of the
        expression and only joins them using the "AND" operator.
        
        This function is schema-agnostic and does not construct or interpret XPath
        fields.  It operates only on fully-formed expression strings.

    .PARAMETER Expression
        One or more XPath condition expressions.

        Each expression must already be a valid and properly grouped XPath fragment,
        such as:
            (EventID=4624 OR EventID=4625)
            (Data[@Name='TargetUserName']='jsmith')

    .EXAMPLE
        Join-AndGroup -Expression @(
            "(Data[@Name='TargetUserName']='jsmith' OR Data[@Name='TargetUserName']='mjones')",
            "(Data[@Name='LogonType']=10)"
        )

        Output:
            (Data[@Name='TargetUserName']='jsmith' OR Data[@Name='TargetUserName']='mjones') AND (Data[@Name='LogonType']=10)

    .EXAMPLE
        Join-AndGroup -Expression @(
            "(Data[@Name='LogonType']=10)"
        )
            Output:
                (Data[@Name='LogonType']=10)

    .OUTPUTS
        System.String
        Returns a single XPath expression string joined using AND logic.
    #>

    param (
        [string[]]$Expression
    )

    return ($Expression -join ' AND ')
}