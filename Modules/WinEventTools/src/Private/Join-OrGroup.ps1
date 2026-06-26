function Join-OrGroup {
    <#
    .SYNOPSIS
        Combines multiple expressions into a single logically grouped OR expression.

    .DESCRIPTION
        Accepts one or more pre-built expressions and combines them using OR logic.

        The function performs a simple join operation by inserting " OR "
        between each expression and wrapping the final result in parentheses
        to enforce consistent logical grouping.

        - If multiple expressions are provided, they are joined with " OR "
          and enclosed in parentheses.
        - If a single expression is provided, it is still wrapped in parentheses
          to maintain consistency when composing larger logical structures.
        - The function does not validate, modify, or interpret expressions.
        - It assumes each input expression is already valid in its intended context.

        This consistent grouping behavior makes the function suitable for use
        in dynamic query construction, filtering logic, and rule composition.

    .PARAMETER Expression
        One or more pre-built expressions to combine.

        Each expression should represent a complete logical condition, such as:
            Status = 'Active'
            Age > 30
            $User.Enabled -eq $true

    .EXAMPLE
        Join-OrGroup -Expression @(
            "(Status = 'Active')",
            "(Status = 'Pending')"
        )

        Output:
            ((Status = 'Active') OR (Status = 'Pending'))

    .EXAMPLE
        Join-OrGroup -Expression @(
            "Age > 30",
            "Role = 'Admin'"
        )

        Output:
            (Age > 30 OR Role = 'Admin')

    .EXAMPLE
        # PowerShell-style expressions
        Join-OrGroup -Expression @(
            "($User.Enabled -eq $true)",
            "($User.LockedOut -eq $false)"
        )

        Output:
            (($User.Enabled -eq $true) OR ($User.LockedOut -eq $false))

    .EXAMPLE
        # SQL-style expressions
        Join-OrGroup -Expression @(
            "(FirstName = 'John')",
            "(FirstName = 'Jane')"
        )

        Output:
            ((FirstName = 'John') OR (FirstName = 'Jane'))

    .EXAMPLE
        # Single expression (still grouped)
        Join-OrGroup -Expression "IsActive = 1"

        Output:
            (IsActive = 1)

    .OUTPUTS
        System.String
        A single string containing the expressions combined with OR logic
        and wrapped in parentheses.
    #>
``

    param(
        [string[]]$Expression
    )

    return "($($Expression -join ' OR '))"
}