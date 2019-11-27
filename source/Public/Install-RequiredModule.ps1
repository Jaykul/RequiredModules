function Install-RequiredModule {
    [CmdletBinding(DefaultParameterSetName = "FromFile", SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param(
        # The path to a metadata file listing required modules. Defaults to "RequiredModules.psd1" (in the current working directory).
        [Parameter(Position = 0, ParameterSetName = "FromFile")]
        [Parameter(Position = 0, ParameterSetName = "LocalToolsFromFile")]
        [Alias("Path")]
        [string]$RequiredModulesFile = "RequiredModules.psd1",

        [Parameter(Position = 0, ParameterSetName = "FromHash", Mandatory)]
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

        # Automatically trust all repositories registered on the box
        [switch]$TrustRegisteredRepositories,

        # Suppress normal host information output
        [Switch]$Quiet,

        # If set, the modules are download or installed but not imported
        [Switch]$Import
    )

    if ($PSCmdlet.ParameterSetName -like "*FromFile" -And -Not (Test-Path $RequiredModulesFile -PathType Leaf)) {
        $PSCmdlet.WriteError(
            [System.Management.Automation.ErrorRecord]::new(
                [Exception]::new("RequiredModules file '$($RequiredModulesFile)' not found."),
                "RequiredModules.psd1 Not Found",
                "ResourceUnavailable", $RequiredModulesFile))
        return
    }


    if ($Destination) {
        Write-Debug "Using manually specified Destination directory rather than default Scope"
        AddPSModulePath $Destination -Clean:$CleanDestination
    }

    Write-Progress "Verifying PSRepository trust" -Id 1 -ParentId 0

    if ($TrustRegisteredRepositories) {
        # Force Policy to Trusted so we can install without prompts and without -Force which is bad
        $OriginalRepositories = Get-PSRepository
        foreach ($repo in $OriginalRepositories.Where{ $_.InstallationPolicy -ne "Trusted" }) {
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
                    ConvertToRequiredModule $RequiredModules
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
            foreach ($repo in $OriginalRepositories.Where{ $_.InstallationPolicy -ne "Trusted" }) {
                Write-Verbose "Setting $($repo.Name) back to $($repo.InstallationPolicy)"
                Set-PSRepository $repo.Name -InstallationPolicy $repo.InstallationPolicy
            }
        }
    }
    Write-Progress "Importing Modules" -Id 1 -ParentId 0
    Write-Verbose "Importing Modules"

    if ($Import) {
        Remove-Module $Modules.Name -Force -ErrorAction Ignore
        $Modules | GetModuleVersion -OV InstalledModules | Import-Module -Passthru:(!$Quiet) -Verbose:$false
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