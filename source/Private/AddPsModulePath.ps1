filter AddPSModulePath {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Alias("PSPath")]
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path,

        [switch]$Clean
    )
    Write-Verbose "Adding '$Path' to the PSModulePath"

    # First, guarantee it exists, as a folder
    if (-not (Test-Path $Path -PathType Container)) {
        # NOTE: If it's there as a file, then
        #       New-Item will throw a System.IO.IOException "An item with the specified name ... already exists"
        New-Item $Path -ItemType Directory -ErrorAction Stop
        Write-Verbose "Created Destination directory: $(Convert-Path $Path)"
    } elseif (Get-ChildItem $Path) {
        # If it's there as a directory that's not empty, maybe they said we should clean it?
        if (!$Clean) {
            Write-Warning "The folder at '$Path' is not empty, and it's contents may be overwritten"
        } else {
            Write-Warning "The folder at '$Path' is not empty, removing all content from '$($Path)'"
            try {
                Remove-Item $Path -Recurse -ErrorAction Stop # No -Force -- if this fails, you should handle it yourself
                New-Item $Path -ItemType Directory
            } catch {
                $PSCmdlet.WriteError(
                    [System.Management.Automation.ErrorRecord]::new(
                        [Exception]::new("Failed to clean destination folder '$($Path)'"),
                        "Destination Cannot Be Emptied",
                        "ResourceUnavailable", $Path))
                return
            }
        }
    }

    # Make sure it's on the PSModulePath
    $RealPath = Convert-Path $Path
    if (-not (@($Env:PSModulePath.Split([IO.Path]::PathSeparator)) -contains $RealPath)) {
        Write-Verbose "Adding $($RealPath) to PSModulePath"
        $Env:PSModulePath = $RealPath + [IO.Path]::PathSeparator + $Env:PSModulePath
    }
    $RealPath
}