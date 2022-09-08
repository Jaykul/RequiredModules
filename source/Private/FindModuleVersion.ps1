filter FindModuleVersion {
    <#
        .SYNOPSIS
            Find the first module in the feed(s) that matches the specified name and VersionRange
        .DESCRIPTION
            This function wraps Find-Module -AllVersions to filter according to the specified VersionRange

            RequiredModules supports Nuget style VersionRange, where both minimum and maximum versions can be _either_ inclusive or exclusive
            Since Find-Module only supports Inclusive, and only returns a single version if we use the Min/Max parameters, we have to use -AllVersions
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
        [NuGet.Versioning.VersionRange]$Version,

        # Set to allow pre-release versions (defaults to tru if either the minimum or maximum are a pre-release, false otherwise)
        [switch]$AllowPrerelease = $($Version.MinVersion.IsPreRelease, $Version.MaxVersion.IsPreRelease -contains $True),

        # A specific repository to fetch this particular module from
        [AllowNull()]
        [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName="SpecificRepository")]
        [string[]]$Repository,

        # Optionally, credentials for the specified repository
        [AllowNull()]
        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName="SpecificRepository")]
        [PSCredential]$Credential,

        # Optionally, find dependencies (causes this to return more than one result)
        [switch]$Recurse
    )
    begin {
        $Trusted = Get-PSRepository -OutVariable Repositories | Where-Object { $_.InstallationPolicy -eq "Trusted" }
    }
    process {
        Write-Progress "Searching PSRepository for '$Name' module with version '$Version'" -Id 1 -ParentId 0
        Write-Verbose  "Searching PSRepository for '$Name' module with version '$Version'"

        $ModuleParam = @{
            Name = $Name
            Verbose = $false
            IncludeDependencies = [bool]$Recurse
        }
        # AllowPrerelease requires modern PowerShellGet
        if ((Get-Module PowerShellGet).Version -ge "1.6.0") {
            $ModuleParam.AllowPrerelease = $AllowPrerelease
        } elseif($AllowPrerelease) {
            Write-Warning "Installing pre-release modules requires PowerShellGet 1.6.0 or later. Please add that at the top of your RequiredModules!"
        }
        if ($Repository) {
            $Repository = $Repositories.Where{ $_.Name -in $Repository -or $_.SourceLocation -in $Repository }.Name
            $ModuleParam["Repository"] = $Repository
            if ($Credential) {
                $ModuleParam["Credential"] = $Credential
            }
        }

        # Find returns modules in Feed and then Version order
        # Before PowerShell 6, sorting didn't preserve order, so we avoid it
        $Found = Find-Module @ModuleParam -AllVersions -OutVariable All | Where-Object {
                $_.Name -eq $Name -and
                ($Version.Float -and $Version.Float.Satisfies($_.Version.ToString())) -or
                (!$Version.Float -and $Version.Satisfies($_.Version.ToString()))
            }

        # $Found | Format-Table Name, Version, Repository, RepositorySourceLocation | Out-String -Stream | Write-Debug

        if (-not $Found) {
            Write-Warning "Unable to resolve dependency '$Name' with version '$Version'"
        } else {
            # Because we can't trust sorting in PS 5, we need to try checking for
            if (!($Single = @($Found).Where({ $_.RepositorySourceLocation -in $Trusted.SourceLocation }, "First", 1))) {
                $Single = $Found[0]
                Write-Warning "Dependency '$Name' with version '$($Single.Version)' found in untrusted repository $($Single.Repository) ($($Single.RepositorySourceLocation))"
            } else {
                Write-Verbose "Found '$Name' available with version '$($Single.Version)' in trusted repository $($Single.Repository) ($($Single.RepositorySourceLocation))"
            }

            if ($Recurse) {
                $Count = [Array]::IndexOf($All, $Single) + 1
                if ($All.Count -gt $Count) {
                    $Remaining = @($All | Select-Object -Skip $Count).Where({ $_.Name -eq $Name }, "Until")
                    [Array]::Reverse($Remaining)
                }
            }

            if ($Credential) { # if we have credentials, we're going to need to pass them through ...
                @($Remaining) + @($Single) | Add-Member -NotePropertyName Credential -NotePropertyValue $Credential
            }
            @($Remaining) + @($Single)
        }
    }
}