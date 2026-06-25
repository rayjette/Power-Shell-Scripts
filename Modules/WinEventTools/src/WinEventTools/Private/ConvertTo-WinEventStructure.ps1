    function ConvertTo-WinEventStructure {

        <#
        .SYNOPSIS
            Converts an event record into a structured representation.

        .DESCRIPTION
            Takes a raw event record and extracts its structural components,
            including System properties, EventData, and UserData.

            The input object must support a ToXml() method that returns valid
            Windows Event XML.  If the object does not support this method or
            cannot be converted to XML, the function wil throw an exception.

            The returned object has the following structure:

            - System: Hashtable of system-level properties
            - EventData: Hashtable of event data fields (if present)
            - UserData:
                - Wrapper: Name of the UserData wrapper element (if present)
                - Fields: Hashtable of UserData fields (if present)

        .OUTPUTS
            PSCustomObject
                A structured representation of the event containing System,
                EventData, and UserData properties.
        #>

        [CmdletBinding()]
        param (
            [Object]$EventRecord
        )

        if (-not $EventRecord) {
            throw "EventRecord cannot be null."
        }

        if (-not $EventRecord.PSObject.Methods['ToXml']) {
            throw 'EventRecord must have a ToXml() method.'
        }

        $xml = [xml]$EventRecord.ToXml()

        # Output container (normalized shape)
        $eventStructure = [pscustomobject]@{
            System    = $null
            EventData = @{}
            UserData  = @{
                Wrapper = $null
                Fields = @{}
            }
        }

        # Extract payload (EventData or UserData)
        
        # decide which payload exists in the event
        if ($xml.Event.EventData) {

            foreach ($prop in $xml.Event.EventData.Data) {
                $eventStructure.EventData[$prop.Name] = $prop.InnerText
            }

        }
        elseif ($xml.Event.UserData) {

            $wrapper = $xml.Event.UserData.ChildNodes[0]

            $eventStructure.UserData.Wrapper = $wrapper.Name

            foreach ($node in $wrapper.ChildNodes) {
                $eventStructure.UserData.Fields[$node.Name] = $node.InnerText
            }

        }
        else {
            # neither exists (both remain empty)
        }

        $system = @{}

        foreach ($node in $xml.Event.System.ChildNodes) {

            # Case 1: Node has attributes
            if ($node.Attributes.Count -gt 0) {

                foreach ($attr in $node.Attributes) {
    
                    $propertyName = "$($node.LocalName)$($attr.Name)"

                    $system[$propertyName] = $attr.Value

                }
            }

            # Case 2: Node has text value
            elseif ($node.InnerText -and $node.InnerText.Trim() -ne '') {

                $system[$node.LocalName] = $node.InnerText
            }

        }

        $eventStructure.System = $system

        return $eventStructure
    }