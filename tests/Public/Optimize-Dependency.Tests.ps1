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
}