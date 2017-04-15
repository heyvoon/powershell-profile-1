# powershell-profile
Useful functions, configurations and aliases that I use with PowerShell on both Windows and Linux.

This was inspired by [mikemaccana/powershell-profile](https://github.com/mikemaccana/powershell-profile).

### Installation

To install this profile, just drop it in your default PowerShell config directory:

```ps
$profileFolder = split-path $profile;

if (-not (Test-Path $profile)) {
    New-Item -ItemType directory -Path $profileFolder -ErrorAction ignore;
}

# This will overwite whatever profile is there already:
cp ./profile.ps1 $profile;

# Load the profile
. $profile;
```

Alternatively, leave your current profile intact and load this one in addition to it:


```ps
# Inside your current powershell profile
. path/to/profile.ps1
```
