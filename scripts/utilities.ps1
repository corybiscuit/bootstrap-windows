<#
.SYNOPSIS
    Utility functions for the Windows bootstrap process.

.DESCRIPTION
    Contains common functions used across the bootstrap scripts including
    logging, error handling, and system checks.
#>

# Color definitions for console output
$Colors = @{
    Header  = "Cyan"
    Info    = "White"
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
}

function Write-BootstrapHeader {
    param([string]$Message)
    Write-Host "`n" + ("=" * 60) -ForegroundColor $Colors.Header
    Write-Host $Message.ToUpper().PadLeft((60 + $Message.Length) / 2) -ForegroundColor $Colors.Header
    Write-Host ("=" * 60) + "`n" -ForegroundColor $Colors.Header
}

function Write-BootstrapInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Colors.Info
}

function Write-BootstrapSuccess {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $Colors.Success
}

function Write-BootstrapWarning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Colors.Warning
}

function Write-BootstrapError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Colors.Error
}

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Tests system prerequisites for the bootstrap process.
    #>
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        throw "PowerShell 5.0 or higher is required. Current version: $($PSVersionTable.PSVersion)"
    }
    
    # Check if running as Administrator
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script must be run as Administrator"
    }
    
    # Check internet connectivity
    try {
        $null = Invoke-WebRequest -Uri "https://www.microsoft.com" -UseBasicParsing -TimeoutSec 10
    } catch {
        throw "Internet connectivity is required but not available"
    }
    
    Write-BootstrapSuccess "All prerequisites met"
}

function Test-CommandExists {
    <#
    .SYNOPSIS
        Tests if a command exists in the system PATH.
    #>
    param([string]$Command)
    
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Wait-ForProcess {
    <#
    .SYNOPSIS
        Waits for a process to complete with timeout.
    #>
    param(
        [System.Diagnostics.Process]$Process,
        [int]$TimeoutSeconds = 300
    )
    
    if (-not $Process.WaitForExit($TimeoutSeconds * 1000)) {
        $Process.Kill()
        throw "Process timed out after $TimeoutSeconds seconds"
    }
}

function New-DesktopShortcut {
    <#
    .SYNOPSIS
        Creates a desktop shortcut.
    #>
    param(
        [string]$Name,
        [string]$TargetPath,
        [string]$Arguments = "",
        [string]$Description = ""
    )
    
    $WshShell = New-Object -ComObject WScript.Shell
    $DesktopPath = [Environment]::GetFolderPath("Desktop")
    $ShortcutPath = Join-Path $DesktopPath "$Name.lnk"
    
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $TargetPath
    $Shortcut.Arguments = $Arguments
    $Shortcut.Description = $Description
    $Shortcut.Save()
    
    Write-BootstrapInfo "Created desktop shortcut: $Name"
}

function Add-ToEnvironmentPath {
    <#
    .SYNOPSIS
        Adds a path to the system or user PATH environment variable.
    #>
    param(
        [string]$Path,
        [string]$Scope = "User" # User or Machine
    )
    
    if (Test-Path $Path) {
        $CurrentPath = [Environment]::GetEnvironmentVariable("PATH", $Scope)
        if ($CurrentPath -notlike "*$Path*") {
            $NewPath = "$CurrentPath;$Path"
            [Environment]::SetEnvironmentVariable("PATH", $NewPath, $Scope)
            Write-BootstrapInfo "Added to PATH: $Path"
        }
    }
}