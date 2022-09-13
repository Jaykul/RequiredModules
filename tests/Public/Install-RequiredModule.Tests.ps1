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

        $PreRegisteredRepositories = Get-PSRepository
        Register-PSRepository -Name "Untrusted Fake Repo" -SourceLocation "https://www.myget.org/F/fireeye/api/v2" -InstallationPolicy Untrusted
        Register-PSRepository -Default -InstallationPolicy Trusted 2>$null


        # We'll test FindModuleVersion's logic
        Mock Find-Module -Module RequiredModules {
            $Versions = @('3.5.0', '3.4.5', '3.4.4', '3.4.3', '3.4.2', '3.4.1', '3.4.0', '3.3.0', '3.2.0', '3.1.1', '3.1.0', '3.0.2', '3.0.1', '3.0.0', '2.2.4', '2.2.3', '2.2.2', '2.2.1', '2.2.0', '2.1.3', '2.1.2', '2.1.1', '2.1.0', '2.0.1', '2.0.0', '1.2.0', '1.1.5', '1.1.4', '1.1.3', '1.1.2', '1.1.1', '1.1.0', '1.0.4', '1.0.3', '1.0.2', '1.0.1', '1.0.0')
            foreach ($Module in $Name) {
                $Repos = @(
                        [PSCustomObject]@{Name = "PSGallery"; SourceLocation = "https://www.powershellgallery.com/api/v2" }
                        [PSCustomObject]@{Name = "Untrusted Fake Repo"; SourceLocation = "https://www.myget.org/F/fireeye/api/v2" }
                    ).Where{ -not $Repository -or $_.SourceLocation -in $Repository -or $_.Name -in $Repository }

                if (!$Repos) {
                    $Repos = @(
                        @{
                            Name = $Repository
                            SourceLocation = $Repository
                        }
                    )
                }

                foreach ($Repo in $Repos) {
                    foreach ($Version in $Versions) {
                        [PSCustomObject]@{
                            PSTypeName               = "Microsoft.PowerShell.Commands.PSRepositoryItemInfo"
                            Name                     = $Module
                            Version                  = $Version
                            Repository               = $Repo.Name
                            RepositorySourceLocation = $Repo.SourceLocation
                        }
                    }
                }
            }
        }

        Mock Write-Warning -Module RequiredModules
        Mock Install-Module { } -ModuleName RequiredModules
        Mock Save-Module { } -ModuleName RequiredModules
        Mock AddPSModulePath { } -ModuleName RequiredModules
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

            Install-RequiredModule -ErrorAction Stop -Quiet

            Assert-MockCalled ConvertToRequiredModule -ModuleName RequiredModules -ParameterFilter {
                $InputObject.Count | Should -Be 1
                $InputObject["PowerShellGet"] | Should -Be '1.0.0'
                $true
            }
        }

        It "Warns but tries to install from untrusted repositories" {
            Set-Content TestDrive:\RequiredModules.psd1 "@{
                PowerShellGet = @{
                    Version    = '1.0.0'
                    Repository = 'Untrusted Fake Repo'
                }
            }"

            Install-RequiredModule -ErrorAction Stop -Quiet

            Assert-MockCalled Write-Warning -ModuleName RequiredModules -ParameterFilter {
                $Message -Match "Dependency 'PowerShellGet' with version '3.5.0' found in untrusted repository 'Untrusted Fake Repo'.*"
            }

            Assert-MockCalled Install-Module -ModuleName RequiredModules -ParameterFilter {
                $Name | Should -Be "PowerShellGet"
                $Repository | Should -Be 'Untrusted Fake Repo'
                $true
            }
        }

        It "Supports trusting all registered repositories" {
            Set-Content TestDrive:\RequiredModules.psd1 "@{
                PowerShellGet = @{
                    Version    = '1.0.0'
                    Repository = 'Untrusted Fake Repo'
                }
            }"

            Install-RequiredModule -ErrorAction Stop -Quiet -TrustRegisteredRepositories

            Assert-MockCalled Install-Module -ModuleName RequiredModules -ParameterFilter {
                $Name | Should -Be "PowerShellGet"
                $Repository | Should -Be 'Untrusted Fake Repo'
                $true
            }
        }

        It "Warns but tries to install from unknown repositories" {
            Set-Content TestDrive:\RequiredModules.psd1 "@{
                PowerShellGet = @{
                    Version    = '1.0.0'
                    Repository = 'https://pkgs.dev.azure.com/poshcode/_packaging/PowerShell/nuget/v2'
                }
            }"

            Install-RequiredModule -ErrorAction Stop -Quiet

            Assert-MockCalled Write-Warning -ModuleName RequiredModules -ParameterFilter {
                $Message -Match "Dependency 'PowerShellGet' with version '3.5.0' found in untrusted repository.*"
            }

            Assert-MockCalled Install-Module -ModuleName RequiredModules -ParameterFilter {
                $Name | Should -Be "PowerShellGet"
                $true
            }
        }
    }

    Describe "But it also accepts a hashtable inline" {
        It "Will install all modules, but hashtables are not necessarily ordered" {
            $Modules = @{
                "PowerShellGet"    = "2.0.4"
                "Configuration"    = "[1.0.1,2.0)"
                "Pester"           = "*"
                "PSScriptAnalyzer" = @{
                    Repository = "https://www.myget.org/F/fireeye/api/v2"
                    Version    = "1.*"
                }
            }

            Install-RequiredModule $Modules -Quiet

            foreach($M in $Modules.Keys) {
                Assert-MockCalled Install-Module -ModuleName RequiredModules -ParameterFilter {
                    $Name -eq $M
                }
            }

            Assert-MockCalled Write-Warning -ParameterFilter {
                $Message -Match "'PSScriptAnalyzer' with version '1.2.0' found in untrusted repository"
            } -ModuleName RequiredModules -Scope It
        }

        It "Supports installing into any file path" {
            Install-RequiredModule @{ "PowerShellGet" = "1.0.0" } -Quiet -Destination TestDrive:\

            Assert-MockCalled AddPSModulePath -Module RequiredModules -ParameterFilter {
                $Path -eq "TestDrive:\"
            }

            Assert-MockCalled Save-Module -Module RequiredModules -ParameterFilter {
                $Path -eq "TestDrive:\"
            }
        }
    }
    Describe "Upgrade support" {
        BeforeAll {
            # Find would return a bunch of versions, including a newer one than what's installed
            Mock Find-Module -Module RequiredModules {
                $Versions = '3.0.0', '2.2.0', '2.1.3', '2.1.2', '2.1.1', '2.1.0', '2.0.0', '1.0.0'
                foreach ($Module in $Name) {
                    foreach ($Version in $Versions) {
                        [PSCustomObject]@{
                            PSTypeName               = "Microsoft.PowerShell.Commands.PSRepositoryItemInfo"
                            Name                     = $Module
                            Version                  = $Version
                            Repository               = "PSGallery"
                            RepositorySourceLocation = "https://www.powershellgallery.com/api/v2"
                        }
                    }
                }
            }

            # But get will find a valid one already installed
            Mock GetModuleVersion -Module RequiredModules {
                foreach ($Module in $Name) {
                    [PSCustomObject]@{
                        PSTypeName               = "Microsoft.PowerShell.Commands.PSRepositoryItemInfo"
                        Name                     = $Module
                        Version                  = '2.2.0'
                        Repository               = "PSGallery"
                        RepositorySourceLocation = "https://www.powershellgallery.com/api/v2"
                    }
                    Write-Verbose "Found '$Name' hard-coded with version '2.2.0'"
                }
            }
        }

        It "Normally checks GetModuleVersion before FindModuleVersion" {
            Install-RequiredModule @{ "PowerShellGet" = "[2.0,4.0)" } -Destination TestDrive:\

            # GetModuleVersion should be called to search for the full range of valid versions
            Assert-MockCalled GetModuleVersion -ModuleName RequiredModules -ParameterFilter {
                $Name -eq "PowerShellGet" -and "[2.0.0, 4.0.0)" -eq $Version
            }

            # Since it finds it already installed, it should not call Find-Module or Save-Module (or Install-Module)
            Assert-MockCalled Find-Module -ModuleName RequiredModules -Times 0 -Scope It
            Assert-MockCalled Install-Module -ModuleName RequiredModules -Times 0 -Scope It
            Assert-MockCalled Save-Module -ModuleName RequiredModules -Times 0 -Scope It
        }

        It "Checks GetModuleVersion after FindModuleVersion when -Upgrade" {
            Install-RequiredModule @{ "PowerShellGet" = "[2.0,4.0)" } -Upgrade -Quiet -Destination TestDrive:\

            # Find-Module gets called first, and returns 3.0.0 as the latest version ...
            Assert-MockCalled Find-Module -ModuleName RequiredModules -ParameterFilter {
                $Name -eq "PowerShellGet" -and
                $AllVersions -eq $true
            } -Times 1 -Scope It

            # GetModuleVersion is only called (afterward), to check if that specific version is installed
            Assert-MockCalled GetModuleVersion -ModuleName RequiredModules -ParameterFilter {
                $Name -eq "PowerShellGet" -and "[3.0.0, 3.0.0]" -eq $Version
            }

            # And of course, we install it with Save-Module (because -Destination is specified)
            Assert-MockCalled Save-Module -ModuleName RequiredModules -Times 1 -Scope It
            Assert-MockCalled Install-Module -ModuleName RequiredModules -Times 0 -Scope It
        }
    }
    AfterAll {
        foreach ($r in Get-PSRepository) {
            if ($r.Name -notin @($PreRegisteredRepositories.Name)) {
                Unregister-PSRepository -Name $r.Name
            } else {
                Set-PSRepository -Name $r.Name -InstallationPolicy $r.InstallationPolicy
            }
        }
        Pop-Location
    }
}