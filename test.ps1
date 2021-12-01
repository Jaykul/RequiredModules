#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '4.10.1'; MaximumVersion = '4.9999' }, @{ ModuleName = 'PowerShellGet'; ModuleVersion = '2.1.0'; MaximumVersion = '2.9999' }
using namespace Microsoft.PackageManagement.Provider.Utility
# using namespace System.Management.Automation
param(
    [switch]$SkipScriptAnalyzer,
    [switch]$SkipCodeCoverage,
    [switch]$HideSuccess,
    [switch]$IncludeVSCodeMarker
)
Push-Location $PSScriptRoot -StackName TestModule
$ModuleName = "RequiredModules"

# Disable default parameters during testing, just in case
$PSDefaultParameterValues += @{}
$PSDefaultParameterValues["Disabled"] = $true


# Find a built module as a version-numbered folder:
$FoundModule = Get-ChildItem [0-9]* -Directory | Sort-Object { $_.Name -as [SemanticVersion[]] } |
    Select-Object -Last 1 -Ov Version |
    Get-ChildItem -Filter "$($ModuleName).psd1"

if (!$FoundModule) {
    throw "Can't find $($ModuleName).psd1 in $($Version.FullName)"
}

$Show = if ($HideSuccess) {
    "Fails"
} else {
    "All"
}

Remove-Module $ModuleName -ErrorAction Ignore -Force
$ModuleUnderTest = Import-Module $FoundModule.FullName -PassThru -Force -DisableNameChecking -Verbose:$false
Write-Host "Invoke-Pester for Module $($ModuleUnderTest) version $($ModuleUnderTest.Version)"

# Add the folder above to the PSModulePath so classes and such can work
$ModulePath = Split-Path $PSScriptRoot
if (-not ($Env:PSModulePath -split ';' -eq $ModulePath)) {
    Write-Warning "Adding '$ModulePath' to PSModulePath"
    $Env:PSModulePath = $ModulePath + ';' + $Env:PSModulePath
}

if (-not $SkipCodeCoverage) {
    Invoke-Pester .\Tests -Show $Show -CodeCoverage $ModuleUnderTest.Path -CodeCoverageOutputFile .\coverage.xml
} else {
    Invoke-Pester .\Tests -Show $Show
}

# Write-Host
# if (-not $SkipScriptAnalyzer) {
#     Invoke-ScriptAnalyzer $ModuleUnderTest.Path
# }
Pop-Location -StackName TestModule

# Re-enable default parameters after testing
$PSDefaultParameterValues["Disabled"] = $false