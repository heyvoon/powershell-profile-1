<#
Author: Andre Barbosa de Amaral

Requirements for this script to work:
- Notepadd++
- ConnectM365Services.psm1 module installed
Get the module here -> https://gist.github.com/heyvoon/afb3e081f6395b47732e9555ec934715

!! Change the variables below accordingly !!

This file should be stored in $PROFILE.CurrentUserAllHosts
If $PROFILE.CurrentUserAllHosts doesn't exist, you can make one with the following:
PS> New-Item $PROFILE.CurrentUserAllHosts -ItemType File -Force
This will create the file and the containing subdirectory if it doesn't already
#>

## START DEFINITION OF VARIABLES
$adsynServer = "< AD SYNC SERVER >"  # Change here to your own AD Sync Server
$nplusplus = "C:\Program Files (x86)\Notepad++\notepad++.exe"  # Path to Notepad++
$installUtil = "C:\WINDOWS\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe"
$docFolder = "< USER DOCUMENTS FOLDER >"

###
### DO NOT CHANGE ANYTHING BEYOND THIS POINT
###

Write-Host "`nUse 'Get-MyCommands (gmc)' and 'Get-MyAliases (gma)'`nto see the list of your custom functions and aliases. `n`n" -ForegroundColor YELLOW

if (!(Test-Path -Path $profile.CurrentUserAllHosts)) {
    New-Item -ItemType File -Path $profile.CurrentUserAllHosts -Force
  }

## START FUNCTIONS DEFINITIONS

# Add a clock to the title bar
Function Add-Clock {
    $code = { 
       $pattern = '\d{2}:\d{2}:\d{2}'
       do {
         $clock = Get-Date -format 'HH:mm:ss'
   
         $oldtitle = [system.console]::Title
         if ($oldtitle -match $pattern) {
           $newtitle = $oldtitle -replace $pattern, $clock
         } else {
           $newtitle = "$clock $oldtitle"
         }
         [System.Console]::Title = $newtitle
         Start-Sleep -Seconds 1
       } while ($true)
     }
   
    $ps = [PowerShell]::Create()
    $null = $ps.AddScript($code)
    $ps.BeginInvoke()
   } Add-Clock | Out-Null

# Start IsAdministrator check and change title accordingly
function Test-IsAdministrator {
    $Administrator = [Security.Principal.WindowsBuiltinRole]::Administrator
    $User = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal]($User)).IsInRole($Administrator)
}

Function Set-ConsoleTitle {
 if(-not (Test-IsAdministrator))
  {$Host.ui.RawUI.WindowTitle = "- REGULAR PowerShell $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)  Dude!  |  Hostname:  $($env:COMPUTERNAME.ToUpper())" }
 else {$Host.ui.RawUI.WindowTitle = "- SUPER PowerShell $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor) Guru!  |  Hostname: $($env:COMPUTERNAME.ToUpper())"}
} Set-ConsoleTitle
# End IsAdministrator

# Function to list all aliases available
Function Get-MyAliases {
    Get-Content -Path $profile.CurrentUserAllHosts | Select-String -Pattern "^Set-Alias.+" | ForEach-Object {
        # Find function names that contains letters, numbers and dashes
        [Regex]::Matches($_, "^Set-Alias ([\s\S]+)","IgnoreCase").Groups[1].Value
    } | Where-Object { $_ -ine "prompt" } | Sort-Object
}

# Function to list all custom commands available
Function Get-MyCommands {
    Get-Content -Path $profile.CurrentUserAllHosts | Select-String -Pattern "^function.+" | ForEach-Object {
        # Find function names that contains letters, numbers and dashes
        [Regex]::Matches($_, "^function ([a-z0-9.-]+)","IgnoreCase").Groups[1].Value
    } | Where-Object { $_ -ine "prompt" } | Sort-Object
}

# Call Notepad++ with current profile for editing
Function Edit-Profile { & $nplusplus $profile.CurrentUserAllHosts }

