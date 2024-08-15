@{
    ModuleManifest = "./Source/RequiredModules.psd1"
    OutputDirectory = ".."
    CopyDirectories = "lib"
    VersionedOutputDirectory = $true
    Generators = @(
        @{ Generator = "ConvertTo-Script"; Function = "Install-RequiredModule" }
    )
}
