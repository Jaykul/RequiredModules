# Install Required Modules for PowerShell Development Projects

This repository is for the `Install-RequiredModule` script you can find on the PowerShell Gallery. It was meant as a tool for developers, so you can put a `RequiredModules.psd1` file in a repository and in just two steps, install all of the modules you need, whether interactively on a dev box, or in a CI build script:


```PowerShell
Install-Script Install-RequiredModule
Install-RequiredModule
```

The `Install-RequiredModule` command parses a hashtable from a file (named `RequiredModules.psd1` by default, but you can pass a path to any file name) or on the command-line. The format of the RequiredModules hashtable specifies the module name and version, using [NuGet's version range syntax](https://docs.microsoft.com/en-us/nuget/concepts/package-versioning#version-ranges-and-wildcards). It also supports specifying the repository (either the URL or the registered name). Some examples:

```PowerShell
@{
    "PowerShellGet"    = "1.0.0"
    "Configuration"    = "[1.0.0,2.0)"
    "ModuleBuilder"    = @{
        Version = "2.*"
        Repository = "https://www.powershellgallery.com/api/v2"
    }
}
```

> NOTE: We're using NuGet's syntax for version ranges because the PowerShell Gallery uses NuGet, and PowerShellGet wraps it. Their versions use square braces to mean matches including the number, and round parenthesis to exclude it. There's support for wildcards and ranges, etc. See [NuGet's documentation](https://docs.microsoft.com/en-us/nuget/concepts/package-versioning#version-ranges-and-wildcards) for more details.


## Contributing

This project is MIT licensed and I'm happy to accept PRs, feature requests or bug reports.

If you're interested in helping, please realize that _all_ of the scripts in source/private define a `filter`, not a function. The difference is _simple_: the default body of a filter defines the `process` block, rather than the `end` block -- so all of these are pipeline-enabled by default.