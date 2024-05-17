#requires -Module RequiredModules
using module RequiredModules
using namespace NuGet.Versioning

Describe "FindModuleVersion calls Find-Module and filters based on the VersionRange" {
    BeforeAll {
        $PreRegisteredRepositories = Get-PSRepository

        Register-PSRepository -Name "Trusted Fake Repo" -SourceLocation "https://www.myget.org/F/aspnetwebstacknightly/api/v2" -InstallationPolicy Trusted
        Register-PSRepository -Name "Untrusted Fake Repo" -SourceLocation "https://www.myget.org/F/fireeye/api/v2" -InstallationPolicy Untrusted
        Register-PSRepository -Default -InstallationPolicy Trusted 2>$null

        # This mock dumps a _ton_ of module info looking things for every query ....
        # Find-Module returns results HIGHEST to LOWEST (which is critical for our logic)
        Mock Find-Module -Module RequiredModules {
            $Versions = @('3.5.0', '3.4.5', '3.4.4', '3.4.3', '3.4.2', '3.4.1', '3.4.0', '3.3.0', '3.2.0', '3.1.1', '3.1.0', '3.0.2', '3.0.1', '3.0.0', '2.2.4', '2.2.3', '2.2.2', '2.2.1', '2.2.0', '2.1.3', '2.1.2', '2.1.1', '2.1.0', '2.0.1', '2.0.0', '1.2.0', '1.1.5', '1.1.4', '1.1.3', '1.1.2', '1.1.1', '1.1.0', '1.0.4', '1.0.3', '1.0.2', '1.0.1', '1.0.0')
            # Write-Host "Given a big list of module versions for ${Name}: $Versions"
            foreach ($Module in $Name) {
                foreach ($Repo in @(
                        [PSCustomObject]@{Name = "Untrusted Fake Repo"; SourceLocation = "https://www.myget.org/F/fireeye/api/v2" }
                        [PSCustomObject]@{Name = "Trusted Fake Repo"; SourceLocation = "https://www.myget.org/F/aspnetwebstacknightly/api/v2" }
                        [PSCustomObject]@{Name = "PSGallery"; SourceLocation = "https://www.powershellgallery.com/api/v2" }
                    ).Where{ -not $Repository -or $_.SourceLocation -in $Repository -or $_.Name -in $Repository }) {
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

        # The hashtable scope-escape hack for pester
        $Result = @{ }
    }

    It "FindModuleVersion limits the output of Find-Module" {
        Set-Content TestDrive:\RequiredModules.psd1 '@{
            "PowerShellGet" = "1.0.0"
            "Configuration" = "[1.0.0,2.0)"
            "ModuleBuilder" = @{
                Version    = "2.*"
                Repository = "https://www.powershellgallery.com/api/v2"
            }
            "PoshCode"      = @{
                Version    = "3.0.*"
                Repository = "https://www.myget.org/F/fireeye/api/v2"
            }
        }'

        $Result["Output"] = InModuleScope RequiredModules { ImportRequiredModulesFile TestDrive:\RequiredModules.psd1 | FindModuleVersion }

        # If this fails, I need the error to help me understand what broke
        if ($Result["Output"].Count -ne 4) {
            throw "$($Result["Output"].Length) Output (expected 4).`n$(($Result["Output"] | ForEach-Object { $_.GetType().FullName }) -join "`n" )"
        }
    }

    It "Returns a value for each module (in order)" {
        $Result["Output"].Name | Should -Be "PowerShellGet", "Configuration", "ModuleBuilder", "PoshCode"
    }

    It "Returns the highest version (3.5.0) for PowerShellGet = '1.0.0'" {
        $Required = $Result["Output"].Where{ $_.Name -eq "PowerShellGet" }
        $Required.Count | Should -Be 1
        $Required.Version | Should -Be "3.5.0"
    }

    It "Returns the highest below 2.0 (1.2.0) for Configuration = '[1.0.0,2.0)'" {
        $Required = $Result["Output"].Where{ $_.Name -eq "Configuration" }
        $Required.Count | Should -Be 1
        $Required.Version | Should -Be "1.2.0"
    }

    It "Returns the highest below 3.0 (2.2.4) for ModuleBuilder = '2.*'" {
        $Required = $Result["Output"].Where{ $_.Name -eq "ModuleBuilder" }
        $Required.Count | Should -Be 1
        $Required.Version | Should -Be "2.2.4"
    }

    It "Returns the highest below 3.1 (3.0.2) for PoshCode = '3.0.*'" {
        $Required = $Result["Output"].Where{ $_.Name -eq "PoshCode" }
        $Required.Count | Should -Be 1
        $Required.Version | Should -Be "3.0.2"
    }

    It "Returns the first trusted result if the repository isn't specified" {
        $Required = $Result["Output"].Where{ $_.Name -eq "PowerShellGet" }
        $Required.RepositorySourceLocation | Should -Be "https://www.myget.org/F/aspnetwebstacknightly/api/v2"

        $Required = $Result["Output"].Where{ $_.Name -eq "Configuration" }
        $Required.RepositorySourceLocation | Should -Be "https://www.myget.org/F/aspnetwebstacknightly/api/v2"
    }

    It "Filters the result to a specific location when the repository is specified" {
        $Required = $Result["Output"].Where{ $_.Name -eq "ModuleBuilder" }
        $Required.RepositorySourceLocation | Should -Be "https://www.powershellgallery.com/api/v2"
    }

    It "Returns the untrusted respository only when it's not available from a trusted repository" {
        $Required = $Result["Output"].Where{ $_.Name -eq "PoshCode" }
        $Required.RepositorySourceLocation | Should -Be "https://www.myget.org/F/fireeye/api/v2"
        # And it warns when that happens
        Assert-MockCalled Write-Warning -ParameterFilter {
            $Message -Match "'PoshCode' with version '3.0.2' found in untrusted repository"
        } -ModuleName RequiredModules -Scope Describe
    }

    Describe "When passing credentials" {

        It "Should pass through the credential" {
            $Required = InModuleScope RequiredModules {
                [RequiredModule[]]@((
                        @{
                            "Configuration" = @{
                                Version    = "[1.0.0,2.0)"
                                Repository = "https://www.myget.org/F/aspnetwebstacknightly/api/v2"
                                Credential = [PSCredential]::new("UserName", (ConvertTo-SecureString "Password" -AsPlainText -Force))
                            }
                        }
                    ).GetEnumerator()) | FindModuleVersion
            }

            $Required.Credential | Should -Not -BeNullOrEmpty
            $Required.Credential.UserName | Should -Be "UserName"
            $Required.Credential.GetNetworkCredential().Password | Should -Be "Password"
        }
    }

    Describe "Upgrade support" {
        It "Warns when there is a newer version when -WarnIfNewer is set" {
            [RequiredModule[]]@((
                        @{
                            "PhauxModule" = @{
                                Version    = "[1.0.0,2.0)"
                            }
                            "Unrestricted" = @{
                                Version    = "3.0.0"
                            }
                        }
                    ).GetEnumerator())
            $Required = InModuleScope RequiredModules {
                [RequiredModule]::new("PhauxModule", "[1.0.0,2.0)") | FindModuleVersion -WarnIfNewer
            }

            $Required.Name | Should -Be "PhauxModule"
            $Required.Version | Should -Be "1.2.0"

            # Write-Warning is only called this one time
            Assert-MockCalled Write-Warning -ModuleName RequiredModules -Scope Describe -Times 1 -Exactly
            Assert-MockCalled Write-Warning -ModuleName RequiredModules -Scope Describe -ParameterFilter {
                $Message -eq "Newer version of 'PhauxModule' available: 3.5.0 -- Selected 1.2.0 per constraint '[1.0.0, 2.0.0)'"
            }
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
    }
}