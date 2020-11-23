<#PSScriptInfo

.VERSION 5.0.0

.GUID 6083ddaa-3951-4482-a9f7-fe115ddf8021

.AUTHOR Joel 'Jaykul' Bennett

.COMPANYNAME PoshCode

.COPYRIGHT Copyright 2019, Joel Bennett

.TAGS Install Modules Development ModuleBuilder Dependencies

.LICENSEURI https://github.com/Jaykul/RequiredModules/blob/master/LICENSE

.PROJECTURI https://github.com/Jaykul/RequiredModules/

.ICONURI https://github.com/Jaykul/RequiredModules/blob/master/resources/images/install.png

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
    5.0.0 Breaking change: Allows installing from any trusted repository! In this version, we no longer automatically trust PSGallery. You must ensure that there is at least one repository already registered and trusted.

    For instance, you could ensure the PSGallery is registered, and trust it:

        Register-PSRepository -Default -ErrorAction Ignore -InstallationPolicy Trusted
        Get-PSRepository -Name PSGallery | Set-PSRepository -InstallationPolicy Trusted

    By default, we only install from trusted repositories, but there is a new TrustRegisteredRepositories switch which ensures all of the repositories that are registered are treated as trusted for the purposes of installing the required modules.

    There is a new syntax for the RequiredModules hashtables to support specifying a specific repository for each module.

    Remember, Install-RequiredModule does not explicitly require PowerShellGet. PowerShell 5+ automatically include a version of it, and we assume that you're using it to install this script. If you need a higher version (which you very well may) you should put it in your RequiredModules manifest.

.PRIVATEDATA

#>
using namespace NuGet.Versioning
using namespace Microsoft.PowerShell.Commands
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
if (-not ("NuGet.Versioning.VersionRange" -as [Type])) {
    throw "You must import Nuget.Versioning"
    $UncompressedFileBytes = [byte[]]::new(<#NuGetVersioningSize#>)
    $DeflatedStream = [System.IO.Compression.DeflateStream]::new(
        [IO.MemoryStream][Convert]::FromBase64String($EncodedCompressedFile),
        [IO.Compression.CompressionMode]::Decompress)
    $null = $DeflatedStream.Read($UncompressedFileBytes, 0, <#NuGetVersioningSize#>)
    $null = [Reflection.Assembly]::Load($UncompressedFileBytes)
}