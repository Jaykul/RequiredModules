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
    Write-Verbose "Build-Module Source\build.psd1 $($ParameterString) -Target CleanBuild"

    Build-Module source\build.psd1 @PSBoundParameters -Target CleanBuild -Passthru -OutVariable BuildOutput | Split-Path
    Write-Verbose "Module build output in $($BuildOutput.Path)"

    # Pack the psm1 and lib into a script
    $Lib = Split-Path $BuildOutput.Path | Join-Path -ChildPath lib/NuGet.Versioning.dll | Convert-Path
    [byte[]]$UncompressedFileBytes = [IO.File]::ReadAllBytes($Lib)
    # Since this is all backed by a memory stream, there's really nothing to dispose of
    $DeflateStream = [IO.Compression.DeflateStream]::new([IO.MemoryStream]::new(), [IO.Compression.CompressionMode]::Compress)
    $DeflateStream.Write($UncompressedFileBytes, 0, $UncompressedFileBytes.Length)
    $EncodedCompressedFile = [Convert]::ToBase64String($DeflateStream.BaseStream.ToArray())

    $ScriptPath = Split-Path $BuildOutput.Path | Join-Path -Child "Install-RequiredModule.ps1"
    $ModulePath = [IO.Path]::ChangeExtension($BuildOutput.Path, ".psm1")

    $Content = Get-Content $ModulePath
    $Content = $Content -replace 'throw "You must import Nuget.Versioning"', "`$EncodedCompressedFile = '$EncodedCompressedFile'"
    $Content = $Content -replace '<#NuGetVersioningSize#>', $UncompressedFileBytes.Length
    $Content += "Install-RequiredModule @PSBoundParameters"
    $Content | Set-Content $ScriptPath

} finally {
    Pop-Location -StackName BuildModule
}
