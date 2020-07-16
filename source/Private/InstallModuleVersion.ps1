filter InstallModuleVersion {
    <#
        .SYNOPSIS
            Installs (or saves) a specific module version (using PowerShellGet)
        .DESCRIPTION
            This function wraps Install-Module to support a -Destination and produce consistent simple errors

            Assumes that the specified module, version and destination all exist
        .EXAMPLE
            InstallModuleVersion -Destination ~\Documents\PowerShell\Modules -Name PowerShellGet -Version "2.1.4"

            Saves a copy of PowerShellGet version 2.1.4 to your Documents\PowerShell\Modules folder
    #>
    [CmdletBinding(DefaultParameterSetName = "Unrestricted")]
    param(
        # Where to install to
        [AllowNull()]
        [string]$Destination,

        # The name of the module to install
        [Parameter(ValueFromPipelineByPropertyName, Mandatory)]
        [string]$Name,

        # The version of the module to install
        [Parameter(ValueFromPipelineByPropertyName, Mandatory)]
        [string]$Version, # This has to stay [string]

        # The scope in which to install the modules (defaults to "CurrentUser")
        [ValidateSet("CurrentUser", "AllUsers")]
        $Scope = "CurrentUser",

        # A specific repository to fetch this particular module from
        [AllowNull()]
        [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName="SpecificRepository")]
        [Alias("RepositorySourceLocation")]
        [string[]]$Repository,

        # Optionally, credentials for the specified repository
        [AllowNull()]
        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName="SpecificRepository")]
        [PSCredential]$Credential
    )
    Write-Progress "Installing module '$($Name)' with version '$($Version)' from the PSGallery"
    Write-Verbose "Installing module '$($Name)' with version '$($Version)' from the PSGallery"
    Write-Verbose "ConfirmPreference: $ConfirmPreference"
    $ModuleOptions = @{
        Name               = $Name
        RequiredVersion    = $Version
        # Allow pre-release because we're always specifying a REQUIRED version
        # If the required version is a pre-release, then we want to allow that
        AllowPrerelease    = $true
        Verbose            = $VerbosePreference -eq "Continue"
        Confirm            = $ConfirmPreference -eq "Low"
        ErrorAction        = "Stop"
        Scope              = $Scope
    }
    if ($Repository) {
        $ModuleOptions["Repository"] = $Repository
        if ($Credential) {
            $ModuleOptions["Credential"] = $Credential
        }
    }

    if ($Destination) {
        $ModuleOptions += @{
            Path = $Destination
        }
        Save-Module @ModuleOptions
    } else {
        $ModuleOptions += @{
            # PowerShellGet requires both -AllowClobber and -SkipPublisherCheck for example
            SkipPublisherCheck = $true
            AllowClobber       = $true
        }
        Install-Module @ModuleOptions
    }

    # We've had weird problems with things failing to install properly, so we check afterward to be sure they're visible
    $null = $PSBoundParameters.Remove("Repository")
    $null = $PSBoundParameters.Remove("Credential")
    $null = $PSBoundParameters.Remove("Scope")
    if (GetModuleVersion @PSBoundParameters -WarningAction SilentlyContinue) {
        $PSCmdlet.WriteInformation("Installed module '$($Name)' with version '$($Version)' from the PSGallery", $script:InfoTags)
    } else {
        $PSCmdlet.WriteError(
            [System.Management.Automation.ErrorRecord]::new(
                [Exception]::new("Failed to install module '$($Name)' with version '$($Version)' from the PSGallery"),
                "InstallModuleDidnt",
                "NotInstalled", $module))
    }
}
