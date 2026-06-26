function Join-AndGroup {
    <#
    .SYNOPSIS
        Combines multiple conditional expressions using logical AND.

    .DESCRIPTION
        Accepts one or more pre-built and properly grouped expressions and joins
        them together using AND logic.

        The function performs a simple join operation by inserting " AND "
        between each expression.

        - If multiple expressions are provided, they are combined with " AND ".
        - If a single expression is provided, it is returned unchanged.
        - The function does not modify, validate, or interpret the expressions.
        - It assumes each input expression is already complete and properly grouped.

        This makes the function flexible and reusable for constructing logical
        conditions in various contexts (e.g., filtering, query building, rule evaluation).

    .PARAMETER Expression
        One or more pre-built expressions to combine.

        Each expression should already be valid and logically grouped if needed,
        for example:
            (Status = 'Active')
            (Age > 30 OR Role = 'Admin')
            (Enabled -eq $true)

    .EXAMPLE
        Join-AndGroup -Expression @(
            "(Status = 'Active')",
            "(Role = 'Admin')"
        )

        Output:
            (Status = 'Active') AND (Role = 'Admin')

    .EXAMPLE
        Join-AndGroup -Expression @(
            "(Age > 30 OR Role = 'Admin')",
            "(Enabled = true)"
        )

        Output:
            (Age > 30 OR Role = 'Admin') AND (Enabled = true)

    .EXAMPLE
        # PowerShell-style expressions
        Join-AndGroup -Expression @(
            "($User.Enabled -eq $true)",
            "($User.LastLogin -gt (Get-Date).AddDays(-30))"
        )

        Output:
            ($User.Enabled -eq $true) AND ($User.LastLogin -gt (Get-Date).AddDays(-30))

    .EXAMPLE
        # SQL-style expressions
        Join-AndGroup -Expression @(
            "(FirstName = 'John' OR FirstName = 'Jane')",
            "(IsActive = 1)"
        )

        Output:
            (FirstName = 'John' OR FirstName = 'Jane') AND (IsActive = 1)

    .EXAMPLE
        # Single expression (no change)
        Join-AndGroup -Expression @(
            "(IsActive = 1)"
        )

        Output:
            (IsActive = 1)

    .OUTPUTS
        System.String
        A single string containing all expressions joined with AND.
    #>

    param (
        [string[]]$Expression
    )

    return ($Expression -join ' AND ')
}