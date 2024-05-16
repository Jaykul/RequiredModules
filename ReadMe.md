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


## Latest Changes

### 5.1.0 Supports Upgrades

This version supports upgrading modules you already have installed. Normally, `Install-RequiredModule` will only search online after determining that you don't have a valid version installed already. Now with the `-Upgrade` switch, it will search online first, and select the highest valid version, and _then_ check if you have _that version_ installed. If it's not already installed, it will install it.

In `-Upgrade` mode, you'll get warnings about the latest module version if it's newer than the valid range you've specified. Please let me know if this is a problem! I'm considering having those warnings suppressed by the `-Quiet` switch, but they are not, currently.

This version also adds an `Optimize-Dependency` command to the module version (currently available on PSGallery if you `-AllowPrerelease`). This command will sort modules into dependency order (so that dependencies are installed before the modules that depend on them).

### 5.0.0 Specify repositories

This version allows installing from any trusted repository! In this version, we no longer only (and automatically) use PSGallery. Instead, you must ensure that there is a repository registered and trusted, and we'll use whatever repostories you have trusted.

For instance, you could ensure the default PSGallery is registered, and trust it:

```PowerShell
Register-PSRepository -Default -ErrorAction Ignore -InstallationPolicy Trusted
Get-PSRepository -Name PSGallery | Set-PSRepository -InstallationPolicy Trusted
```

By default, we only install from trusted repositories, but there is a new `-TrustRegisteredRepositories` switch which ensures all of the repositories that are registered are treated as trusted for the purposes of installing the required modules.

There is a new syntax for the RequiredModules hashtables to support specifying a specific repository for each module.

Remember, Install-RequiredModule does not explicitly require PowerShellGet. PowerShell 5+ automatically include a version of it, and we assume that you're using it to install this script. If you need a higher version (which you very well may) you should put it in your RequiredModules manifest.

## Missing Functionality

- We need to handle PowerShellGet (and PackageManagement) specially. If they are in the list, install them first AND import them. This would allow clean environments to install pre-release modules.


## Contributing

This project is MIT licensed and I'm happy to accept PRs, feature requests or bug reports.

If you're interested in helping, please realize that _all_ of the scripts in source/private define a `filter`, not a function. The difference is _simple_: the default body of a filter defines the `process` block, rather than the `end` block -- so all of these are pipeline-enabled by default.