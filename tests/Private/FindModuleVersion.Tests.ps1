#requires -Module RequiredModules
using module RequiredModules
using namespace NuGet.Versioning

Describe "FindModuleVersion calls Find-Module and filters based on the VersionRange" {
    $PreRegisteredRepositories = @()
    $Warns = @()

    BeforeAll {
        Write-Host "PreRegisteredRepositories:" -Foreground Green
        Get-PSRepository -OutVariable +PreRegisteredRepositories | Out-String -Stream | Write-Host -Foreground Green

        Register-PSRepository -Name FindModuleTestFake -SourceLocation "https://www.myget.org/F/aspnetwebstacknightly/api/v2" -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Register-PSRepository -Default -InstallationPolicy Trusted -ErrorAction SilentlyContinue

        Write-Host "RegisteredRepositoriesIncludingTest:" -Foreground Cyan
        Get-PSRepository | Out-String -Stream | Write-Host -Foreground Cyan
    }

    # This mock dumps a _ton_ of module info looking things for every query ....
    # Find-Module returns results HIGHEST to LOWEST (which is critical for our logic)
    Mock Find-Module -Module RequiredModules {
        $Versions = @('3.5.0', '3.4.5', '3.4.4', '3.4.3', '3.4.2', '3.4.1', '3.4.0', '3.3.0', '3.2.0', '3.1.1', '3.1.0', '3.0.2', '3.0.1', '3.0.0', '2.2.4', '2.2.3', '2.2.2', '2.2.1', '2.2.0', '2.1.3', '2.1.2', '2.1.1', '2.1.0', '2.0.1', '2.0.0', '1.2.0', '1.1.5', '1.1.4', '1.1.3', '1.1.2', '1.1.1', '1.1.0', '1.0.4', '1.0.3', '1.0.2', '1.0.1', '1.0.0')
        # Write-Host "Given a big list of module versions for ${Name}: $Versions"
        # Write-Host "Search for $Name in $Repository"
        foreach($Module in $Name) {
            foreach($Repo in @(
                [PSCustomObject]@{Name = "SomeUntrustedRepo"; SourceLocation = "https://poshcode.org/api/psget2/"}
                [PSCustomObject]@{Name = "FindModuleTestFake"; SourceLocation = "https://www.myget.org/F/aspnetwebstacknightly/api/v2"}
                [PSCustomObject]@{Name = "PSGallery"; SourceLocation = "https://www.powershellgallery.com/api/v2"}
                ).Where{ -not $Repository -or $_.SourceLocation -in $Repository }) {
                foreach ($Version in $Versions) {
                    [PSCustomObject]@{
                        PSTypeName = "Microsoft.PowerShell.Commands.PSRepositoryItemInfo"
                        Name                     = $Module
                        Version                  = $Version
                        Repository               = $Repo.Name
                        RepositorySourceLocation = $Repo.SourceLocation
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
            "PoshCode"         = @{
                Version = "3.0.*"
                Repository = "https://poshcode.org/api/psget2/"
            }
        }'

        $Result["Output"] = InModuleScope RequiredModules { ImportRequiredModulesFile TestDrive:\RequiredModules.psd1 | FindModuleVersion -Verbose } -WarningVariable Warnings
        $Result["Warnings"] = $Warnings
        $Result["Output"].Count | Should -Be 4
    }

    # unstuffing the hack
    $Warns = $Result["Warnings"]
    $Result = $Result["Output"]

    It "Returns a value for each module" {
        $Result.Name | Should -Contain "PowerShellGet"
        $Result.Name | Should -Contain "Configuration"
        $Result.Name | Should -Contain "ModuleBuilder"
        $Result.Name | Should -Contain "PoshCode"
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

    It "Returns the first trusted result if the repository isn't specified" {
        $Required = $Result.Where{ $_.Name -eq "PowerShellGet" }
        $Required.RepositorySourceLocation | Should -Be "https://www.myget.org/F/aspnetwebstacknightly/api/v2"

        $Required = $Result.Where{ $_.Name -eq "Configuration" }
        $Required.RepositorySourceLocation | Should -Be "https://www.myget.org/F/aspnetwebstacknightly/api/v2"
    }

    It "Filters the result to a specific location when the repository is specified" {
        $Required = $Result.Where{ $_.Name -eq "ModuleBuilder" }
        $Required.RepositorySourceLocation | Should -Be "https://www.powershellgallery.com/api/v2"
    }

    It "Returns the untrusted respository only when it's not available from a trusted repository" {
        $Required = $Result.Where{ $_.Name -eq "PoshCode" }
        $Required.RepositorySourceLocation | Should -Be "https://poshcode.org/api/psget2/"
        # And it warns when that happens
        $Warns -match "'PoshCode'" | Should -Match "untrusted repository"
    }
    Describe "When passing credentials" {

        It "Should pass through the credential" {
            $Required = InModuleScope RequiredModules {
                [RequiredModule[]]@((
                    @{ "Configuration" = @{
                        Version = "[1.0.0,2.0)"
                        Repository = "https://www.myget.org/F/aspnetwebstacknightly/api/v2"
                        Credential = [PSCredential]::new("UserName", (ConvertTo-SecureString "Password" -AsPlainText -Force))
                    }}
                ).GetEnumerator()) | FindModuleVersion
            }

            $Required.Credential | Should -Not -BeNullOrEmpty
            $Required.Credential.UserName | Should -Be "UserName"
            $Required.Credential.GetNetworkCredential().Password | Should -Be "Password"
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

        Write-Host "PostTest Remaining RegisteredRepositories:" -Foreground Green
        Get-PSRepository | Out-String -Stream | Write-Host -Foreground Green
    }
}