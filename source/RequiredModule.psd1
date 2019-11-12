@{
    # The module version should be SemVer.org compatible
    ModuleVersion          = "1.0.0"

    # PrivateData is where all third-party metadata goes
    PrivateData            = @{
        # PrivateData.PSData is the PowerShell Gallery data
        PSData             = @{
            # Prerelease string should be here, so we can set it
            Prerelease     = 'beta'

            # Release Notes have to be here, so we can update them
            ReleaseNotes   = '
            4.1.0 Support non-PSGallery feeds
            4.0.6 Fix a double -Verbose problem
            4.0.5 Let the -Destination be non-empty (so we do not have to re-download every time)
            4.0.4 Fix PowerShell 5 .Where bug
            4.0.3 Fix module check when using -Destination to force all modules to be in destination
            4.0.2 Fix Remove-Module error
            4.0.1 Add logging outputs
            4.0.0 Breaking change: require the -Destination to start empty (allow -CleanDestination to clear it)
                Fix for adding the destination to PSModulePath multiple times
                Started testing this so I can ship it to PowerShellGet
            3.0.0 Breaking change: switch -SkipImport to -Import -- inverting the logic to NOT import by default
                Add -Destination parameter to support installing in a local tool path
            2.0.1 Squash mistaken "InstallError" message caused by Select-Object -First
                Clean up output that was unexpected
            2.0.0 Breaking change: use NuGetVersion to support wildcards like 3.*
                Improve the error messages around aborted or failed installs
            1.0.1 Fix "Version 3.4.0 of module Pester is already installed"
            1.0.0 This is the first public release - it probably does not work right
            '

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags           = 'Install','Requirements','Development'

            # A URL to the license for this module.
            LicenseUri     = 'https://github.com/PoshCode/RequiredModule/blob/master/LICENSE'

            # A URL to the main website for this project.
            ProjectUri     = 'https://github.com/PoshCode/RequiredModule'

            # A URL to an icon representing this module.
            IconUri        = 'https://github.com/PoshCode/RequiredModule/blob/resources/RequiredModule.png?raw=true'
        } # End of PSData
    } # End of PrivateData

    # The main script module that is automatically loaded as part of this module
    RootModule             = 'RequiredModule.psm1'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules        = @() # 'Configuration'

    RequiredAssemblies     = @("lib\NuGet.Versioning.dll")

    # Always define FunctionsToExport as an empty @() which will be replaced on build
    FunctionsToExport      = @()

    # ID used to uniquely identify this module
    GUID                   = '72076b25-00b7-4e2a-997a-35a411ae17cd'
    Description            = 'A module for installing PowerShell resources'

    # Common stuff for all our modules:
    CompanyName            = 'PoshCode'
    Author                 = 'Joel Bennett'
    Copyright              = "Copyright 2019 Joel Bennett"

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion      = '5.1'
    CompatiblePSEditions   = @('Core','Desktop')
}

