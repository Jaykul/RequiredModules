class PSEquality : System.Collections.Generic.EqualityComparer[PSObject] {
    <#
        A customizable equality comparer for PowerShell
        By default compares objects using PowerShell's default -eq

        Supports passing a custom `Properties` list (e.g. "Name" to only compare names, or "Name", "Version" to compare name and version but nothing else)
        The default is a comparison using all properties

        Supports passing a custom `Equals` scriptblock (e.g. { $args[0].Equals($args[1]) } to use .net .Equals)
        Note that passing Equals means Properties are ignored (unless you use them)
    #>
    # A simple list of properties to be used in the comparison
    [string[]]$Properties = "*"

    # A custom implementation of the Equals method
    # Must accept two arguments
    # Must return $true if they are equal, $false otherwise
    [scriptblock]$Equals = {
        $left, $right = $args | Select-Object $this.Properties
        $Left -eq $right
    }

    PSEquality() {}

    PSEquality([string[]]$Properties) {
        $this.Properties = $Properties
    }

    PSEquality([scriptblock]$Equals) {
        $this.Equals = $Equals
    }

    PSEquality([string[]]$Properties, [scriptblock]$Equals) {
        $this.Properties = $Properties
        $this.Equals = $Equals
    }

    [bool] Equals([PSObject]$first, [PSObject]$second) {
        return [bool](& $this.Equals $first $second)
    }

    [int] GetHashCode([PSObject]$PSObject) {
        return $PSObject.GetHashCode()
    }
}
