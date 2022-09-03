#requires -Module RequiredModules
using module RequiredModules
using namespace NuGet.Versioning

Describe "ImportRequiredModulesFile reads metadata files" {

    BeforeAll {
        # The hashtable scope-escape hack for pester
        $Result = @{}
    }

    It "Parses all sorts of data" {
        Set-Content TestDrive:\RequiredModules.psd1 '@{
            "PowerShellGet"    = "2.0.4"
            "Configuration"    = "[1.3.1,2.0)"
            "Pester"           = "*"
            "PSScriptAnalyzer" = "1.*"
            "ModuleBuilder"    = @{
                Version    = "1.*"
                Repository = "https://www.powershellgallery.com/api/v2"
            }
        }'

        $Result["Output"] = InModuleScope RequiredModules { ImportRequiredModulesFile TestDrive:\RequiredModules.psd1 }
    }

    It "Produces a result for each key in the metadata file" {
        $Result["Output"].Count | Should -Be 5
    }

    It "Gets a [RequiredModule] for each key in the metadata file" {
        $Output = $Result["Output"]

        $Output.ForEach{ $_ | Should -BeOfType ([RequiredModule]) }
        $Output.Name | Should -Contain "PowerShellGet"
        $Output.Name | Should -Contain "Configuration"
        $Output.Name | Should -Contain "Pester"
        $Output.Name | Should -Contain "PSScriptAnalyzer"
        $Output.Name | Should -Contain "ModuleBuilder"
    }

    It "Parses a simple '2.0.4' as a minimum version" {
        $Required = $Result["Output"].Where{ $_.Name -eq "PowerShellGet"}
        $Required.Version.MinVersion | Should -Be "2.0.4"
        $Required.Version.MaxVersion | Should -BeNullOrEmpty
    }

    It "Parses a range [1.3.1,2.0) as the inclusive minimum and exclusive maximum" {
        $Required = $Result["Output"].Where{ $_.Name -eq "Configuration"}

        $Required.Version.MinVersion | Should -Be "1.3.1"
        $Required.Version.IsMinInclusive | Should -Be $true

        $Required.Version.MaxVersion | Should -Be "2.0"
        $Required.Version.IsMaxInclusive | Should -Be $false
    }

    It "Parses a wildcard as unspecified minimum and maximum" {
        $Required = $Result["Output"].Where{ $_.Name -eq "Pester" }
        $Required.Version.MaxVersion | Should -BeNullOrEmpty
        # In the latest version:
        if ($Required.Version.HasLowerBound) {
            #   on .NET 6, * comes out with MinVersion: 0.0.0
            $Required.Version.MinVersion | Should -Be "0.0.0"
        } else {
            #   on .NET 4, * comes out with MinVersion: null
            $Required.Version.MinVersion | Should -BeNullOrEmpty
        }
    }

    It "Parses a partial wildcard '1.*' as a min inclusive [1.0,)" {
        $Required = $Result["Output"].Where{ $_.Name -eq "PSScriptAnalyzer" }

        $Required.Credential | Should -BeNullOrEmpty
        $Required.Version.MinVersion | Should -Be "1.0"
        $Required.Version.IsMinInclusive | Should -Be $true

        $Required.Version.MaxVersion | Should -BeNullOrEmpty
        $Required.Version.IsMaxInclusive | Should -Be $false
    }

    It "Handles a detailed syntax that includes a Repository URL" {
        $Required = $Result["Output"].Where{ $_.Name -eq "ModuleBuilder" }

        $Required.Credential | Should -BeNullOrEmpty
        $Required.Version.MinVersion | Should -Be "1.0"
        $Required.Version.IsMinInclusive | Should -Be $true

        $Required.Version.MaxVersion | Should -BeNullOrEmpty
        $Required.Version.IsMaxInclusive | Should -Be $false

        $Required.Repository | Should -Be "https://www.powershellgallery.com/api/v2"
    }
}