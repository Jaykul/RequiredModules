<#PSScriptInfo

.VERSION 4.1.1

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
[CmdletBinding(DefaultParameterSetName="FromHash", ConfirmImpact="High", SupportsShouldProcess)]
param(
    # The path to a metadata file listing required modules. Defaults to "RequiredModules.psd1" (in the current working directory).
    [Parameter(Position=0, ParameterSetName="FromFile")]
    [Parameter(Position=0, ParameterSetName="LocalToolsFromFile")]
    [Alias("Path")]
    [string]$RequiredModulesFile = "RequiredModules.psd1",

    [Parameter(Position=0, ParameterSetName="FromHash", Mandatory)]
    [hashtable]$RequiredModules,

    # If set, the local tools Destination path will be cleared and recreated
    [Parameter(ParameterSetName="LocalToolsFromFile")]
    [Switch]$CleanDestination,

    # If set, saves the modules to a local path rather than installing them to the scope
    [Parameter(Position=1, ParameterSetName="LocalToolsFromFile", Mandatory)]
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