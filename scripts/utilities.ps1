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

function Show-CategoryMenu {
    <#
    .SYNOPSIS
        Shows a menu for selecting application categories.
    #>
    param(
        $Categories,  # Changed from [hashtable] to accept PSCustomObject too
        [string]$PackageManager
    )
    
    Write-Host "`n$PackageManager Application Categories:" -ForegroundColor $Colors.Header
    Write-Host "Select which categories to install (multiple selections allowed):" -ForegroundColor $Colors.Info
    Write-Host ""
    
    # Handle both hashtable and PSCustomObject
    $categoryKeys = if ($Categories -is [hashtable]) {
        @($Categories.Keys)
    } else {
        @($Categories.PSObject.Properties.Name)
    }
    
    for ($i = 0; $i -lt $categoryKeys.Count; $i++) {
        $category = $categoryKeys[$i]
        $apps = if ($Categories -is [hashtable]) {
            $Categories[$category]
        } else {
            $Categories.$category
        }
        $appCount = $apps.Count
        Write-Host "  $($i + 1). $category ($appCount apps)" -ForegroundColor White
    }
    Write-Host "  0. Skip all categories" -ForegroundColor Gray
    Write-Host ""
    
    return $categoryKeys
}

function Get-CategorySelection {
    <#
    .SYNOPSIS
        Gets user selection for categories to install.
    #>
    param(
        [string[]]$CategoryKeys
    )
    
    do {
        $input = Read-Host "Enter category numbers (comma-separated, e.g., 1,3,4) or 0 to skip"
        $input = $input.Trim()
        
        if ($input -eq "0") {
            return @()
        }
        
        $selectedIndices = @()
        $valid = $true
        
        if ($input -ne "") {
            $numbers = $input -split "," | ForEach-Object { $_.Trim() }
            foreach ($num in $numbers) {
                if ($num -match '^\d+$' -and [int]$num -ge 1 -and [int]$num -le $CategoryKeys.Count) {
                    $selectedIndices += [int]$num - 1
                } else {
                    Write-Host "Invalid selection: $num. Please use numbers 1-$($CategoryKeys.Count) or 0." -ForegroundColor $Colors.Warning
                    $valid = $false
                    break
                }
            }
        } else {
            Write-Host "Please enter at least one category number or 0 to skip." -ForegroundColor $Colors.Warning
            $valid = $false
        }
    } while (-not $valid)
    
    return $selectedIndices | Sort-Object -Unique
}

function Show-CategoryApps {
    <#
    .SYNOPSIS
        Shows applications in a specific category and allows user to modify selection.
    #>
    param(
        [string]$CategoryName,
        [array]$Apps,
        [string]$PackageManager
    )
    
    Write-Host "`n$CategoryName Applications ($PackageManager):" -ForegroundColor $Colors.Header
    
    if ($Apps.Count -eq 0) {
        Write-Host "  No applications in this category." -ForegroundColor Gray
        return @()
    }
    
    # Display apps with numbers
    for ($i = 0; $i -lt $Apps.Count; $i++) {
        $app = $Apps[$i]
        if ($PackageManager -eq "WinGet" -and $app -is [PSCustomObject]) {
            Write-Host "  $($i + 1). $($app.name) ($($app.id))" -ForegroundColor White
        } else {
            Write-Host "  $($i + 1). $app" -ForegroundColor White
        }
    }
    
    Write-Host ""
    Write-Host "Options:" -ForegroundColor $Colors.Info
    Write-Host "  Press ENTER to install all applications" -ForegroundColor Gray
    Write-Host "  Type numbers to EXCLUDE (comma-separated, e.g., 1,3)" -ForegroundColor Gray
    Write-Host "  Type 'skip' to skip this entire category" -ForegroundColor Gray
    
    do {
        $input = Read-Host "Your choice"
        $input = $input.Trim().ToLower()
        
        if ($input -eq "" -or $input -eq "all") {
            return $Apps
        } elseif ($input -eq "skip") {
            return @()
        } else {
            # Parse exclusions
            $excludeIndices = @()
            $valid = $true
            
            $numbers = $input -split "," | ForEach-Object { $_.Trim() }
            foreach ($num in $numbers) {
                if ($num -match '^\d+$' -and [int]$num -ge 1 -and [int]$num -le $Apps.Count) {
                    $excludeIndices += [int]$num - 1
                } else {
                    Write-Host "Invalid selection: $num. Please use numbers 1-$($Apps.Count), ENTER, or 'skip'." -ForegroundColor $Colors.Warning
                    $valid = $false
                    break
                }
            }
            
            if ($valid) {
                $selectedApps = @()
                for ($i = 0; $i -lt $Apps.Count; $i++) {
                    if ($i -notin $excludeIndices) {
                        $selectedApps += $Apps[$i]
                    }
                }
                return $selectedApps
            }
        }
    } while ($true)
}

function Get-SelectedCategories {
    <#
    .SYNOPSIS
        Interactive function to get user's category and app selections.
    #>
    param(
        $AllCategories,  # Changed from [hashtable] to accept PSCustomObject too
        [string]$PackageManager
    )
    
    $selectedCategories = @{}
    
    # Show category menu and get selection
    $categoryKeys = Show-CategoryMenu -Categories $AllCategories -PackageManager $PackageManager
    $selectedIndices = Get-CategorySelection -CategoryKeys $categoryKeys
    
    if ($selectedIndices.Count -eq 0) {
        Write-BootstrapInfo "No categories selected for $PackageManager"
        return @{}
    }
    
    # For each selected category, show apps and get refined selection
    foreach ($index in $selectedIndices) {
        $categoryName = $categoryKeys[$index]
        $apps = if ($AllCategories -is [hashtable]) {
            $AllCategories[$categoryName]
        } else {
            $AllCategories.$categoryName
        }
        
        $selectedApps = Show-CategoryApps -CategoryName $categoryName -Apps $apps -PackageManager $PackageManager
        
        if ($selectedApps.Count -gt 0) {
            $selectedCategories[$categoryName] = $selectedApps
            Write-BootstrapSuccess "Selected $($selectedApps.Count) apps from $categoryName category"
        } else {
            Write-BootstrapInfo "Skipped $categoryName category"
        }
    }
    
    return $selectedCategories
}