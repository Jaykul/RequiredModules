@{  # NOTE: follow nuget syntax for versions: https://docs.microsoft.com/en-us/nuget/reference/package-versioning#version-ranges-and-wildcards
    "Pester"            = "[5.0,6.0)"
    "PackageManagement" = "[1.4.8,2.0)"
    "PSScriptAnalyzer"  = "1.*"
    "PowerShellGet"     = "[2.2.5,3.0)"
    "Metadata"          = "[1.5.7,2.0)"
    "Configuration"     = "[1.5.1,2.0)"
    "ModuleBuilder"     = @{
        Version    = "1.*"
        Repository = "https://www.powershellgallery.com/api/v2"
    }
}
