#requires -Module RequiredModules, PowerShellGet
# using module RequiredModules
using namespace NuGet.Versioning

Describe "Optimize-Dependency" {
    BeforeAll {
        $TestModules = @{
            # Create a dependency order that's the opposite of alphabetical
            E = [PSCustomObject]@{ Name = "E"; Version = "1.0"; Dependencies = @() }
            D = [PSCustomObject]@{ Name = "D"; Version = "1.0"; Dependencies = @() }
            C = [PSCustomObject]@{ Name = "C"; Version = "1.0"; Dependencies = @(@{Name = "E"}) }
            B = [PSCustomObject]@{ Name = "B"; Version = "1.0"; Dependencies = @(@{Name = "D"}, @{Name = "C"}) }
            A = [PSCustomObject]@{ Name = "A"; Version = "1.0"; Dependencies = @(@{Name = "E"}, @{Name = "B"}) }
            # Set up XYZ for a circular dependency
            Z = [PSCustomObject]@{ PSTypeName = "System.Management.Automation.PSModuleInfo"; Name = "Z"; Version = "1.0"; RequiredModules = @() }
            Y = [PSCustomObject]@{ PSTypeName = "System.Management.Automation.PSModuleInfo"; Name = "Y"; Version = "1.0"; RequiredModules = @(@{Name = "Z"}) }
            X = [PSCustomObject]@{ PSTypeName = "System.Management.Automation.PSModuleInfo"; Name = "X"; Version = "1.0"; RequiredModules = @(@{Name = "Y"}) }
        }
        # Create a circular dependency
        $TestModules["Z"].RequiredModules = @($TestModules["X"])

        Mock Get-Module {
            $TestModules[$Name]
        } -ModuleName RequiredModules

        Mock Find-Module {
            $TestModules[$Name]
        } -ModuleName RequiredModules
    }

    It "Recursively discovers depedencies" {
        # Create a dependency order that's the opposite of alphabetical
        # Pass them in alphabetical order:
        $Results = Optimize-Dependency -InputObject $TestModules['A']

        $Results.Name | Should -Be "E", "D", "C", "B", "A"
    }

    It "Sorts lists into dependency order" {
        # Create a dependency order that's the opposite of alphabetical
        # Pass them in alphabetical order:
        $Results = Optimize-Dependency -InputObject $TestModules['A', 'B', 'C', 'D', 'E']

        $Results.Name | Should -Be "E", "D", "C", "B", "A"
    }

    It "Handles circular dependencies without dying" {
        Mock Write-Warning -ModuleName RequiredModules
        # Pass them in alphabetical order:
        $Results = Optimize-Dependency -InputObject $TestModules['X']

        # There's not actually a single winning order when there's a circular reference ...
        # But the expectation is that it should get output in the order we discovered them
        $Results.Name | Should -Be "Z", "Y", "X"

        Assert-MockCalled Write-Warning -ModuleName RequiredModules
    }

    Context "Using RequiredModules Files" {
        BeforeAll {
            $PreRegisteredRepositories = Get-PSRepository

            Register-PSRepository -Name "Trusted Fake Repo" -SourceLocation "https://www.myget.org/F/aspnetwebstacknightly/api/v2" -InstallationPolicy Trusted
            Register-PSRepository -Default -InstallationPolicy Trusted 2>$null

            # This mock dumps a _ton_ of module info looking things for every query ....
            # Find-Module returns results HIGHEST to LOWEST (which is critical for our logic)
            Mock Find-Module -Module RequiredModules {
                $Versions = @('3.5.0', '3.4.5', '3.4.4', '3.4.3', '3.4.2', '3.4.1', '3.4.0', '3.3.0', '3.2.0', '3.1.1', '3.1.0', '3.0.2', '3.0.1', '3.0.0', '2.2.4', '2.2.3', '2.2.2', '2.2.1', '2.2.0', '2.1.3', '2.1.2', '2.1.1', '2.1.0', '2.0.1', '2.0.0', '1.2.0', '1.1.5', '1.1.4', '1.1.3', '1.1.2', '1.1.1', '1.1.0', '1.0.4', '1.0.3', '1.0.2', '1.0.1', '1.0.0')
                # Write-Host "Given a big list of module versions for ${Name}: $Versions"
                foreach ($Module in $Name) {
                    foreach ($Repo in @(
                            [PSCustomObject]@{Name = "Trusted Fake Repo"; SourceLocation = "https://www.myget.org/F/aspnetwebstacknightly/api/v2" }
                            [PSCustomObject]@{Name = "PSGallery"; SourceLocation = "https://www.powershellgallery.com/api/v2" }
                        ).Where{ -not $Repository -or $_.SourceLocation -in $Repository -or $_.Name -in $Repository } | Get-Random) {
                        foreach ($Version in $Versions[$(if($AllVersions){ 0..$($Versions.Count) } else { 0 })]) {
                            [PSCustomObject]@{
                                PSTypeName               = "Microsoft.PowerShell.Commands.PSRepositoryItemInfo"
                                Name                     = $Module
                                Version                  = $Version
                                Repository               = $Repo.Name
                                RepositorySourceLocation = $Repo.SourceLocation
                                Dependencies             = @(
                                    switch ($Name) {
                                        "Configuration" {
                                            @{ Name = "Metadata" }
                                        }
                                        "ModuleBuilder" {
                                            @{ Name = "Configuration" }
                                            @{ Name = "Metadata" }
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
            }

            Set-Content TestDrive:\RequiredModules.psd1 '@{
                "ModuleBuilder"    = @{
                    Version    = "1.*"
                    Repository = "https://www.powershellgallery.com/api/v2"
                }
                "PowerShellGet"    = "2.0.4"
                "Configuration"    = "[3.0,4.0)"
                "Pester"           = "*"
                "PSScriptAnalyzer" = "1.*"
            }'
        }

        It "Works from metadata files" {
            $Results = Optimize-Dependency -Path TestDrive:\RequiredModules.psd1
            $Results.Name | Should -Be "Metadata", "Configuration", "ModuleBuilder", "PowerShellGet", "Pester", "PSScriptAnalyzer"
        }

        AfterAll {
            foreach ($r in Get-PSRepository) {
                if ($r.Name -notin @($PreRegisteredRepositories.Name)) {
                    Unregister-PSRepository -Name $r.Name
                } else {
                    Set-PSRepository -Name $r.Name -InstallationPolicy $r.InstallationPolicy
                }
            }
        }
    }
}