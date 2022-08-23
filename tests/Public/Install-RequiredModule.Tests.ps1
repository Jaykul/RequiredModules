#requires -Module RequiredModules, PowerShellGet
using module RequiredModules
using namespace NuGet.Versioning

Describe "Install-RequiredModule" {
    BeforeAll {
        Push-Location TestDrive:\

        Mock ConvertToRequiredModule {
            process {
                $InputObject.GetEnumerator().ForEach([RequiredModule])
            }
        } -ModuleName RequiredModules

        # We'll test FindModuleVersion's logic
        Mock Find-Module {
            $Versions = @('3.5.0', '3.4.5', '3.4.4', '3.4.3', '3.4.2', '3.4.1', '3.4.0', '3.3.0', '3.2.0', '3.1.1', '3.1.0', '3.0.2', '3.0.1', '3.0.0', '2.2.4', '2.2.3', '2.2.2', '2.2.1', '2.2.0', '2.1.3', '2.1.2', '2.1.1', '2.1.0', '2.0.1', '2.0.0', '1.2.0', '1.1.5', '1.1.4', '1.1.3', '1.1.2', '1.1.1', '1.1.0', '1.0.4', '1.0.3', '1.0.2', '1.0.1', '1.0.0')
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
        } -ModuleName RequiredModules

        Mock Install-Module { } -ModuleName RequiredModules
        Mock Save-Module { } -ModuleName RequiredModules
        Mock GetModuleVersion { (Get-PSCallStack) -match "InstallModuleVersion" } -ModuleName RequiredModules

    }

    Describe "When called without parameters, requires a RequiredModules.psd1 in the working directory" {
        It "Errors if RequiredModules.psd1 does not exist" {
            {
                Install-RequiredModule -ErrorAction Stop
            } | Should -Throw "RequiredModules file 'RequiredModules.psd1' not found."
        }

        It "Reads RequiredModules.psd1 if it does exist" {

            Set-Content TestDrive:\RequiredModules.psd1 "@{ PowerShellGet = '1.0.0' }"

            {
                Install-RequiredModule -ErrorAction Stop
            } | Should -Not -Throw

            Assert-MockCalled ConvertToRequiredModule -ModuleName RequiredModules -ParameterFilter {
                $InputObject.Count | Should -Be 1
                $InputObject["PowerShellGet"] | Should -Be '1.0.0'
                $true
            }
        }
    }


    Describe "But it also accepts a hashtable inline" {
        Install-RequiredModule @{
            "PowerShellGet"    = "2.0.4"
            "Configuration"    = "[1.2.1,2.0)"
            "Pester"           = "*"
            "PSScriptAnalyzer" = "1.*"
            "SitecoreDockerTools"    = @{
                Version = "10.*"
                Repository = "https://sitecore.myget.org/F/sc-powershell/api/v2"
                Credential = [PSCredential]::Empty
            }
        }
    }

    AfterAll {
        Pop-Location
    }
}