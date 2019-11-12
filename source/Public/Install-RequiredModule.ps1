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

        # Suppress normal host information output
        [Switch]$Quiet,

        # If set, the modules are download or installed but not imported
        [Switch]$Import
    )

    if (-Not (Test-Path $RequiredModulesFile -PathType Leaf)) {
        $PSCmdlet.WriteError(
            [System.Management.Automation.ErrorRecord]::new(
                [Exception]::new("RequiredModules file '$($RequiredModulesFile)' not found."),
                "RequiredModules.psd1 Not Found",
                "ResourceUnavailable", $RequiredModulesFile))
        return
    }

    if ($Destination) {
        if (-not (Test-Path $Destination -PathType Container)) {
            New-Item $Destination -ItemType Directory -ErrorAction Stop
            Write-Verbose "Created Destination directory: $(Convert-Path $Destination)"
        }
        # if (-not $CleanDestination) {
        #     if (Get-ChildItem $Destination) {
        #         $PSCmdlet.WriteError(
        #             [System.Management.Automation.ErrorRecord]::new(
        #                 [Exception]::new("Destination folder '$($Destination)' not empty."),
        #                 "Destination Not Empty",
        #                 "ResourceUnavailable", $Destination))
        #         return
        #     }
        # }
        if ($CleanDestination -and (Get-ChildItem $Destination)) {
            Write-Warning "CleanDestination specified: Removing $($Destination) and all it's children:"
            try {
                Remove-Item $Destination -Recurse -ErrorAction Stop # No -Force -- if this fails, you should handle it yourself
                New-Item $Destination -ItemType Directory
            } catch {
                $PSCmdlet.WriteError(
                    [System.Management.Automation.ErrorRecord]::new(
                        [Exception]::new("Failed to clean destination folder '$($Destination)'"),
                        "Destination Cannot Be Emptied",
                        "ResourceUnavailable", $Destination))
                return
            }
        }
    }

    Write-Progress "Verifying PSRepository trust" -Id 1 -ParentId 0

    # Force Policy to Trusted so we can install without prompts and without -Force which is bad
    # TODO: Add support for all registered PSRepositories
    if ('Trusted' -ne ($Policy = (Get-PSRepository PSGallery).InstallationPolicy)) {
        Write-Verbose "Setting PSGallery Trusted"
        Set-PSRepository PSGallery -InstallationPolicy Trusted
    }

    if ($Destination) {
        # make sure we don't do this multiple times
        $RealDestination = Convert-Path $Destination
        if (-not (@($Env:PSModulePath.Split([IO.Path]::PathSeparator)) -contains $RealDestination)) {
            Write-Verbose "Adding $($RealDestination) to PSModulePath"
            $Env:PSModulePath = $RealDestination + [IO.Path]::PathSeparator + $Env:PSModulePath
        }
    }

    try {
        ImportRequiredModulesFile $RequiredModulesFile -OV Modules |
            Where-Object { -not ($_ | GetModuleVersion -Destination:$RealDestination -WarningAction SilentlyContinue) } |
            FindModuleVersion |
            InstallModuleVersion -Destination:$RealDestination -ErrorVariable InstallErrors
    } finally {
        # Put Policy back so we don't needlessly change environments permanently
        if ('Trusted' -ne $Policy) {
            Write-Verbose "Setting PSGallery Untrusted"
            Set-PSRepository PSGallery -InstallationPolicy $Policy
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