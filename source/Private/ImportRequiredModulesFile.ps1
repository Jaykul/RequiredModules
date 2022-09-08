using namespace System.Management.Automation
using namespace System.Management.Automation.Language

filter ImportRequiredModulesFile {
    <#
        .SYNOPSIS
            Load a file defining one or more RequiredModules
    #>
    [OutputType('RequiredModule')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Alias("Path", "PSPath")]
        [string]$RequiredModulesFile
    )

    $RequiredModulesFile = Convert-Path $RequiredModulesFile
    Write-Progress "Loading Required Module list from '$RequiredModulesFile'" -Id 1 -ParentId 0
    Write-Verbose "Loading Required Module list from '$RequiredModulesFile'"

    # I really need the RequiredModules files to preserve order, so we're parsing by hand...
    $ErrorActionPreference = "Stop"
    $Tokens = $Null; $ParseErrors = $Null

    # ParseFile on PS5 (and older) doesn't handle utf8 properly (treats it as ASCII if there's no BOM)
    # Sometimes, that causes an avoidable error. So I'm avoiding it, if I can:
    $Path = Convert-Path $RequiredModulesFile
    $Content = (Get-Content -Path $RequiredModulesFile -Encoding UTF8)

    # Remove SIGnature blocks, PowerShell doesn't parse them in .psd1 and chokes on them here.
    $Content = $Content -join "`n" -replace "# SIG # Begin signature block(?s:.*)"

    try {
        # On current PowerShell, this will work
        $AST = [Parser]::ParseInput($Content, $Path, [ref]$Tokens, [ref]$ParseErrors)
        # Older versions throw a MethodException because the overload is missing
    } catch [MethodException] {
        $AST = [Parser]::ParseFile($Path, [ref]$Tokens, [ref]$ParseErrors)

        # If we got parse errors on older versions of PowerShell, test to see if the error is just encoding
        if ($null -ne $ParseErrors -and $ParseErrors.Count -gt 0) {
            $StillErrors = $null
            $AST = [Parser]::ParseInput($Content, [ref]$Tokens, [ref]$StillErrors)
            # If we didn't get errors the 2nd time, ignore the errors (it's the encoding bug)
            # Otherwise, use the original errors that they have the path in them
            if ($null -eq $StillErrors -or $StillErrors.Count -eq 0) {
                $ParseErrors = $StillErrors
            }
        }
    }
    if ($null -ne $ParseErrors -and $ParseErrors.Count -gt 0) {
        $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new(([ParseException]::new([ParseError[]]$ParseErrors)), "RequiredModules Error", "ParserError", $RequiredModulesFile))
    }

    # Get the variables or subexpressions from strings which have them ("StringExpandable" vs "String") ...
    $Tokens += $Tokens | Where-Object { "StringExpandable" -eq $_.Kind } | Select-Object -ExpandProperty NestedTokens

    $Script = $AST.GetScriptBlock()
    try {
        $Script.CheckRestrictedLanguage( [string[]]@(), [string[]]@(), $false )
    } catch {
        $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new($_.Exception.InnerException, "RequiredModules Error", "InvalidData", $Script))
    }

    # Make all the hashtables ordered, so that the output objects make more sense to humans...
    if ($Tokens | Where-Object { "AtCurly" -eq $_.Kind }) {
        $ScriptContent = $AST.ToString()
        $Hashtables = $AST.FindAll( { $args[0] -is [HashtableAst] -and ("ordered" -ne $args[0].Parent.Type.TypeName) }, $Recurse)
        $Hashtables = $Hashtables | ForEach-Object {
            [PSCustomObject]@{Type = "([ordered]"; Position = $_.Extent.StartOffset }
            [PSCustomObject]@{Type = ")"; Position = $_.Extent.EndOffset }
        } | Sort-Object Position -Descending
        foreach ($point in $Hashtables) {
            $ScriptContent = $ScriptContent.Insert($point.Position, $point.Type)
        }

        $AST = [Parser]::ParseInput($ScriptContent, [ref]$Tokens, [ref]$ParseErrors)
        $Script = $AST.GetScriptBlock()
    }

    $Mode, $ExecutionContext.SessionState.LanguageMode = $ExecutionContext.SessionState.LanguageMode, "RestrictedLanguage"

    try {
        $Script.InvokeReturnAsIs(@()) | ConvertToRequiredModule
    } finally {
        $ExecutionContext.SessionState.LanguageMode = $Mode
    }
}