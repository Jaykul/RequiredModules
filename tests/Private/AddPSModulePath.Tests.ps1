#requires -Module RequiredModules
using module RequiredModules
using namespace NuGet.Versioning

Describe "AddPSModulePath ensures the path is a folder and adds it to the current PSModulePath" {

    Push-Location TestDrive:\
    $BeforePSModulePath = $Env:PSModulePath
    BeforeEach {
        $Env:PSModulePath = $BeforePSModulePath
    }

    It "Creates missing folders" {
        # just to make sure it's not already there
        "TestDrive:\One" | Should -Not -Exist

        InModuleScope RequiredModules {
            AddPSModulePath TestDrive:\One
        }

        "TestDrive:\One" | Should -Exist
    }

    It "Adds folders to (the front of) PSModulePath" {
        # just to make sure it's not already there
        $Env:PSModulePath.Split([IO.Path]::PathSeparator) -eq (Convert-Path "TestDrive:\One") | Should -BeNullOrEmpty

        InModuleScope RequiredModules {
            AddPSModulePath TestDrive:\One
        }

        $Env:PSModulePath.Split([IO.Path]::PathSeparator)[0] | Should -Be (Convert-Path "TestDrive:\One")
    }


    It "Handles existing empty folders without error" {

        "TestDrive:\One" | Should -Exist

        InModuleScope RequiredModules {
            AddPSModulePath TestDrive:\One
        }

        "TestDrive:\One" | Should -Exist
    }

    It "Handles existing empty folders without warning or error" {

        "TestDrive:\One" | Should -Exist

        InModuleScope RequiredModules {
            AddPSModulePath TestDrive:\One -WarningVariable warned -ErrorVariable failed
            $warned | Should -BeNullOrEmpty
            $failed | Should -BeNullOrEmpty
        }

        "TestDrive:\One" | Should -Exist
    }

    It "Warns if an existing folder has content" {

        New-Item "TestDrive:\One\FileOne" -ItemType File -Value "Hello World"

        InModuleScope RequiredModules {
            AddPSModulePath TestDrive:\One -WarningVariable warned -WarningAction SilentlyContinue -ErrorVariable failed
            $warned | Should -Match "The folder .* is not empty"
            $warned | Should -Not -Match "removing all content"
            $failed | Should -BeNullOrEmpty
        }

        "TestDrive:\One" | Should -Exist
    }


    It "Supports -Clean to remove existing content" {

        New-Item "TestDrive:\One\FileTwo" -ItemType File -Value "Hello World"

        InModuleScope RequiredModules {
            AddPSModulePath TestDrive:\One -Clean -WarningVariable warned -WarningAction SilentlyContinue -ErrorVariable failed
            $warned | Should -Match "The folder .* is not empty"
            $warned | Should -Match "removing all content"
            $failed | Should -BeNullOrEmpty
        }

        "TestDrive:\One" | Should -Exist
        Get-ChildItem "TestDrive:\One" | Should -BeNullOrEmpty

    }

    It "Does not cause problems if you -Clean a non-existent folder" {

        "TestDrive:\Two" | Should -Not -Exist
        InModuleScope RequiredModules {
            AddPSModulePath TestDrive:\Two -Clean -WarningVariable warned -WarningAction SilentlyContinue -ErrorVariable failed
            $warned | Should -BeNullOrEmpty
            $failed | Should -BeNullOrEmpty
        }

        "TestDrive:\Two" | Should -Exist
        $Env:PSModulePath.Split([IO.Path]::PathSeparator)[0] | Should -Be (Convert-Path "TestDrive:\Two")
    }


    Pop-Location
}
