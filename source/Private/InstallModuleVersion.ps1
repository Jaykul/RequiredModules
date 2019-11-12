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
    [CmdletBinding()]
    param(
        # Where to install to
        [AllowNull()][string]$Destination,

        # The name of the module to install
        [Parameter(ValueFromPipelineByPropertyName, Mandatory)][string]$Name,

        # The version of the module to install
        [Parameter(ValueFromPipelineByPropertyName, Mandatory)][string]$Version, # This has to stay [string]

        # A specific repository to fetch this particular module from
        [AllowNull()]
        [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName="SpecificRepository")]
        [string[]]$Repository,

        # Optionally, credentials for the specified repository
        [AllowNull()]
        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName="SpecificRepository")]
        [PSCredential]$Credential
    )
    Write-Progress "Installing module '$($Name)' with version '$($Version)' from the PSGallery"
    Write-Verbose "Installing module '$($Name)' with version '$($Version)' from the PSGallery"
    if ($Destination) {
        Save-Module -Name $Name -Repository "PSGallery" -RequiredVersion $Version -Path $Destination -ErrorAction Stop -Verbose:($VerbosePreference -eq "Continue")
    } else {
        $Preferences = @{
            Verbose            = $VerbosePreference -eq "Continue"
            Confirm            = $ConfirmPreference -ne "None"
            Scope              = $Scope
            Repository         = "PSGallery"
            # PowerShellGet requires both -AllowClobber and -SkipPublisherCheck for example
            SkipPublisherCheck = $true
            AllowClobber       = $true
            RequiredVersion    = $Version
            Name               = $Name
        }

        Install-Module @Preferences -ErrorAction Stop
    }

    if (GetModuleVersion @PSBoundParameters -WarningAction SilentlyContinue) {
        $PSCmdlet.WriteInformation("Installed module '$($Name)' with version '$($Version)' from the PSGallery", $InfoTags)
    } else {
        $PSCmdlet.WriteError(
            [System.Management.Automation.ErrorRecord]::new(
                [Exception]::new("Failed to install module '$($Name)' with version '$($Version)' from the PSGallery"),
                "InstallModuleDidnt",
                "NotInstalled", $module))
    }
}
