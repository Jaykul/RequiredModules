#requires -Module RequiredModules
using module RequiredModules
using namespace NuGet.Versioning

Describe "InstallModuleVersion calls Save or Install-Module with -RequiredVersion" {

    Mock Install-Module -Module RequiredModules { }
    Mock Save-Module -Module RequiredModules { }
    Mock GetModuleVersion -Module RequiredModules { $true }

    Describe "Unrestricted module install" {
        It "InstallModuleVersion accepts module name and version" {
            InModuleScope RequiredModules {
                InstallModuleVersion -Name ModuleBuilder -Version 1.3.0
            }
        }

        It "Calls install-Module with the Name and RequiredVersion" {
            Assert-MockCalled Install-Module -Module RequiredModules -Parameter {
                $Name -eq "ModuleBuilder"
                $RequiredVersion -eq "1.3.0"
            }
        }
    }

    Describe "Repository-qualified module install" {

        It "InstallModuleVersion accepts respository as well" {
            # Note we test pipeline binding here with an object shaped like the output of Find-Module:
            InModuleScope RequiredModules {
                @(
                    [PSCustomObject]@{
                        PSTypeName = "PSModuleInfo"
                        Name       = "ModuleBuilder"
                        Version    = "1.3.0"
                        # This should bind to the "Repository" parameter
                        RepositorySourceLocation = "https://www.powershellgallery.com/api/v2"
                        #[PSCredential]$Credential
                    }
                ) | InstallModuleVersion
            }
        }

        It "Calls install-Module with the Repository" {
            Assert-MockCalled Install-Module -Module RequiredModules -Parameter {
                $Name -eq "ModuleBuilder" -and
                $RequiredVersion -eq "1.3.0" -and
                $Repository -eq "https://www.powershellgallery.com/api/v2"
            }
        }
    }

    Describe "Repository-qualified install with credentials" {

        It "InstallModuleVersion accepts repository as well" {
            # Note we test pipeline binding here with an object shaped like the output of Find-Module:
            InModuleScope RequiredModules {
                @(
                    [PSCustomObject]@{
                        PSTypeName = "PSModuleInfo"
                        Name       = "ModuleBuilder"
                        Version    = "1.3.0"
                        # This should also bind to the "Repository" parameter
                        Repository = "https://www.powershellgallery.com/api/v2"
                        Credential = [PSCredential]::new("UserName", (ConvertTo-SecureString "Password" -AsPlainText -Force))
                    }
                ) | InstallModuleVersion
            }
        }

        It "Calls install-Module with the Repository and Credential" {
            Assert-MockCalled Install-Module -Module RequiredModules -Parameter {
                $Name -eq "ModuleBuilder" -and
                $RequiredVersion -eq "1.3.0" -and
                $Repository -eq "https://www.powershellgallery.com/api/v2" -and
                $Credential.UserName -eq "UserName" -and
                $Credential.GetNetworkCredential().Password -eq "Password"
            }
        }
    }
}