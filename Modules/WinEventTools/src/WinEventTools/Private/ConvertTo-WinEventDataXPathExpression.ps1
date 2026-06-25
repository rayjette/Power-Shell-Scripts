function ConvertTo-WinEventDataXPathExpression {
    <#
    .SYNOPSIS
        Converts an EventData field and its values into a grouped XPath expression.

    .DESCRIPTION
        Takes a single EventData field name and an array of values, and produces
        a valid XPath condition string for use within an EventData filter block.

        Each value is converted into an individual XPath expression using the
        EventData schema:

            Data[@name='FieldName']='Value'

        String values are quoted.  Non-string values are emitted without quotes.

        All generated expressions are combined using OR logic via Join-OrGroup.

        The result is always wrapped in parentheses to ensure consistent structure,
        event when only a single value is provided.

        This function is specific to EventData filtering and does not handle
        system level fields

    .PARAMETER FieldName
        The name of the EventData field.

        Example:
            TargetUserName
            LogonType

    .PARAMETER Values
        An array of values associated with the field.

        Each value will be converted into an individual XPath expression.

        Example:
            @('jsmith', 'mjones')
            @(10, 2)

    .EXAMPLE
        ConvertTo-WinEventDataXPathExpression -FieldName 'TargetUserName' -Values @('jsmith','mjones')

        Output: 
            (Data[@Name='TargetUserName']='jsmith' OR Data[@Name='TargetUserName']='mjones')

    .EXAMPLE
        ConvertTo-WinEventDataXPathExpression -FieldName 'LogonType' -Values @(10)

        Output: 
            (Data[@Name='LogonType']=10)

    .OUTPUTS
        System.String
        Returns a single grouped XPath expression for the specified EventData field.
    #>
    param(
        [string]$FieldName,

        [object[]]$Values
    )

    $expressions = @()
    
    foreach ($value in $Values) {

        # IMPORTANT: XPath 1.0 has no escaping, so all string values must be normalized
        # using ConvertTo-XPathStringLiteral to avoid invalid queries

        # Use helper to ensure XPath-safe string literals
        if ($value -is [string]) {
            $formattedValue = ConvertTo-XPathStringLiteral -Value $value
        } else {
            $formattedValue = $value
        }

        $expressions += "Data[@Name='$FieldName']=$formattedValue"

    }

    return Join-OrGroup -Expression $expressions

}