function Optimize-Dependency {
    <#
        .SYNOPSIS
            Optimize a set of objects by their dependencies
        .EXAMPLE
            Find-Module TerminalBlocks, PowerLine | Optimize-Dependency
    #>
    [Alias("Sort-Dependency")]
    [OutputType([Array])]
    [CmdletBinding(DefaultParameterSetName = "ByPropertyFromInputObject")]
    param(
        # The path to a RequiredModules file
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "CustomEqualityFromPath")]
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "ByPropertyFromPath")]
        [string]$Path,

        # The objects you want to sort
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = "CustomEqualityFromInputObject")]
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = "ByPropertyFromInputObject")]
        [PSObject[]]$InputObject,

        # A list of properties used with Compare-Object in the default equality comparer
        # Since this is in RequiredModules, it defaults to "Name", "Version"
        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = "ByPropertyFromInputObject")]
        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = "ByPropertyFromPath")]
        [string[]]$Properties = @("Name", "Version"),

        # A custom implementation of the equality comparer for the InputObjects
        # Must accept two arguments, and return $true if they are equal, $false otherwise
        # InputObjects will only be added to the output if this returns $false
        # The default EqualityFilter compares based on the $Properties
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "CustomEqualityFromInputObject")]
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "CustomEqualityFromPath")]
        [scriptblock]$EqualityFilter = { !($args[0] | Compare-Object $args[1] -Property $Properties) },

        # A ScriptBlock to calculate the dependencies of the InputObjects
        # Defaults to a scriptblock that works for Find-Module and Get-Module
        [Parameter(ValueFromPipelineByPropertyName)]
        [ScriptBlock]$Dependency = {
            if ($_.PSTypeNames -eq "System.Management.Automation.PSModuleInfo") {
                $_.RequiredModules.Name.ForEach{ Get-Module $_ }
            } else {
                $_.Dependencies.Name.ForEach{ Find-Module $_ }
            }
        },

        # Do not pass this parameter. It's only for use in recursive calls
        [Parameter(DontShow)]
        [System.Collections.Generic.HashSet[PSObject]]${ Recursion Ancestors } = @()
    )
    begin {
        if ($null -eq $Optimize_Dependency_Results) {
            $Optimize_Dependency_Results = [System.Collections.Generic.HashSet[PSObject]]::new([PSEquality]::new($Properties, $EqualityFilter))
        }
        if ($Path) {
            $null = $PSBoundParameters.Remove("Path")
            ImportRequiredModulesFile $Path | FindModuleVersion -Recurse | Optimize-Dependency @PSBoundParameters
            return
        }
    }
    process {
        $null = $PSBoundParameters.Remove("InputObject")
        if ($DebugPreference) {
            $Pad = "  " * ${ Recursion Ancestors }.Count
            Write-Debug "${Pad}ENTER: Optimize-Dependency: $(@($InputObject | Select-Object $Properties | ForEach-Object { $_.PsObject.Properties.Value  -join ','}) -join '; ')"
        }

        foreach ($IO in $InputObject) {
            # Optional reference to Ancestors, a hidden variable that acts like a parameter for recursion
            $Optimize_Dependency_Parents = [System.Collections.Generic.HashSet[PSObject]]::new([PSObject[]]@(${ Recursion Ancestors }), [PSEquality]::new($Properties, $EqualityFilter))
            # Technically, if we've seen this object before *at all*, we don't need to recurse it again, but I'm not optimizing that for now
            # However, if we see the same object twice in a single chain, that's a dependency loop, so we're broken
            if (!$Optimize_Dependency_Parents.Add($IO)) {
                Write-Warning "May contain a dependency loop: $(@(@($Optimize_Dependency_Parents) + @($IO) | Select-Object $Properties | ForEach-Object { $_.PsObject.Properties.Value  -join ','}) -join ' --> ')"
                return
            }
            if ($DebugPreference) {
                Write-Debug "${Pad}TRACE: Optimize-Dependency chain: $(@($Optimize_Dependency_Parents | Select-Object $Properties | ForEach-Object { $_.PsObject.Properties.Value  -join ','}) -join ' --> ')"
            }

            $PSBoundParameters[" Recursion Ancestors "] = $Optimize_Dependency_Parents
            ForEach-Object -In $IO -Process $Dependency | Optimize-Dependency @PSBoundParameters
        }
        $InputObject | ForEach-Object {
            if ($Optimize_Dependency_Results.Add($_)) {
                Write-Verbose "Added $(@($_ | Select-Object $Properties | ForEach-Object { $_.PsObject.Properties.Value}) -join ',')"
                $_
            }
        }
        if ($DebugPreference) {
            Write-Debug "${Pad}EXIT: Optimize-Dependency: $(@($InputObject | Select-Object $Properties | ForEach-Object { $_.PsObject.Properties.Value  -join ','}) -join '; ')"
        }
    }
}