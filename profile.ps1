# Powershell lacks a null-coalescing (??) operator, so this function makes up for it.
function Coalesce($a, $b) { if ($a -ne $null) { $a } else { $b } }

# Easily add a property to a custom object
function AddPropTo-Object($obj, $propName, $value) {
	$obj | Add-Member -type NoteProperty -name $propName -value $value;

	return $obj;
}

Set-Alias -name ?? -value Coalesce;
Set-Alias -name prop -value AddPropTo-Object;

# Save the profile name for use when copying between $Profile and $onedrive/profile
$profileName = (get-item $profile).Name;
$profileFolder = split-path $profile;
$username = ?? $env:username $(whoami);

function getMachineType() {
	if ($IsLinux) {
		return "Linux";
	};

	if ($IsOSX) {
		return "macOS";
	}

	return "Windows";
}

$machineType = getMachineType;
# IsLinux, IsOSX and IsWindows are provided by PS on .NET Core, but not on vanilla Windows. 
$isNotWindows = $IsLinux -or $IsOSX;

# Customize the posh-git prompt to only show the current folder name + git status
function prompt {
	$origLastExitCode = $LASTEXITCODE;
	$folderName = (get-item $pwd).Name;
	# $emoji = [char]::ConvertFromUtf32(0x1F914);  

	if ($isNotWindows) {
		# A bug in PSReadline on .NET Core makes all colored write-host output in prompt 
		# function, including write-vcsstatus, echo twice.
		# https://github.com/PowerShell/PowerShell/issues/1897
		# https://github.com/lzybkr/PSReadLine/issues/468
		"$folderName => ";
	} else {
		write-host "$folderName" -nonewline -foregroundcolor green;
		Write-VcsStatus;
		" => ";
	}

	$LASTEXITCODE = $origLastExitCode;
}

function Load-Module
{
    param (
        [parameter(Mandatory = $true)][string] $name
    )

    $retVal = $true

    if (!(Get-Module -Name $name))
    {
        $retVal = Get-Module -ListAvailable | where { $_.Name -eq $name }

        if ($retVal)
        {
            try
            {
                Import-Module $name -ErrorAction SilentlyContinue
            }

            catch
            {
                $retVal = $false

				write-host -foregroundcolor yellow "Failed to import $name on $machineType machine. Please install the module via OneGet, or download the script and place it in $profileFolder.";
            }
        }
    }

    return $retVal
}

# PSCX is not supported on Linux or OSX yet. 
# https://github.com/Pscx/Pscx/issues/16
$pscxImported = Load-Module "Pscx";
$jumpLocationImported = Load-Module "jump.location";
$powerLsImported = Load-Module "powerls";
$poshGitImported = Load-Module "posh-git";

# Add program folders to the path
if ($pscxImported) {
	Add-PathVariable "${env:ProgramFiles}\7-Zip";
	Add-PathVariable "${env:ProgramFiles}\OpenSSH";
	Add-PathVariable "C:\tools\mingw\bin";
	Add-PathVariable "${env:ProgramFiles(x86)}\Microsoft SDKs\F#\4.1\Framework\v4.0";
}

# Set PowerLS as the default ls Command
if ($powerLsImported) {
	Set-Alias -Name ls -Value PowerLS -Option AllScope
}

# Load the psenv file
$psenv = "$(Split-Path $profile)/psenv.ps1";

if (! (Test-Path $psenv)) {
	# Create the env file and swallow the output
	New-Item $psenv | out-null;
}

. $psenv;

function findCloudFolder($cloudName) {
	$basicDrive = $null;

	foreach ($drive in "~", "C:", "D:") {
		if (Test-Path "$drive/$cloudName") {
			$basicDrive = $drive;

			break;
		}
	}

	if ($basicDrive -ne $null) {
		return "$basicDrive/$cloudName";
	}

	if ($isNotWindows) {
		function searchTopFolder($folderName) {
			$drivePath = $null;

			if (Test-Path $folderName) {
				# Using foreach here instead of piping to %, because breaking in a % pipe stops the function itself, not the %.
				foreach ($drive in gci "/media/$username") {
					if (Test-Path "$($drive.FullName)/$cloudName") {
						$drivePath = $drive.FullName;

						break;
					}
				}

				if ($drivePath -ne $null) {
					return "$drivePath/$cloudName";
				}
			}

			return $null;
		}

		return ?? (searchTopFolder "/media/$username") (searchTopFolder "/mnt")
	}

	# Don't set the value if it wasn't found.
	return $null;
}

# Find OneDrive and Dropbox
$onedrive = findCloudFolder "OneDrive";
$dropbox = findCloudFolder "Dropbox";

# Function to reset colors when they get messed up by some program (e.g. react native)
function Reset-Colors {
	[Console]::ResetColor();
	echo "Console colors have been reset.";
}

Set-Alias -Name resetColors -Value Reset-Colors -Option AllScope;

# Extra PS goodies, inspired by https://github.com/mikemaccana/powershell-profile
function uptime {
	if ($isNotWindows) {
		bash -c "uptime";

		return;
	}

    Get-WmiObject win32_operatingsystem | select csname, @{LABEL='LastBootUpTime';
        EXPRESSION={$_.ConverttoDateTime($_.lastbootuptime)}
    }
}

function fromHome($Path) {
    $Path.Replace("$home", "~")
}

