param(
    [switch]$SkipCodeCoverage,
    [switch]$HideSuccess,
    [string]$Path,
    $PesterOption = @{ IncludeVSCodeMarker = $true }
)

Push-Location $PSScriptRoot\..\..
$ModuleUnderTest = Convert-Path $pwd

# if they pass a path to a numbered folder, split an extra time
if ($ModuleUnderTest -match "\\[\d\.]+$") {
    $ModuleUnderTest = Split-Path $ModuleUnderTest
}

# Add the folder above that to the PSModulePath, if it's not there already
$ModulePath = Split-Path $ModuleUnderTest
if (-not ($Env:PSModulePath -split ';' -eq $ModulePath)) {
    Write-Warning "Adding '$ModulePath' to PSModulePath"
    $Env:PSModulePath = $ModulePath + ';' + $Env:PSModulePath
}

$PesterParameters = @{
    PesterOption = $PesterOption
    Show = if ($HideSuccess) { "Fails" } else { "All" }
    Path = if ($Path) { $Path } else { "./Tests" }
}


Remove-Module (Split-Path $ModuleUnderTest -Leaf) -ErrorAction Ignore
Write-Host "Import-Module $ModuleUnderTest"
$ModuleUnderTest = Import-Module $ModuleUnderTest -PassThru

Write-Host "Invoke-Pester for Module $($ModuleUnderTest.Name) version $($ModuleUnderTest.Version)"

if (-not $SkipCodeCoverage) {
    # Get code coverage for the psm1 file
    $PesterParameters += @{
        CodeCoverage = $ModuleUnderTest.Path
        CodeCoverageOutputFile = "./coverage.xml"
    }
}
Write-Host "Invoke-Pester $($PesterParameters | Out-String)"
Invoke-Pester @PesterParameters

Pop-Location
