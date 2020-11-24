param(
    # The path to a RequiredModules manifest, relative to the project root
    $ModuleUnderTest = $(Split-Path $PSScriptRoot),
    [switch]$SkipCodeCoverage
)

Push-Location (Split-Path $PSScriptRoot)

$ModuleUnderTest = Convert-Path $ModuleUnderTest
# if they pass a path to a numbered folder, split an extra time
if ($ModuleUnderTest -match "\\[\d\.]+$") {
    $ModuleUnderTest = Split-Path $ModuleUnderTest
}

# Add the folder above that to the PSModulePath
$ModulePath = Split-Path $ModuleUnderTest
if (-not ($Env:PSModulePath -split ';' -eq $ModulePath)) {
    Write-Warning "Adding '$ModulePath' to PSModulePath"
    $Env:PSModulePath = $ModulePath + ';' + $Env:PSModulePath
}

if (-not $SkipCodeCoverage) {
    # Add all the PSM1 Files to the CodeCoverage
    $ModuleUnderTest = Get-ChildItem $ModuleUnderTest -Filter *.psm1 -Recurse | Convert-Path
    Invoke-Pester .\Tests -CodeCoverage $ModuleUnderTest -CodeCoverageOutputFile .\coverage.xml
} else {
    Invoke-Pester .\Tests
}

Pop-Location
