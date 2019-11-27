# Install Required Modules for PowerShell Development Projects

This repository is for the `Install-RequiredModule` script which provides an early prototype of the RequiredResources functionality from the [PowerShellGet 3 RFC](https://github.com/PowerShell/PowerShell-RFC/blob/cc293e7d9c8bf7b01da7b051f73cb2af0691c9ae/2-Draft-Accepted/RFCxxxx-PowerShellGet-3.0.md)

I'm working on a re-write to support arbitrary repositories (i.e. so you can use it with your artifact feeds on Azure DevOps or GitHub) and this version is not yet ready, nor does it have a packaging `build` script, but I'm sharing it now anyway.

## Contributing

This project is MIT licensed and I'm happy to accept PRs, feature requests or bug reports.

If you're interested in helping, please realize that _all_ of the scripts in source/private define a `filter`, not a function. The difference is _simple_: the default body of a filter defines the `process` block, rather than the `end` block -- so all of these are pipeline-enabled by default.