# http://mohundro.com/blog/2009/03/31/quickly-extract-files-with-powershell/
function unarchive([string]$file, [string]$outputDir = '') {
    if (-not (Test-Path $file)) {
        $file = Resolve-Path $file
    }

    if ($outputDir -eq '') {
        $outputDir = [System.IO.Path]::GetFileNameWithoutExtension($file)
    }

    7z e "-o$outputDir" $file
}

# http://stackoverflow.com/questions/39148304/fuser-equivalent-in-powershell/39148540#39148540
function fuser($relativeFile){
    $file = Resolve-Path $relativeFile

    echo "Looking for processes using $file"

	if ($isNotWindows) {
		sudo bash -c "fuser $file.Path";

		return;
	}

    foreach ( $Process in (Get-Process)) {
        foreach ( $Module in $Process.Modules) {
            if ( $Module.FileName -like "$file*" ) {
                $Process | select id, path
            }
        }
    }
}

function findfile($name) {
    ls -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | foreach {
        $place_path = $_.directory
        echo "${place_path}\${_}"
    }
}

function which($name) {
    Get-Command $name | Select-Object -ExpandProperty Definition
}

function unzip ($file) {
    $dirname = (Get-Item $file).Basename
    echo("Extracting", $file, "to", $dirname)
    New-Item -Force -ItemType directory -Path $dirname
    expand-archive $file -OutputPath $dirname -ShowProgress
}

# https://gist.github.com/aroben/5542538
function pstree {
	$ProcessesById = @{}
	foreach ($Process in (Get-WMIObject -Class Win32_Process)) {
		$ProcessesById[$Process.ProcessId] = $Process
	}

	$ProcessesWithoutParents = @()
	$ProcessesByParent = @{}
	foreach ($Pair in $ProcessesById.GetEnumerator()) {
		$Process = $Pair.Value

		if (($Process.ParentProcessId -eq 0) -or !$ProcessesById.ContainsKey($Process.ParentProcessId)) {
			$ProcessesWithoutParents += $Process
			continue
		}

		if (!$ProcessesByParent.ContainsKey($Process.ParentProcessId)) {
			$ProcessesByParent[$Process.ParentProcessId] = @()
		}
		$Siblings = $ProcessesByParent[$Process.ParentProcessId]
		$Siblings += $Process
		$ProcessesByParent[$Process.ParentProcessId] = $Siblings
	}

	function Show-ProcessTree([UInt32]$ProcessId, $IndentLevel) {
		$Process = $ProcessesById[$ProcessId]
		$Indent = " " * $IndentLevel
		if ($Process.CommandLine) {
			$Description = $Process.CommandLine
		} else {
			$Description = $Process.Caption
		}

		Write-Output ("{0,6}{1} {2}" -f $Process.ProcessId, $Indent, $Description)
		foreach ($Child in ($ProcessesByParent[$ProcessId] | Sort-Object CreationDate)) {
			Show-ProcessTree $Child.ProcessId ($IndentLevel + 4)
		}
	}

	Write-Output ("{0,6} {1}" -f "PID", "Command Line")
	Write-Output ("{0,6} {1}" -f "---", "------------")

	foreach ($Process in ($ProcessesWithoutParents | Sort-Object CreationDate)) {
		Show-ProcessTree $Process.ProcessId 0
	}
}

# Unix-touch
function unixtouch($file) {
	if ($isNotWindows) {
		bash -c "touch $file";

		return;
	}

  	"" | Out-File $file -Encoding ASCII
}

if (-not $isNotWindows) {
	Set-Alias -Name touch -Value unixtouch -Option AllScope
}

# Produce UTF-8 by default
# https://news.ycombinator.com/item?id=12991690
$PSDefaultParameterValues["Out-File:Encoding"]="utf8"

# TODO: Turn these custom scripts into modules that can be loaded without hardcoded paths.

# Add an alias for the Powershell-Utils bogpaddle.ps1 script.
Set-Alias -Name bogpaddle -Value 'D:\source\powershell-utils\bogpaddle.ps1' -Option AllScope
# Add an alias for the Powershell-Utils namegen.ps1 script.
Set-Alias -Name namegen -Value 'D:\source\powershell-utils\namegen.ps1' -Option AllScope
# Add an alias for the Powershell-Utils kmsignalr.ps1 script.
Set-Alias -Name kmsignalr -Value 'D:\source\powershell-utils\kmsignalr.ps1' -Option AllScope
# Add an alias for the Powershell-Utils download-video.ps1 script.
Set-Alias -Name download-video -Value 'D:\source\powershell-utils\download-video.ps1' -Option AllScope
# Add an alias for the Powershell-Utils guid.ps1 script.
Set-Alias -Name guid -Value 'D:\source\powershell-utils\guid.ps1' -Option AllScope
# Add an alias for the Powershell-Utils bcrypt.ps1 script.
Set-Alias -Name bcrypt -Value 'D:\source\powershell-utils\bcrypt.ps1' -Option AllScope
# Add an alias for the Powershell-Utils now.ps1 script.
Set-Alias -Name now -Value 'D:\source\powershell-utils\now.ps1' -Option AllScope
# Add an alias for the Powershell-Utils template.ps1 script.
Set-Alias -Name template -Value 'D:\source\powershell-utils\template.ps1' -Option AllScope
