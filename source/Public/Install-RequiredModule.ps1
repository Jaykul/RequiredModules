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

            The default parameter-less usage reads the default 'RequiredModules.psd1' from the current folder and installs everything to your user scope PSModulePath
        .EXAMPLE
            Install-RequiredModule -Destination .\Modules -Upgrade

            Reads the default 'RequiredModules.psd1' from the current folder and installs everything to the specified "Modules" folder, upgrading any modules where there are newer (valid) versions than what's already installed.
        .EXAMPLE
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

            Uses Install-RequiredModule to ensure Configuration and ModuleBuilder modules are available, without using a RequiredModules metadata file.
        .EXAMPLE
            Save-Script Install-RequiredModule -Path ./RequiredModules
            ./RequiredModules/Install-RequiredModule.ps1 -Path ./RequiredModules.psd1 -Confirm:$false -Destination ./RequiredModules -TrustRegisteredRepositories

            This shows another way to use required modules in a build script
            without changing the machine as much (keeping all the files local to the build script)
            and supressing prompts, trusting repositories that are already registerered
        .EXAMPLE
            Install-RequiredModule @{ Configuration = "*" } -Destination ~/.powershell/modules

            Uses Install-RequiredModules to avoid putting modules in your Documents folder...
    #>
    [CmdletBinding(DefaultParameterSetName = "FromFile", SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param(
        # The path to a metadata file listing required modules. Defaults to "RequiredModules.psd1" (in the current working directory).
        [Parameter(Position = 0, ParameterSetName = "FromFile")]
        [Parameter(Position = 0, ParameterSetName = "LocalToolsFromFile")]
        [Alias("Path")]
        [string]$RequiredModulesFile = "RequiredModules.psd1",

        [Parameter(Position = 0, ParameterSetName = "FromHash")]
        [Parameter(Position = 0, ParameterSetName = "LocalToolsFromHash")]
        [hashtable]$RequiredModules,

        # If set, the local tools Destination path will be cleared and recreated
        [Parameter(ParameterSetName = "LocalToolsFromFile")]
        [Parameter(ParameterSetName = "LocalToolsFromHash")]
        [Switch]$CleanDestination,

        # If set, saves the modules to a local path rather than installing them to the scope
        [Parameter(ParameterSetName = "LocalToolsFromFile", Position = 1, Mandatory)]
        [Parameter(ParameterSetName = "LocalToolsFromHash", Position = 1, Mandatory)]
        [string]$Destination,

        # The scope in which to install the modules (defaults to "CurrentUser")
        [Parameter(ParameterSetName = "FromHash")]
        [Parameter(ParameterSetName = "FromFile")]
        [ValidateSet("CurrentUser", "AllUsers")]
        $Scope = "CurrentUser",

        # Automatically trust all repositories registered in the environment.
        # This allows you to leave some repositories set as "Untrusted"
        # but trust them for the sake of installing the modules specified as required
        [switch]$TrustRegisteredRepositories,

        # Suppress normal host information output
        [Switch]$Quiet,

        # If set, the specififed modules are imported (after they are installed, if necessary)
        [Switch]$Import,

        # By default, Install-RequiredModule does not even check onlin if there's a suitable module available locally
        # If Upgrade is set, it always checks for newer versions of the modules and will install the newest version that's valid
        [Switch]$Upgrade
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
        $Destination = AddPSModulePath $Destination -Clean:$CleanDestination
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
                    Write-Debug "Installing from RequiredModulesFile $RequiredModulesFile"
                    ImportRequiredModulesFile $RequiredModulesFile -OV Modules
                }
                "*FromHash"  {
                    Write-Debug "Installing from in-line hashtable $($RequiredModules | Out-String)"
                    ConvertToRequiredModule $RequiredModules -OV Modules
                }
            }
        ) |
            # Which do not already have a valid version installed (or that we're upgrading)
            Where-Object { $Upgrade -or -not ($_ | GetModuleVersion -Destination:$Destination -WarningAction SilentlyContinue) } |
            # Find a version on the gallery (if we're upgrading, warn if there are versions that are excluded)
            FindModuleVersion -Recurse -WarnIfNewer:$Upgrade | Optimize-Dependency |
            # And if we're not upgrading (or THIS version is not already installed)
            Where-Object {
                if (!$Upgrade) {
                    $true
                } else {
                    $Installed = GetModuleVersion -Destination:$Destination -Name:$_.Name -Version:"[$($_.Version)]"
                    if ($Installed) {
                        Write-Verbose "$($_.Name) version $($_.Version) is already installed."
                    } else {
                        $true
                    }
                }

            } |
            # And install it
            InstallModuleVersion -Destination:$Destination -Scope:$Scope -ErrorVariable InstallErrors
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

    if ($Import) {
        Write-Verbose "Importing Modules"
        Remove-Module $Modules.Name -Force -ErrorAction Ignore -Verbose:$false
        $Modules | GetModuleVersion -OV InstalledModules | Import-Module -Passthru:(!$Quiet) -Verbose:$false -Scope Global
    } elseif ($InstallErrors) {
        Write-Warning "Module import skipped because of errors. `nSee error details in `$IRM_InstallErrors`nSee required modules in `$IRM_RequiredModules`nSee installed modules in `$IRM_InstalledModules"
        Set-Variable -Scope Global -Name IRM_InstallErrors -Value $InstallErrors
        Set-Variable -Scope Global -Name IRM_RequiredModules -Value $Modules
        Set-Variable -Scope Global -Name IRM_InstalledModules -Value $InstalledModules
    } elseif(!$Quiet) {
        Write-Warning "Module import skipped"
    }

    Write-Progress "Done" -Id 0 -Completed
}