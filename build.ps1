#requires -Module Configuration, ModuleBuilder
<#
    .Synopsis
        This is just a bootstrapping build, for when ModuleBuilder can't be used to build ModuleBuilder
#>
[CmdletBinding()]
param(
    # A specific folder to build into
    $OutputDirectory,

    # The version of the output module
    [Alias("ModuleVersion")]
    [string]$SemVer
)
$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot -StackName BuildModule

if (-not $Semver -and (Get-Command gitversion -ErrorAction SilentlyContinue)) {
    if ($semver = gitversion -showvariable SemVer) {
        $null = $PSBoundParameters.Add("SemVer", $SemVer)
    }
}


try {
    # Build new output
    $ParameterString = $PSBoundParameters.GetEnumerator().ForEach{ '-' + $_.Key + " '" + $_.Value + "'" } -join " "
    Write-Verbose "Build-Module Source/build.psd1 $($ParameterString) -Target CleanBuild"

    Build-Module source/build.psd1 @PSBoundParameters -Target CleanBuild -Passthru -OutVariable BuildOutput | Split-Path
    Write-Verbose "Module build output in $($BuildOutput.Path)"

    # Pack the psm1 and lib into a script
    Import-Module "$PSScriptRoot\pack.psm1"
    $ModulePath = [IO.Path]::ChangeExtension($BuildOutput.Path, ".psm1")
    $AssemblyPath = Split-Path $BuildOutput.Path | Join-Path -Child "lib/NuGet.Versioning.dll"
    $ScriptPath = Split-Path $BuildOutput.Path | Join-Path -Child "Install-RequiredModule.ps1"

    Set-Content $ScriptPath @(
        Get-Content $PSScriptRoot/Source/ScriptHeader.ps1
        Compress-ToString $AssemblyPath, $ModulePath
        "Install-RequiredModule @PSBoundParameters"
    )

    Write-Verbose "Script compiled to $($ScriptPath)"
    $ModuleInfo = @(Get-Module $BuildOutput -ListAvailable)[0]
    Update-ScriptFileInfo $ScriptPath -Version $ModuleInfo.Version -Author $ModuleInfo.Author -CompanyName $ModuleInfo.CompanyName -Copyright $ModuleInfo.Copyright -Tags $ModuleInfo.Tags -ProjectUri $ModuleInfo.ProjectUri -LicenseUri $ModuleInfo.LicenseUri -IconUri $ModuleInfo.IconUri -ReleaseNotes $ModuleInfo.ReleaseNotes

} finally {
    Pop-Location -StackName BuildModule
}
