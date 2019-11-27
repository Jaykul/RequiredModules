using namespace NuGet.Versioning

# A class for a structured version of a dependency
# Note that by default, we leave the repository empty
# - If you set the repository to "PSGallery" we wil _only_ look there
# - If you leave it blank, we'll look in all registered repositories
class RequiredModule {
    [string]$Name
    [VersionRange]$Version
    [string]$Repository
    [PSCredential]$Credential

    # A simple dependency has just a name and a minimum version
    RequiredModule([string]$Name, [string]$Version) {
        $this.Name = $Name
        $this.Version = $Version
        # $this.Repository = "PSGallery"
    }

    # A more complicated dependency includes a specific repository URL
    RequiredModule([string]$Name, [VersionRange]$Version, [string]$Repository) {
        $this.Name = $Name
        $this.Version = $Version
        $this.Repository = $Repository
    }

    # The most complicated dependency includes credentials for that specific repository
    RequiredModule([string]$Name, [VersionRange]$Version, [string]$Repository, [PSCredential]$Credential) {
        $this.Name = $Name
        $this.Version = $Version
        $this.Repository = $Repository
        $this.Credential = $Credential
    }

    # This contains the logic for parsing a dependency entry: @{ module = "[1.2.3]" }
    # As well as extended logic for allowing a nested hashtable like:
    # @{
    #   module = @{
    #     version = "[1.2.3,2.0)"
    #     repository = "url"
    #   }
    # }
    hidden [void] Update([System.Collections.DictionaryEntry]$Data) {
        $this.Name = $Data.Key

        if ($Data.Value -as [VersionRange]) {
            $this.Version = [VersionRange]$Data.Value
        # This is extra: don't care about version, do care about repo ...
        } elseif($Data.Value -is [string] -or $Data.Value -is [uri]) {
            $this.Repository = $Data.Value

        } elseif($Data.Value -is [System.Collections.IDictionary]) {
                # this allows partial matching like the -Property of Select-Object:
            switch ($Data.Value.GetEnumerator()) {
                { "Version".StartsWith($_.Key, [StringComparison]::InvariantCultureIgnoreCase) } {
                    $this.Version = $_.Value
                }
                { "Repository".StartsWith($_.Key, [StringComparison]::InvariantCultureIgnoreCase) } {
                    $this.Repository = $_.Value
                }
                { "Credential".StartsWith($_.Key, [StringComparison]::InvariantCultureIgnoreCase) } {
                    $this.Credential = $_.Value
                }
                default {
                    throw [ArgumentException]::new($_.Key, "Unrecognized key '$($_.Key)' in module constraints for '$($_.Name)'")
                }
            }
        } else {
            throw [System.Management.Automation.ArgumentTransformationMetadataException]::new("Unsupported data type in module constraint for $($Data.Key) ($($Data.Key.PSTypeNames[0]))")
        }
    }

    # This is a cast constructor supporting casting a dictionary entry to RequiredModule
    # It's used that way in ConvertToRequiredModule and thus in ImportRequiredModulesFile
    RequiredModule([System.Collections.DictionaryEntry]$Data) {
        $this.Update($Data)
    }
}