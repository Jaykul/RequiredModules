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

# Sanitize parameters to pass to Build-Module
$null = $PSBoundParameters.Remove('Test')

if (-not $Semver) {
    if ($semver = gitversion -showvariable SemVer) {
        $null = $PSBoundParameters.Add("SemVer", $SemVer)
    }
}


try {
    # Build new output
    $ParameterString = $PSBoundParameters.GetEnumerator().ForEach{ '-' + $_.Key + " '" + $_.Value + "'" } -join " "
    Write-Verbose "Build-Module Source\build.psd1 $($ParameterString) -Target CleanBuild"

    Build-Module source\build.psd1 @PSBoundParameters -Target CleanBuild -Passthru -OutVariable BuildOutput | Split-Path
    Write-Verbose "Module build output in $(Split-Path $BuildOutput.Path)"

    # Copy the psm1 content with the prefix and postfix.

} finally {
    Pop-Location -StackName BuildModule
}
