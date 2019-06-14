Push-Location (Split-Path $PSScriptRoot)

Build-Module -SourcePath .\source\build.psd1 -SemVer $(gitversion -showvariable semver) -Passthru

Pop-Location