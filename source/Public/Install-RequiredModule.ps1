function Install-RequiredModule {
    <#
        .SYNOPSIS
            Installs (and imports) modules listed in RequiredModules.psd1
        .DESCRIPTION
            Parses a RequiredModules.psd1 listing modules and attempts to import those modules.
            If it can't find the module in the PSModulePath, attempts to install it from PowerShellGet.

            The RequiredModules list looks like this (uses nuget version range syntax, and now, has an optional syntax for specifying the repository to install from):
            @{
                "PowerShellGet" = "2.0.4"
                "Configuration" = "[1.3.1,2.0)"
                "Pester"        = "[4.4.2,4.7.0]"
                "ModuleBuilder"    = @{
                    Version = "2.*"
                    Repository = "https://www.powershellgallery.com/api/v2"
                }
            }

            https://docs.microsoft.com/en-us/nuget/reference/package-versioning#version-ranges-and-wildcards

        .EXAMPLE
            Install-RequiredModule

            Runs the install interactively:
            - reads the default 'RequiredModules.psd1' from the current folder
            - prompts for each module that needs to be installed
        .EXAMPLE
            Install-Script Install-RequiredModule
            Install-RequiredModule @{
                "Configuration" = @{
                    Version = "[1.3.1,2.0)"
                    Repository = "https://www.powershellgallery.com/api/v2"
                }
                "ModuleBuilder" = @{
                    Version = "2.*"
                    Repository = "https://www.powershellgallery.com/api/v2"
                }
            }

            This is one way you can use Install-Required module in a build script to ensure the required module are available.
        .EXAMPLE
            Save-Script Install-RequiredModule -Path ./RequiredModules
            ./RequiredModules/Install-RequiredModule.ps1 -Path ./RequiredModules.psd1 -Confirm:$false -Destination ./RequiredModules -TrustRegisteredRepositories

            This shows another way to use required modules in a build script
            without changing the machine as much (keeping all the files locally)
            and supressing prompts, trusting repositories that are already registerered
    #>
    [CmdletBinding(DefaultParameterSetName = "FromFile", SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param(
        # The path to a metadata file listing required modules. Defaults to "RequiredModules.psd1" (in the current working directory).
        [Parameter(Position = 0, ParameterSetName = "FromFile")]
        [Parameter(Position = 0, ParameterSetName = "LocalToolsFromFile")]
        [Alias("Path")]
        [string]$RequiredModulesFile = "RequiredModules.psd1",

        [Parameter(Position = 0, ParameterSetName = "FromHash")]
        [hashtable]$RequiredModules,

        # If set, the local tools Destination path will be cleared and recreated
        [Parameter(ParameterSetName = "LocalToolsFromFile")]
        [Switch]$CleanDestination,

        # If set, saves the modules to a local path rather than installing them to the scope
        [Parameter(ParameterSetName = "LocalToolsFromFile", Position = 1, Mandatory)]
        [string]$Destination,

        # The scope in which to install the modules (defaults to "CurrentUser")
        [ValidateSet("CurrentUser", "AllUsers")]
        $Scope = "CurrentUser",

        # Automatically trust all repositories registered in the environment.
        # This allows you to leave some repositories set as "Untrusted"
        # but trust them for the sake of installing the modules specified as required
        [switch]$TrustRegisteredRepositories,

        # Suppress normal host information output
        [Switch]$Quiet,

        # If set, the specififed modules are imported (after they are installed, if necessary)
        [Switch]$Import
    )

    [string[]]$script:InfoTags = @("Install")
    if (!$Quiet) {
        [string[]]$script:InfoTags += "PSHOST"
    }

    if ($PSCmdlet.ParameterSetName -like "*FromFile") {
        Write-Progress "Installing required modules from $RequiredModulesFile" -Id 0

        if (-Not (Test-Path $RequiredModulesFile -PathType Leaf)) {
            $PSCmdlet.WriteError(
                [System.Management.Automation.ErrorRecord]::new(
                    [Exception]::new("RequiredModules file '$($RequiredModulesFile)' not found."),
                    "RequiredModules.psd1 Not Found",
                    "ResourceUnavailable", $RequiredModulesFile))
            return
        }
    } else {
        Write-Progress "Installing required modules from hashtable list" -Id 0
    }

    if ($Destination) {
        Write-Debug "Using manually specified Destination directory rather than default Scope"
        AddPSModulePath $Destination -Clean:$CleanDestination
    }

    Write-Progress "Verifying PSRepository trust" -Id 1 -ParentId 0

    if ($TrustRegisteredRepositories) {
        # Force Policy to Trusted so we can install without prompts and without -Force which is bad
        $OriginalRepositories = @(Get-PSRepository)
        foreach ($repo in $OriginalRepositories.Where({ $_.InstallationPolicy -ne "Trusted" })) {
            Write-Verbose "Setting $($repo.Name) Trusted"
            Set-PSRepository $repo.Name -InstallationPolicy Trusted
        }
    }
    try {
        $(  # For all the modules they want to install
            switch -Wildcard ($PSCmdlet.ParameterSetName) {
                "*FromFile" {
                    ImportRequiredModulesFile $RequiredModulesFile -OV Modules
                }
                "FromHash"  {
                    ConvertToRequiredModule $RequiredModules -OV Modules
                }
            }
        ) |
            # Which do not already have a valid version installed
            Where-Object { -not ($_ | GetModuleVersion -Destination:$RealDestination -WarningAction SilentlyContinue) } |
            # Find a version on the gallery
            FindModuleVersion |
            # And install it
            InstallModuleVersion -Destination:$RealDestination -Scope:$Scope -ErrorVariable InstallErrors
    } finally {
        if ($TrustRegisteredRepositories) {
            # Put Policy back so we don't needlessly change environments permanently
            foreach ($repo in $OriginalRepositories.Where({ $_.InstallationPolicy -ne "Trusted" })) {
                Write-Verbose "Setting $($repo.Name) back to $($repo.InstallationPolicy)"
                Set-PSRepository $repo.Name -InstallationPolicy $repo.InstallationPolicy
            }
        }
    }
    Write-Progress "Importing Modules" -Id 1 -ParentId 0
    Write-Verbose "Importing Modules"

    if ($Import) {
        Remove-Module $Modules.Name -Force -ErrorAction Ignore -Verbose:$false
        $Modules | GetModuleVersion -OV InstalledModules | Import-Module -Passthru:(!$Quiet) -Verbose:$false -Scope Global
    } elseif ($InstallErrors) {
        Write-Warning "Module import skipped because of errors. `nSee error details in `$IRM_InstallErrors`nSee required modules in `$IRM_RequiredModules`nSee installed modules in `$IRM_InstalledModules"
        $global:IRM_InstallErrors = $InstallErrors
        $global:IRM_RequiredModules = $Modules
        $global:IRM_InstalledModules = $InstalledModules
    } else {
        Write-Warning "Module import skipped"
    }

    Write-Progress "Done" -Id 0 -Completed
}