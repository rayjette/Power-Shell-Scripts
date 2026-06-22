function New-WinEventXPathFilter {
    <#
    .SYNOPSIS
        Builds an XPath query for filtering Windows Event Logs using Get-WinEvent.

    .DESCRIPTION
        Generates a valid XPath expression for querying Windows Event Logs.

        The function supports a structured filtering model consisting of:

            1. System Filter (fixed schema)
                - EventID (int array)
                - StartTime (datetime)
                - EndTime (datetime)

            2. Data Filter (dynamic schema)
                - Hashtable of EventData field filters
                - Each key represents an EventData field name
                - Each value may be:
                    - a single value
                    - or an array of values

        OUTPUT FORMATS
            The function supports two output formats:

                - Compact (default)
                    A single-line XPath expression suitable for direct use with Get-WinEvent.

                - Pretty
                    A multi-line formatted XPath expression intended for debugging.

       LOGICAL MODEL

            A. Within a single field (DataFilter values):
                - Multiple values are combined using OR logic.

                Example:
                    TargetUserName = 'jsmith', 'mjones'

                Becomes:
                    (TargetUserName='jsmith' OR TargetUserName='mjones')

            B. Between different fields:
            - Fields are combined using AND logic.

                Example:
                    TargetUserName AND LogonType

                Becomes:
                    (User condition) AND (LogonType condition)

            C. System vs EventData:
            - System filters and EventData filters are independent blocks
            - Both blocks are combined using AND logic

        FINAL XPATH STRUCTURE:

        *[
            System[ ... ]
            AND
            EventData[ ... ]
        ]
       
    .PARAMETER EventID
        One or more Event IDs to filter on.
        Multiple values are combined using OR logic.

    .PARAMETER StartTime
        Start of the range filter (inclusive).

    .PARAMETER EndTime
        End of time range filter (inclusive).

    .PARAMETER DataFilter
        Hashtable of EventData filters.

        key = EventData field name
        Value = single value or array of values

        Example:
            @{
                TargetUsername = 'jsmith', 'mjones'
                LogonType      = 10, 2
            }

    .PARAMETER Format
        Specifies output formatting mode.

        Valid values:

        - compact (default)
            Returns a single-line XPath expression suitable for execution.
        
        - Pretty
            Returns a multi-line formatted XPath expression with indentation,
            used for debugging and readability.

    .EXAMPLE
        New-WinEventXPath -EventID 4624 -DataFilter @{
            TargetUserName = 'jsmith', 'mjones'
            LogonType      = 10
        }

    .OUTPUTS
        System.String
        Returns an XPath query string in either Compact or Pretty format.
    #>

    param (
        [int[]]$EventID,

        [string[]]$ProviderName,

        [datetime]$StartTime,
        [datetime]$EndTime,

        [hashtable]$DataFilter,

        [ValidateSet('Compact', 'Pretty')]
        [string]$Format = 'Compact'
    )


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
            One ore more XPath condition expressions.

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


    function Join-AndGroup {
        <#
        .SYNOPSIS
            Combine multiple XPath expressions into a single AND expression.

        .DESCRIPTION
            Accepts one or more pre-built, parenthesized XPath condition expressions
            and combine them using AND logic.

            The function performs a simple join operation using the AND operator.

            If multiple expressions are provided, they are joined with " AND " between them.

            If a single expression is provided, it is returned unchanged.

            This function does not add additional parentheses and assumes that each
            input expression is already properly grouped.

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

            OUTPUT:
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

 
    function ConvertTo-XPathStringLiteral {
        <#
        .SYNOPSIS
            Safely converts a string into a valid XPath string literal.

        .DESCRIPTION
            XPath 1.0 does not support escaping characters within string literals.

            This function ensures that arbitrary string values are safely represented
            in XPath expressions by selecting the appropriate quoting strategy:

                1. If the string contains no single quotes:
                    Wrap in single quotes

                2. If the string contains single quotes but no double quotes:
                    Wrap in double quotes

                3. If the string contains both single and double quotes:
                    Construct a concat() expression that safely represents the string

            This prevents syntax errors and ensures compatibility with
            Get-WinEvent XPath filtering.

            This function is required for any EventData string comparisons where
            the value may contain embedded quotes.

        .PARAMETER Value
            The string value to convert into a valid XPath literal.
        
        .EXAMPLE
            ConvertTo-XPathStringLiteral -Value "jsmith"
            Output:
                'jsmith'

        .EXAMPLE
            ConvertTo-XPathStringLiteral -Value "O'Connor"
            Output:
                "O'Connor"
            
        .EXAMPLE
            ConvertTo-XPathStringLiteral -Value 'Bob''s "Admin" Account'
            Output:
                concat('Bob', "'", 's "Admin" Account')

        .OUTPUTS
            System.String
            Returns a valid XPath string liberal expression.
        #>
        param(
            [string]$Value
        )

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


    function ConvertTo-EventDataExpression {
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
            ConvertTo-EventDataExpression -FieldName 'TargetUserName' -Values @'jsmith','mjones')

            Output: 
                (Data[@Name='TargetUserName']='jsmith' OR Data[@Name='TargetUserName']='mjones')

        .EXAMPLE
            ConvertTo-EventDataExpression -FieldName 'LogonType' -Values @(10)

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


    function ConvertTo-TimeCreatedExpression {
        <#
        .SYNOPSIS
            Converts StartTime and EndTime parameters into a TimeCreated XPath expression.

        .DESCRIPTION
            Generate an XPath condition for filtering events based on their creation time.

            The function supports inclusive time range filtering using the SystemTime field:

                @SystemTime >= SystemTime
                @SystemTime <= EndTime

            Either StartTime or EndTime may be provided independently.

            When both values are provided, they are combined using AND logic.

            When only one value is provided, only the corresponding comparison is generated.

            If neither StartTime nor EndTime is specified, the function returns no output,
            allowing all events to pass through without time-based filtering.

            This function is specific to the System section of the XPath query and does
            not participate in OR or AND grouping beyond its internal logic.

        .PARAMETER StartTime
            The beginning of the event time range (inclusive).

        .PARAMETER EndTime
            The end of the event time range (inclusive).

        .EXAMPLE
            ConvertTo-TimeCreatedExpression -Starttime $start -EndTime $end

            Output:
                TimeCreated[@System >= 'start' and @SystemTime <= 'end']

        .EXAMPLE
            ConvertTo-TimeCreatedExpression -StartTime $start

            Output:
                TimeCreated[@SystemTime >= 'start']

        .EXAMPLE
            ConvertToTimeCreatedExpression -EndTime $end

            output:
                TimeCreated[@SystemTime <= 'end']

        .EXAMPLE
            ConvertTo-TimeCreatedExpression

            Output:
                (no output)

        .OUTPUTS
            System.String

            Returns a TimeCreated XPath condition string, or no output if no time
            parameters are provided.
        #>

        param(
            [datetime]$StartTime,
            [datetime]$EndTime
        )

        $timeParts = @()

        if ($StartTime) {
            $utcStart = $StartTime.ToUniversalTime().ToString("o")
            $timeParts += "@SystemTime >= '$utcStart'"
        }

        if ($EndTime) {
            $utcEnd = $EndTime.ToUniversalTime().ToString("o")
            $timeParts += "@SystemTime <= '$utcEnd'"
        }

        if ($timeParts.Count -eq 0) {
            return $null
        }

        # Join conditions
        $joined = $timeParts -join ' AND '

        # Return full XPath fragment
        return "TimeCreated[$joined]"
    }


    # SYSTEM
    $systemExpressions = @()

    # EventID
    if ($EventID -and $EventID.Count -gt 0) {

        $eventIdExpressions = foreach ($id in $EventID) {
            "EventID=$id"
        }

        $systemExpressions += Join-OrGroup -Expression $eventIdExpressions
    }

    # providerName 
    if ($ProviderName -and $ProviderName.Count -gt 0) {
        
        $providerExpressions = foreach ($name in $ProviderName) {
            $formattedName = ConvertTo-XPathStringLiteral -Value $name
            "Provider[@Name=$formattedName]"
        }

        $systemExpressions += Join-OrGroup -Expression $providerExpressions

    }


    $timeParams = @{}

    if ($StartTime) {
        $timeParams.StartTime = $StartTime
    }

    if ($EndTime) {
        $timeParams.EndTime = $EndTime
    }

    if ($timeParams.Count -gt 0) {
        $timeExpression = ConvertTo-TimeCreatedExpression @timeParams
    }

    if ($timeExpression) {
        $systemExpressions += $timeExpression
    }

    # Combine System
    if ($systemExpressions.Count -gt 0) {
        $systemBlock = Join-AndGroup -Expression $systemExpressions
        $systemBlock = "System[$systemBlock]"
    }

    # EVENTDATA
    $eventDataExpressions = @()

    if ($DataFilter -and $DataFilter.Count -gt 0) {
        foreach ($key in $DataFilter.Keys) {

            $values = $DataFilter[$key]

            # Normalize scaler -> array
            if ($values -isnot [System.Collections.IEnumerable] -or $values -is [string]) {
                $values = @($values)
            }

            $expr = ConvertTo-EventDataExpression -FieldName $key -Values $values
            $eventDataExpressions += $expr
        }
    }

    # Combine EventData
    if ($eventDataExpressions.Count -gt 0) {
        $eventDataBlock = Join-AndGroup -Expression $eventDataExpressions
        $eventDataBlock = "EventData[$eventDataBlock]"
    }

    $finalExpressions = @()

    if ($systemBlock) {
        $finalExpressions += $systemBlock
    }

    if ($eventDataBlock) {
        $finalExpressions += $eventDataBlock
    }

    if ($finalExpressions.Count -gt 0) {
        $final = Join-AndGroup -Expression $finalExpressions
        $xpath = "*[$final]"
    }

    # NOTE:
    # Pretty formatting is best-effort and intended for readability/debugging only.
    # This version avoids fragile global string replacements by formatting known blocks.
    if ($Format -eq 'Pretty' -and $finalExpressions.Count -gt 0) {

        $pretty = @()
        $pretty += "*["

        if ($systemBlock) {
            $pretty += "    System["
            $pretty += "        $($systemBlock -replace '^System\[|\]$','')"
            $pretty += "    ]"
        }

        if ($systemBlock -and $eventDataBlock) {
            $pretty += "    AND"
        }

        if ($eventDataBlock) {
            $pretty += "    EventData["
            $pretty += "        $($eventDataBlock -replace '^EventData\[|\]$','')"
            $pretty += "    ]"
        }

        $pretty += "]"

        $xpath = ($pretty -join "`n")
    }

    return $xpath

}