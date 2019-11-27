filter GetModuleVersion {
    <#
        .SYNOPSIS
            Find the first installed module that matches the specified name and VersionRange
        .DESCRIPTION
            This function wraps Get-Module -ListAvailable to filter according to the specified VersionRange and path.

            Install-RequiredModule supports Nuget style VersionRange, where both minimum and maximum versions can be either inclusive or exclusive. Since Get-Module only supports Inclusive, we can't just use that.
        .EXAMPLE
            GetModuleVersion ~\Documents\PowerShell\Modules PowerShellGet "[1.0,5.0)"

            Returns any version of PowerShellGet greater than 1.0 and less than 5.0 (up to 4.9*) that's installed in the current user's PowerShell Core module folder.
    #>
    [CmdletBinding(DefaultParameterSetName = "Unrestricted")]
    param(
        # A specific Module install folder to search
        [AllowNull()]
        [string]$Destination,

        # The name of the module to find
        [Parameter(ValueFromPipelineByPropertyName, Mandatory)]
        [string]$Name,

        # The VersionRange for valid modules
        [Parameter(ValueFromPipelineByPropertyName, Mandatory)]
        [VersionRange]$Version
    )
    Write-Progress "Searching PSModulePath for '$Name' module with version '$Version'" -Id 1 -ParentId 0
    Write-Verbose  "Searching PSModulePath for '$Name' module with version '$Version'"
    $Found = @(Get-Module $Name -ListAvailable -Verbose:$false).Where({
        (!$Destination -or $_.ModuleBase.ToUpperInvariant().StartsWith($Destination.ToUpperInvariant())) -and
        (
            ($Version.Float -and $Version.Float.Satisfies($_.Version.ToString())) -or
            (!$Version.Float -and $Version.Satisfies($_.Version.ToString()))
        )
        # Get returns modules in PSModulePath and then Version order,
        # so you're not necessarily getting the highest valid version,
        # but rather the _first_ valid version (as usual)
    }, "First", 1)
    if (-not $Found) {
        Write-Warning "Unable to find module '$Name' installed with version '$Version'"
    } else {
        Write-Verbose "Found '$Name' installed with version '$($Found.Version)'"
        $Found
    }
}