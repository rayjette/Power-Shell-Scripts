    function ConvertTo-WinEventTimeCreatedXPathExpression {
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