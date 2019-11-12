#requires -Module RequiredModule
using module RequiredModule
using namespace NuGet.Versioning

Describe "FindModuleVersion calls Find-Module and filters based on the VersionRange" {

    # This mock dumps a _ton_ of module info looking things for every query ....
    # Find-MOoule returns results HIGHEST to LOWEST (which is critical for our logic)
    Mock Find-Module -Module RequiredModule {
        $Versions = @('3.5.0', '3.4.5', '3.4.4', '3.4.3', '3.4.2', '3.4.1', '3.4.0', '3.3.0', '3.2.0', '3.1.1', '3.1.0', '3.0.2', '3.0.1', '3.0.0', '2.2.4', '2.2.3', '2.2.2', '2.2.1', '2.2.0', '2.1.3', '2.1.2', '2.1.1', '2.1.0', '2.0.1', '2.0.0', '1.2.0', '1.1.5', '1.1.4', '1.1.3', '1.1.2', '1.1.1', '1.1.0', '1.0.4', '1.0.3', '1.0.2', '1.0.1', '1.0.0')
        Write-Host "Given a big list of module versions for ${Name}: $Versions"
        Write-Host "Search for $Name in $Repository"
        foreach($Module in $Name) {
            foreach($Repo in @( "https://pkgs.dev.azure.com/poshcode/_packaging/PowerShell/nuget/v2"
                                "https://www.powershellgallery.com/api/v2" ).Where{ -not $Repository -or $_ -in $Repository }) {
                foreach ($Version in $Versions) {
                    [PSCustomObject]@{
                        PSTypeName = "Microsoft.PowerShell.Commands.PSRepositoryItemInfo"
                        Name                     = $Module
                        Version                  = $Version
                        RepositorySourceLocation = $Repo
                    }
                }
            }
        }
    }

    # The hashtable scope-escape hack for pester
    $Result = @{ }

    It "FindModuleVersion limits the output of Find-Module" {
        Set-Content TestDrive:\RequiredModules.psd1 '@{
            "PowerShellGet"    = "1.0.0"
            "Configuration"    = "[1.0.0,2.0)"
            "ModuleBuilder"    = @{
                Version = "2.*"
                Repository = "https://www.powershellgallery.com/api/v2"
            }
        }'

        $Result["Output"] = InModuleScope RequiredModule { ImportRequiredModulesFile TestDrive:\RequiredModules.psd1 | FindModuleVersion }
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

    It "Returns the highest below 2.0 (1.2.0) for Configuration = '[1.0.0,2.0)'" {
        $Required = $Result.Where{ $_.Name -eq "Configuration" }
        $Required.Count | Should -Be 1
        $Required.Version | Should -Be "1.2.0"
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