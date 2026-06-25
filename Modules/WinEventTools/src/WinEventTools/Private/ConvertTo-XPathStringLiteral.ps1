function ConvertTo-XPathStringLiteral {
    <#
    .SYNOPSIS
        Safely converts a string into a valid XPath string literal.

    .DESCRIPTION
        XPath 1.0 does not support escaping characters within string literals.

        This function ensures that arbitrary string values are safely represented
        in XPath expressions by producing a valid XPath string literal using the
        appropriate quoting strategy:

            1. If the string contains no single quotes:
                Wrap in single quotes

            2. If the string contains single quotes but no double quotes:
                Wrap in double quotes

            3. If the string contains both single and double quotes:
                Construct a concat() expression that safely represents the string

        This prevents syntax errors and ensures compatibility with
        Get-WinEvent XPath filtering.

        If the input value is null or an empty string, the function returns
        an empty XPath string literal ("''").

        This function is required for any XPath string comparisons where
        the value may contain embedded quotes.

    .PARAMETER Value
        The string value to convert into a valid XPath string literal.
        If the value is null or an empty string, the function returns
        an empty XPath string literal ("''").
    
    .EXAMPLE
        ConvertTo-XPathStringLiteral -Value "jsmith"
        Output (XPath literal):
            'jsmith'

    .EXAMPLE
        ConvertTo-XPathStringLiteral -Value "O'Connor"
        Output (XPath literal):
            "O'Connor"
        
    .EXAMPLE
        ConvertTo-XPathStringLiteral -Value 'Bob''s "Admin" Account'
        Output (XPath literal):
            concat('Bob', "'", 's "Admin" Account')

    .EXAMPLE
        ConvertTo-XPathStringLiteral -Value $null

        Output (XPath literal):
            ''
    
    .EXAMPLE
        ConvertTo-XPathStringLiteral -Value ''

        Output (XPath literal):
            ''

    .OUTPUTS
        System.String
        Returns a string formatted as a valid XPath string literal
        expression.
    #>
    param(
        [string]$Value
    )

    if ($null -eq $Value) {
        return "''"
    }

    if ($Value -eq '') {
        return "''"
    }

    # No single quote
    if ($Value -notmatch "'") {
        return "'$Value'"
    }

    # No double quote
    if ($Value -notmatch '"') {
        return "`"$Value`""
    }

    # Contains both → concat()
    $parts = $Value -split "'"
    $result = @()

    for ($i = 0; $i -lt $parts.Count; $i++) {

        if ($parts[$i]) {
            $result += "'$($parts[$i])'"
        }

        if ($i -lt ($parts.Count - 1)) {
            $result += '"''"' 
        }
    }

    return "concat($($result -join ', '))"
}