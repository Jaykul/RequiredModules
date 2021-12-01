<#
    For an example use of these functions, the following is loosely based on the build.ps1 script in my RequiredModules repository.
    It combines a "param()" header, the required assembly dll, and a module psm1, with a call to the public function in the module:

    Set-Content $ScriptPath @(
        "[CmdletBinding()]param()"
        Compress-Module $AssemblyPath, $ModulePath
        "Install-RequiredModule 'RequiredModules.psd1'"
    )
#>

function Compress-Module {
    <#
        .SYNOPSIS
            Compresses and encodes a file for embedding into a script
        .DESCRIPTION
            Reads the raw bytes and then compress (gzip) them, before base64 encoding the result
        .EXAMPLE
            Get-ChildItem *.dll, *.psm1 | Compress-Module >> Script.ps1
        .LINK
            ExpandToMemory
    #>
    [CmdletBinding()]
    param(
        # The path to the dll or script file to compress
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("PSPath")]
        [string[]]$Path,

        # If set, return the raw base64. Otherwise, returns a script for embedding
        [switch]$Passthru
    )
    begin {
        $Result = @()
    }
    process {
        foreach ($File in $Path | Convert-Path) {
            $Source = [System.IO.MemoryStream][System.IO.File]::ReadAllBytes($File)
            $OutputStream = [System.IO.Compression.DeflateStream]::new(
                [System.IO.MemoryStream]::new(),
                [System.IO.Compression.CompressionMode]::Compress)
            $Source.CopyTo($OutputStream)
            $OutputStream.Flush()
            $ByteArray = $OutputStream.BaseStream.ToArray()
            if ($Passthru) {
                [Convert]::ToBase64String($ByteArray)
            } else {
                $Result += [Convert]::ToBase64String($ByteArray)
            }
        }
    }
    end {
        if (!$Passthru) {
            [ScriptBlock]::Create("`$null = '$($Result -join "', '")' |`n.{`n$((Get-Command Expand-ToMemory).ScriptBlock)`n}")
        }
    }
}

function Expand-ToMemory {
    <#
        .SYNOPSIS
            Expands a string and loads it as an assembly or scriptblock
        .DESCRIPTION
            Converts Base64 encoded string to bytes and decompresses (gzip) it, before attempting to load or execute the result
        .LINK
            CompressToString
    #>
    [CmdletBinding(DefaultParameterSetName = "ByteArray")]
    param(
        # A Base64 encoded and deflated assembly or script
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Base64Content
    )
    process {
        $DeflateStream = [System.IO.Compression.DeflateStream]::new(
            [System.IO.MemoryStream][System.Convert]::FromBase64String($Base64Content),
            [System.IO.Compression.CompressionMode]::Decompress)
        $OutputStream = [System.IO.MemoryStream]::new()
        $DeflateStream.CopyTo($OutputStream)
        [System.Reflection.Assembly]::Load($OutputStream.ToArray())
        trap {
            $null = $OutputStream.Seek(0, "Begin")
            # If it's a script, deal with the BOM and import it as a module in the global scope
            $Source = [System.IO.StreamReader]::new($OutputStream, $true).ReadToEnd()
            New-Module ([ScriptBlock]::Create($Source)) -Verbose:$false | Import-Module -Scope Global -Verbose:$false
            continue
        }
    }
}