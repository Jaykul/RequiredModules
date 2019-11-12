Describe "Install-RequiredModule installs modules" {

    Describe "Install-RequiredModule accepts a hashtable inline" {
        Install-RequiredModule @{
            "PowerShellGet"    = "2.0.4"
            "Configuration"    = "[1.3.1,2.0)"
            "Pester"           = "*"
            "PSScriptAnalyzer" = "1.*"
            "Questionmark.Naming"    = @{
                Version = "1.*"
                Repository = "https://qmdevteam.pkgs.visualstudio.com/_packaging/PowerShell@Local/nuget/v2"
                Credential = [PSCredential]::new("Automation", (ConvertTo-SecureString -Force -AsPlainText $ENV:VSS_NUGET_ACCESSTOKEN))
            }
        }
    }


}