# Sends a Delta AD Sync with Azure AD on the remote AD Sync Server. Change the server name here!
Function Delta { 
    try { Invoke-command -scriptblock { Start-ADSyncSyncCycle Delta } -computername $adsynServer -ErrorAction stop}
    catch { Write-Host "`nIt seems you're not connected to the company VPN.`nConnect to the VPN and try again.`n" -BackgroundColor RED -ForegroundColor YELLOW}
}

# Connect to Azure services
Function Azure { ConnectM365 -MFA -Services AzureAD }

# Connect to Exchange online
Function Exo { ConnectM365 -MFA -Services ExchangeOnline }

# List Modules Paths
Function Get-psmodulePath { $env:PSModulePath.split(';') }

# Notepad++
Function n++ { & $nplusplus $args }

# Reload Profile
Function reloadProfile { . $profile.CurrentUserAllHosts }

# Open PowerShell command history file
Function Open-HistoryFile { & $nplusplus (Get-PSReadLineOption | Select-Object -ExpandProperty HistorySavePath) }

# Sudo alias, from http://www.exitthefastlane.com/2009/08/sudo-for-powershell.html

# Open anything with elevated process
Function elevate-Process {
  $file, [string]$arguments = $args;
  $psi = new-object System.Diagnostics.ProcessStartInfo $file;
  $psi.Arguments = $arguments;
  $psi.Verb = "runas";
  $psi.WorkingDirectory = get-location;
  [System.Diagnostics.Process]::Start($psi);
}

# Extra PS goodies, inspired by https://github.com/mikemaccana/powershell-profile
Function uptime {
  if ($isNotWindows) {
      bash -c "uptime";
      return;
  }

  Get-WmiObject win32_operatingsystem | Select-Object csname, @{LABEL = 'LastBootUpTime';
      EXPRESSION = {$_.ConverttoDateTime($_.lastbootuptime)}
  }
}

# Unarchiver
Function unarchive([string]$file, [string]$outputDir = '') {
  if (-not (Test-Path $file)) {
      $file = Resolve-Path $file
  }

  if ($outputDir -eq '') {
      $outputDir = [System.IO.Path]::GetFileNameWithoutExtension($file)
  }

  7z e "-o$outputDir" $file
}

# Find files
Function findfile($name) {
  ls -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | foreach {
      $place_path = $_.directory
      Write-Host "${place_path}\${_}"
  }
}

