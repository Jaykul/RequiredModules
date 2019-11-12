#requires -Module RequiredModule
using module RequiredModule
using namespace NuGet.Versioning

Describe "GetModuleVersion calls Get-Module and filters based on the VersionRange" {

    # This mock dumps a _ton_ of module info looking things for every query ....
    # Get-Module returns results HIGHEST to LOWEST (but also by folder)
    Mock Get-Module -Module RequiredModule {
        $Folders = @{
            "C:\Program Files\PowerShell\Modules" = @('3.4.0', '3.0.0', '2.2.4', '1.0.1', '1.0.0')
            "C:\Users\YourName\Documents\PowerShell" = @('3.5.0', '3.4.5', '3.4.1')
        }

        $(
            foreach($Module in $Name) {
                foreach($ModuleFolder in $Folders.GetEnumerator()) {
                    foreach ($Version in $ModuleFolder.Value) {
                        [PSCustomObject]@{
                            PSTypeName   = "ModuleInfo"
                            Name         = $Module
                            Version      = $Version
                            ModuleBase   = Join-Path $ModuleFolder.Key $Module
                            ModuleFolder = $ModuleFolder
                        }
                    }
                }
            }
        ) | Sort-Object ModuleFolder, Name, {[Version]$_.Version}
    }

    # The hashtable scope-escape hack for pester
    $Result = @{ }

    It "FindModuleVersion limits the output of Get-Module" {
        Set-Content TestDrive:\RequiredModules.psd1 '@{
            "PowerShellGet"    = "1.0.0"
            "Configuration"    = "[1.0.0,2.0)"
            "ModuleBuilder"    = @{
                Version = "2.*"
                Repository = "https://www.powershellgallery.com/api/v2"
            }
        }'

        $Result["Output"] = InModuleScope RequiredModule { ImportRequiredModulesFile TestDrive:\RequiredModules.psd1 | GetModuleVersion }
    }

    # unstuffing the hack
    $Result = $Result["Output"]

    It "Returns a value for each module" {
        $Result.Name | Should -Contain "PowerShellGet"
        $Result.Name | Should -Contain "Configuration"
        $Result.Name | Should -Contain "ModuleBuilder"
    }

    It "Returns the highest version (3.5.0) for PowerShellGet = '1.0.0'" {
        $Required = $Result.Where{ $_.Name -eq "PowerShellGet" }
        $Required.Count | Should -Be 1
        $Required.Version | Should -Be "3.5.0"
    }

    It "Returns the highest below 2.0 (1.0.1) for Configuration = '[1.0.0,2.0)'" {
        $Required = $Result.Where{ $_.Name -eq "Configuration" }
        $Required.Count | Should -Be 1
        $Required.Version | Should -Be "1.0.1"
    }

    It "Returns the highest below 3.0 (2.2.4) for ModuleBuilder = '2.*'" {
        $Required = $Result.Where{ $_.Name -eq "ModuleBuilder" }
        $Required.Count | Should -Be 1
        $Required.Version | Should -Be "2.2.4"
    }

    It "Returns the first result (regardless of source) if the repository isn't specified" {
        $Required = $Result.Where{ $_.Name -eq "PowerShellGet" }
        $Required.RepositorySourceLocation | Should -Be "https://pkgs.dev.azure.com/poshcode/_packaging/PowerShell/nuget/v2"

        $Required = $Result.Where{ $_.Name -eq "Configuration" }
        $Required.RepositorySourceLocation | Should -Be "https://pkgs.dev.azure.com/poshcode/_packaging/PowerShell/nuget/v2"
    }

    It "Filters the result to a specific location when the repository is specified" {
        $Required = $Result.Where{ $_.Name -eq "ModuleBuilder" }
        $Required.RepositorySourceLocation | Should -Be "https://www.powershellgallery.com/api/v2"
    }

}