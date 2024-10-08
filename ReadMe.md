# Install Required Modules for PowerShell Development Projects

Although it's only superficially compatible with this module (and PowerShelLGet) you may want to have a look at [JustinGrote/ModuleFast](https://github.com/JustinGrote/ModuleFast), which is a re-implementation of installing Powershell modules from scratch. Without the dependency on PowerShellGet, it goes _much_ faster, and even uses a v3 nuget feed cache of the PowerShell gallery.

## Install-RequiredModule

This repository is for the `Install-RequiredModule` script you can find on the PowerShell Gallery. It was meant as a tool for developers, so you can just put a `RequiredModules.psd1` file in a repository and in just two steps, install all of the modules you need, whether interactively on a dev box, or in a CI build script:

```PowerShell
Install-Script Install-RequiredModule
Install-RequiredModule
```

The `Install-RequiredModule` command parses a hashtable and calls the (old) built-in PowerShellGet module to actually do the installation. It supports all current versions of PowerShell (including the legacy Windows PowerShell). It takes a hash table of module names to version _ranges_. By default, it reads a file named `RequiredModules.psd1` -- but you can pass a hash table at the command-line, or specify any file name you like. The format of the RequiredModules hashtable specifies the module name and version. There is also support for specifying custom repositories per-module (including by specifying the URL, so you don't have to have the repository registered ahead of time). Some examples:

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

> NOTE: We're using NuGet's syntax for version ranges because the PowerShell Gallery uses NuGet, and PowerShellGet wraps it. Their versions use square braces to mean matches which including the specified number, and round parenthesis to exclude it. There's also support for wildcards and ranges, etc. See [NuGet's documentation](https://docs.microsoft.com/en-us/nuget/concepts/package-versioning#version-ranges-and-wildcards) for more details.

## Latest Changes

### 5.1.1 Fixes support for prerelease versions

You can use ranges like `[1.0.0-a, 2.0.0-a)` to specify a range that _allows_ prerelease versions. Having _any_ pre-release label in either the minimum or maximum version will allow pre-release versions. This means that if you want to **exclude** pre-release versions of a future breaking change release, you should specify the maximum (exclusive) version with the "a" pre-release tag, like `2.0.0-a)` which is the lowest alphanumeric version, and not just `2.0.0)` -- this is because 2.0.0-beta is a _lower version number_ than 2.0.0.

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