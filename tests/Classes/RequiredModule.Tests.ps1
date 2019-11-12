#requires -Module RequiredModule
using module RequiredModule
using namespace NuGet.Versioning

Describe "RequiredModule converts KeyValuePairs" {
    It "parses Module = '2.1'" {
        $Required = [RequiredModule]@{ "ModuleName" = "2.1" }
        $Required.Name | Should -Be "ModuleName"
        $Required.Version | Should -BeOfType ([VersionRange])
        $Required.Version.MinVersion | Should -Be "2.1"
        $Required.Version.MaxVersion | Should -BeNullOrEmpty
    }

    It "handles Module = '*' as a way to leave the version empty" {
        $Required = [RequiredModule]@{ "ModuleName" = "*" }
        $Required.Name | Should -Be "ModuleName"
        $Required.Version | Should -BeOfType ([VersionRange])
        $Required.Version.MinVersion | Should -BeNullOrEmpty
        $Required.Version.MaxVersion | Should -BeNullOrEmpty
    }

    It "handles nuget version range: Module = '[2.0,3.0)'" {
        $Required = [RequiredModule]@{ "ModuleName" = "[2.0,3.0)" }
        $Required.Name | Should -Be "ModuleName"
        $Required.Version | Should -BeOfType ([VersionRange])

        $Required.Version.MinVersion | Should -Be "2.0"
        $Required.Version.IsMinInclusive | Should -Be $true

        $Required.Version.MaxVersion | Should -Be "3.0"
        $Required.Version.IsMaxInclusive | Should -Be $false
    }

    It "handles nuget version range: Module = '2.*'" {
        $Required = [RequiredModule]@{ "ModuleName" = "2.*" }
        $Required.Name | Should -Be "ModuleName"
        $Required.Version | Should -BeOfType ([VersionRange])
        $Required.Credential | Should -BeNullOrEmpty

        $Required.Version.MinVersion | Should -Be "2.0"
        $Required.Version.IsMinInclusive | Should -Be $true

        $Required.Version.MaxVersion | Should -BeNullOrEmpty
        $Required.Version.IsMaxInclusive | Should -Be $false
    }

    It "handles nuget version range: Module = '[2.0,)'" {
        $Required = [RequiredModule]@{ "ModuleName" = "[2.0,)" }
        $Required.Name | Should -Be "ModuleName"
        $Required.Version | Should -BeOfType ([VersionRange])
        $Required.Credential | Should -BeNullOrEmpty

        $Required.Version.MinVersion | Should -Be "2.0"
        $Required.Version.IsMinInclusive | Should -Be $true

        $Required.Version.MaxVersion | Should -BeNullOrEmpty
        $Required.Version.IsMaxInclusive | Should -Be $false
    }

    It "handles wildcards as unspecified version numbers: Module = '*'" {
        $Required = [RequiredModule]@{ "ModuleName" = "*" }
        $Required.Name | Should -Be "ModuleName"
        $Required.Version | Should -BeOfType ([VersionRange])
        $Required.Credential | Should -BeNullOrEmpty

        $Required.Version.MinVersion | Should -BeNullOrEmpty
        $Required.Version.MaxVersion | Should -BeNullOrEmpty
    }

    It "parses Module = @{ Version = '2.1' }" {
        $Required = [RequiredModule]@{ "ModuleName" =  @{ Version = '2.1' } }
        $Required.Name | Should -Be "ModuleName"

        $Required.Credential | Should -BeNullOrEmpty

        $Required.Version | Should -BeOfType ([VersionRange])
        $Required.Version.MinVersion | Should -Be "2.1"
        $Required.Version.MaxVersion | Should -BeNullOrEmpty
    }

    It "parses Module = @{ Version = '2.1'; Repository = 'PSGallery' }" {
        $Required = [RequiredModule]@{ "ModuleName" = @{ Version = '2.1'; Repository = 'PSGallery' } }
        $Required.Name | Should -Be "ModuleName"
        $Required.Version | Should -BeOfType ([VersionRange])
        $Required.Repository | Should -Be "PSGallery"

        $Required.Credential | Should -BeNullOrEmpty

        $Required.Version.MinVersion | Should -Be "2.1"
        $Required.Version.MaxVersion | Should -BeNullOrEmpty
    }

    It "parses Module = @{ Version = '2.1'; Repository = 'http://powershellgallery.com/api/v2' }" {
        $Required = [RequiredModule]@{ "ModuleName" = @{ Version = '2.1'; Repository = 'http://powershellgallery.com/api/v2' } }
        $Required.Name | Should -Be "ModuleName"
        $Required.Version | Should -BeOfType ([VersionRange])
        $Required.Repository | Should -Be 'http://powershellgallery.com/api/v2'

        $Required.Credential | Should -BeNullOrEmpty

        $Required.Version.MinVersion | Should -Be "2.1"
        $Required.Version.MaxVersion | Should -BeNullOrEmpty
    }


    It "parses short form: Module = @{ V = '2.1'; Repo = 'PSGallery'; Cred = `$MyuCred }" {
        $Password = ConvertTo-SecureString -AsPlainText -Force "I'mJustT3st1ngDon'tDoThis!"
        $Credential = [PSCredential]::new("UserName", $Password)

        $Required = [RequiredModule]@{ "ModuleName" = @{ V = '2.1'; Repo = 'PSGallery'; Cred = $Credential } }

        $Required.Name | Should -Be "ModuleName"
        $Required.Version | Should -BeOfType ([VersionRange])
        $Required.Repository | Should -Be "PSGallery"

        $Required.Credential | Should -BeOfType PSCredential

        $Required.Version.MinVersion | Should -Be "2.1"
        $Required.Version.MaxVersion | Should -BeNullOrEmpty
    }

}