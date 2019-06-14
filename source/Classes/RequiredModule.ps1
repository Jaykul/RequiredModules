using namespace NuGet.Versioning

class RequiredModule {
    [string]$Name
    [VersionRange]$Version
    [string]$Repository

    RequiredModule([string]$Name, [string]$Version) {
        $this.Name = $Name
        $this.Version = $Version
        # $this.Repository = "PSGallery"
    }

    RequiredModule([string]$Name, [VersionRange]$Version, [string]$Repository) {
        $this.Name = $Name
        $this.Version = $Version
        $this.Repository = $Repository
    }

    hidden [void] Update([System.Collections.DictionaryEntry]$Data) {
        $this.Name = $Data.Key
        # $this.Repository = "PSGallery"

        if ($Data.Value -as [VersionRange]) {
            $this.Version = [VersionRange]$Data.Value
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
                default {
                    throw [ArgumentException]::new($_.Key, "Unrecognized key $($_.Key) in module contraints")
                }
            }
        } else {
            throw [System.Management.Automation.ArgumentTransformationMetadataException]::new("Unsupported data type in module constraint for $($Data.Key)")
        }
    }

    RequiredModule([System.Collections.DictionaryEntry]$Data) {
        Update($Data)
    }

    RequiredModule([System.Collections.IDictionary]$Data) {
        if ($Data.Count -ne 1) {
            throw [ArgumentOutOfRangeException]::new("Data", "Can't convert dictionaries with more than one entry to RequiredModule")
        } else {
            Update(@($Data.GetEnumerator())[0])
        }
    }
}