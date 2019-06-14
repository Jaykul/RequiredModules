param(
    # The path to a RequiredModules manifest, relative to the project root
    $RequiredModulesManifest = "RequiredModules.psd1",

    # If set, saves modules to a "RequiredModules" sub-folder instead of installing them
    [Switch]$Local
)

# The path to a folder to install RequiredModules, relative to the project root
$RequiredModulesDestination = "RequiredModules"

Push-Location (Split-Path $PSScriptRoot)

if (!(Test-Path $RequiredModulesDestination)) {
    New-Item -Type Directory $RequiredModulesDestination
}

$RequiredModulesDestination = Convert-Path $RequiredModulesDestination
$RequiredModulesManifest = Convert-Path $RequiredModulesManifest

Save-Script Install-RequiredModule -Path $RequiredModulesDestination
if ($Local) {
    &"$RequiredModulesDestination/Install-RequiredModule.ps1" -Path $RequiredModulesManifest -Destination $RequiredModulesDestination
} else {
    &"$RequiredModulesDestination/Install-RequiredModule.ps1" -Path $RequiredModulesManifest
}

Pop-Location