<#PSScriptInfo

.VERSION 5.1.0

.GUID 295c5e90-c699-4a39-8db2-cb71e564a32d

.AUTHOR Joel 'Jaykul' Bennett

.COMPANYNAME PoshCode

.COPYRIGHT Copyright 2019 Joel Bennett

.TAGS Install Requirements Development Dependencies Modules

.LICENSEURI https://github.com/Jaykul/RequiredModules/blob/master/LICENSE

.PROJECTURI https://github.com/Jaykul/RequiredModules

.ICONURI https://github.com/Jaykul/RequiredModules/blob/master/resources/RequiredModules.png?raw=true

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES

.PRIVATEDATA
#>

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