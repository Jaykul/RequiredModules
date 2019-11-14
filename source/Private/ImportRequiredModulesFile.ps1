function ImportRequiredModulesFile {
    # Load a requirements file
    [CmdletBinding()]
    param(
        $RequiredModulesFile
    )

    $RequiredModulesFile = Convert-Path $RequiredModulesFile
    Write-Progress "Loading Required Module list from '$RequiredModulesFile'" -Id 1 -ParentId 0
    Write-Verbose "Loading Required Module list from '$RequiredModulesFile'"
    $LocalizedData = @{
        BaseDirectory = [IO.Path]::GetDirectoryName($RequiredModulesFile)
        FileName = [IO.Path]::GetFileName($RequiredModulesFile)
    }
    (Import-LocalizedData @LocalizedData).GetEnumerator().ForEach({
        [RequiredModule[]]$_
    })
}