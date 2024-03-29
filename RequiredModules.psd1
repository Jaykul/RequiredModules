@{  # NOTE: follow nuget syntax for versions: https://docs.microsoft.com/en-us/nuget/reference/package-versioning#version-ranges-and-wildcards
    "PowerShellGet"    = "[2.0.4,3.0)"
    "Configuration"    = "[1.3.1,2.0)"
    "Pester"           = "[4.5.0,5.0)"
    "PSScriptAnalyzer" = "1.*"
    "ModuleBuilder"    = @{
        Version = "1.*"
        Repository = "https://www.powershellgallery.com/api/v2"
    }
}