# https://gist.github.com/aroben/5542538
Function pstree {
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

  Function Show-ProcessTree([UInt32]$ProcessId, $IndentLevel) {
      $Process = $ProcessesById[$ProcessId]
      $Indent = " " * $IndentLevel
      if ($Process.CommandLine) {
          $Description = $Process.CommandLine
      }
      else {
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

# Find commands
Function which($name) { Get-Command $name | Select-Object -ExpandProperty Definition }


# https://github.com/JRJurman/PowerLS
Function PowerLS {
  <#
.Synopsis
Powershell unix-like ls
Written by Jesse Jurman (JRJurman)
.Description
A colorful ls
.Parameter Redirect
The first month to display.
.Example
# List the current directory
PowerLS
.Example
# List the parent directory
PowerLS ../
#>
  param(
      [string]$redirect = "."
  )
  write-host "" # add newline at top

  # get the console buffersize
  $buffer = Get-Host
  $bufferwidth = $buffer.ui.rawui.buffersize.width

  # get all the files and folders
  $childs = Get-ChildItem $redirect

  # get the longest string and get the length
  $lnStr = $childs | select-object Name | sort-object { "$_".length } -descending | select-object -first 1
  $len = $lnStr.name.length

  # keep track of how long our line is so far
  $count = 0

  # extra space to give some breather space
  $breather = 4

  # for every element, print the line
  foreach ($e in $childs) {

      $newName = $e.name + (" " * ($len - $e.name.length + $breather))
      $count += $newName.length

      # determine color we should be printing
      # Blue for folders, Green for files, and Gray for hidden files
      if (($newName -match "^\..*$") -and (Test-Path ($redirect + "\" + $e) -pathtype container)) {
          #hidden folders
          $newName = $e.name + "\" + (" " * ($len - $e.name.length + $breather - 1))
          write-host $newName -nonewline -foregroundcolor darkcyan
      }
      elseif (Test-Path ($redirect + "\" + $e) -pathtype container) {
          #normal folders
          $newName = $e.name + "\" + (" " * ($len - $e.name.length + $breather - 1))
          write-host $newName -nonewline -foregroundcolor cyan
      }
      elseif ($newName -match "^\..*$") {
          #hidden files
          write-host $newName -nonewline -foregroundcolor darkgray
      }
      elseif ($newName -match "\.[^\.]*") {
          #normal files
          write-host $newName -nonewline -foregroundcolor darkyellow
      }
      else {
          #others...
          write-host $newName -nonewline -foregroundcolor gray
      }

      if ( $count -ge ($bufferwidth - ($len + $breather)) ) {
          write-host ""
          $count = 0
      }
  }

  write-host "" # add newline at bottom
  write-host "" # add newline at bottom
}

Function findFolder($folderName) {
  $basicDrive = $null;

  foreach ($drive in "~", "C:", "D:") {
      if (Test-Path "$drive/$folderName") {
          $basicDrive = $drive;

          break;
      }
  }

  if ($basicDrive -ne $null) {
      return "$basicDrive/$folderName";
  }

  if ($isNotWindows) {
      function searchTopFolder($folderName) {
          $drivePath = $null;

          if (Test-Path $folderName) {
              # Using foreach here instead of piping to %, because breaking in a % pipe stops the function itself, not the %.
              foreach ($drive in gci "/media/$username") {
                  if (Test-Path "$($drive.FullName)/$folderName") {
                      $drivePath = $drive.FullName;

                      break;
                  }
              }

              if ($drivePath -ne $null) {
                  return "$drivePath/$folderName";
              }
          }

          return $null;
      }

      return ?? (searchTopFolder "/media/$username") (searchTopFolder "/mnt")
  }

  # Don't set the value if it wasn't found.
  return $null;
}

Function temp { cd c:\temp }

Function docs { cd "${env:HOMEPATH}\documents" }

Function dt { cd "${env:HOMEPATH}\desktop" }

Function home { cd $home}

Function psd { cd "${env:HOMEPATH}$docFolder" }

Function rmd { rm -force -recurse $args}

# Easily install new cmdlets
Function InstallSnapIn([string]$dll, [string]$snapin) {
  $path = Get-Location;
  $assembly = $path.Path + "\" + $dll;
  elevate-Process $installUtil $assembly | Out-Null;
  Add-PSSnapin $snapin | Out-Null;
  Get-PSSnapin $snapin;
}

${function:u} = { cd .. }
${function:...} = { cd ..\.. }
${function:....} = { cd ..\..\.. }
${function:.....} = { cd ..\..\..\.. }
${function:......} = { cd ..\..\..\..\.. }
${function:.......} = { cd ..\..\..\..\..\.. }

# START ALIASES DEFINITION
Set-Alias gma -Value Get-MyAliases
Set-Alias gmc -Value Get-MyCommands
Set-Alias c -Value clear
Set-Alias d -Value Delta
Set-Alias a -Value Azure
Set-Alias e -Value Exo
Set-Alias modp -Value Get-psmodulePath
Set-Alias rl -Value reloadProfile
Set-Alias ff -Value findFile
Set-Alias ffo -Value findFolder
Set-Alias Unzip -Value unarchive
Set-Alias ut -Value uptime
Set-Alias sudo -Value elevate-Process
Set-Alias pls -Value powerls
Set-Alias isi -Value InstallSnapIn
