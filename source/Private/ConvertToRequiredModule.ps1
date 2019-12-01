filter ConvertToRequiredModule {
    <#
        .SYNOPSIS
            Allows converting a full hashtable of dependencies
    #>
    [OutputType([RequiredModule])]
    [CmdletBinding()]
    param(
        # A hashtable of RequiredModules
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Collections.IDictionary]$InputObject
    )
    $InputObject.GetEnumerator().ForEach([RequiredModule])
}
