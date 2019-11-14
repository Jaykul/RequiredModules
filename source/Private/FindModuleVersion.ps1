filter FindModuleVersion {
    <#
        .SYNOPSIS
            Find the first module in the feed(s) that matches the specified name and VersionRange
        .DESCRIPTION
            This function wraps Find-Module -AllVersions to filter according to the specified VersionRange

            Install-RequiredModule supports Nuget style VersionRange, where both minimum and maximum versions can be either inclusive or exclusive. Since Find-Module only supports Inclusive, we can't just use that.
        .EXAMPLE
            FindModuleVersion PowerShellGet "[2.0,5.0)"

            Returns the first version of PowerShellGet greater than 2.0 and less than 5.0 (up to 4.9*) that's available in the feeds (in the results of Find-Module -Allversions)
    #>
    [CmdletBinding(DefaultParameterSetName = "Unrestricted")]
    param(
        # The name of the module to find
        [Parameter(ValueFromPipelineByPropertyName, Mandatory)]
        [string]$Name,

        # The VersionRange for valid modules
        [Parameter(ValueFromPipelineByPropertyName, Mandatory)]
        [VersionRange]$Version,

        # A specific repository to fetch this particular module from
        [AllowNull()]
        [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName="SpecificRepository")]
        [string[]]$Repository,

        # Optionally, credentials for the specified repository
        [AllowNull()]
        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName="SpecificRepository")]
        [PSCredential]$Credential
    )
    Write-Progress "Searching PSRepository for '$Name' module with version '$Version'" -Id 1 -ParentId 0
    Write-Verbose  "Searching PSRepository for '$Name' module with version '$Version'"

    $ModuleParam = @{
        Name = $Name
        Verbose = $false
    }
    if ($Repository) {
        $ModuleParam["Repository"] = $Repository
        if ($Credential) {
            $ModuleParam["Credential"] = $Credential
        }
    }

    $Found = @(Find-Module @ModuleParam -AllVersions).Where({
                ($Version.Float -and $Version.Float.Satisfies($_.Version.ToString())) -or
                (!$Version.Float -and $Version.Satisfies($_.Version.ToString()))
            # Find returns modules in Feed and then Version order,
            # so you're not necessarily getting the highest valid version,
            # but rather the _first_ valid version (as usual)
            }, "First", 1)

    if (-not $Found) {
        Write-Warning "Unable to resolve dependency '$Name' with version '$Version'"
    } else {
        Write-Verbose "Found '$Name' available with version '$($Found.Version)'"
        if($Credential) { # if we have credentials, we're going to need to pass them through ...
            $Found | Add-Member -NotePropertyName Credential -NotePropertyValue $Credential
        }
        $Found
    }
}