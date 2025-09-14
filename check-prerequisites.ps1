<#
.SYNOPSIS
    Checks system prerequisites for the Windows bootstrap process.

.DESCRIPTION
    This script verifies that the system meets all requirements for running
    the bootstrap scripts, without making any changes to the system.
#>

# Import utility functions
. ".\scripts\utilities.ps1"

Write-BootstrapHeader "Prerequisites Check"

$ChecksPassed = 0
$ChecksFailed = 0

function Test-Requirement {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [string]$SuccessMessage,
        [string]$FailureMessage,
        [string]$Recommendation = ""
    )
    
    try {
        $result = & $Test
        if ($result) {
            Write-BootstrapSuccess "✓ $Name`: $SuccessMessage"
            return $true
        } else {
            Write-BootstrapError "✗ $Name`: $FailureMessage"
            if ($Recommendation) {
                Write-BootstrapInfo "  Recommendation: $Recommendation"
            }
            return $false
        }
    } catch {
        Write-BootstrapError "✗ $Name`: $FailureMessage - $($_.Exception.Message)"
        if ($Recommendation) {
            Write-BootstrapInfo "  Recommendation: $Recommendation"
        }
        return $false
    }
}

# Check PowerShell version
if (Test-Requirement "PowerShell Version" {
    $PSVersionTable.PSVersion.Major -ge 5
} "Version $($PSVersionTable.PSVersion) (OK)" "Version $($PSVersionTable.PSVersion) is too old" "Install PowerShell 5.0 or higher") {
    $ChecksPassed++
} else {
    $ChecksFailed++
}

# Check if running as Administrator
if (Test-Requirement "Administrator Rights" {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} "Running as Administrator" "Not running as Administrator" "Right-click PowerShell and select 'Run as Administrator'") {
    $ChecksPassed++
} else {
    $ChecksFailed++
}

# Check execution policy
if (Test-Requirement "Execution Policy" {
    $policy = Get-ExecutionPolicy -Scope CurrentUser
    $policy -in @("RemoteSigned", "Unrestricted", "Bypass")
} "Policy allows script execution ($((Get-ExecutionPolicy -Scope CurrentUser)))" "Policy restricts script execution ($((Get-ExecutionPolicy -Scope CurrentUser)))" "Run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser") {
    $ChecksPassed++
} else {
    $ChecksFailed++
}

# Check internet connectivity
if (Test-Requirement "Internet Connectivity" {
    try {
        $null = Invoke-WebRequest -Uri "https://www.microsoft.com" -UseBasicParsing -TimeoutSec 10
        $true
    } catch {
        $false
    }
} "Internet connection available" "No internet connection" "Check your network connection") {
    $ChecksPassed++
} else {
    $ChecksFailed++
}

# Check Windows version
if (Test-Requirement "Windows Version" {
    $version = [System.Environment]::OSVersion.Version
    ($version.Major -eq 10 -and $version.Build -ge 17763) -or $version.Major -gt 10
} "Windows version compatible" "Windows version may not be fully supported" "Windows 10 version 1809+ or Windows 11 recommended") {
    $ChecksPassed++
} else {
    $ChecksFailed++
}

# Check available disk space (at least 5GB recommended)
if (Test-Requirement "Disk Space" {
    $drive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
    $freeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
    Write-Host "  Free space on C: drive: $freeSpaceGB GB" -ForegroundColor Gray
    $freeSpaceGB -gt 5
} "Sufficient disk space available" "Low disk space (less than 5GB free)" "Free up disk space before running bootstrap") {
    $ChecksPassed++
} else {
    $ChecksFailed++
}

# Check if WinGet is available
$wingetAvailable = Test-CommandExists "winget"
if (Test-Requirement "WinGet Availability" {
    $wingetAvailable
} "WinGet is available" "WinGet not found" "Install 'App Installer' from Microsoft Store or run Windows Update") {
    $ChecksPassed++
} else {
    $ChecksFailed++
}

# Optional: Check if Scoop is already installed
$scoopInstalled = Test-CommandExists "scoop"
if ($scoopInstalled) {
    Write-BootstrapInfo "ℹ Scoop is already installed"
} else {
    Write-BootstrapInfo "ℹ Scoop will be installed during bootstrap"
}

# Summary
Write-BootstrapHeader "Prerequisites Summary"

Write-BootstrapInfo "Checks passed: $ChecksPassed"
if ($ChecksFailed -gt 0) {
    Write-BootstrapError "Checks failed: $ChecksFailed"
    Write-BootstrapInfo "`nPlease address the failed checks before running the bootstrap script."
    Write-BootstrapInfo "Once resolved, run: .\bootstrap.ps1"
} else {
    Write-BootstrapSuccess "All prerequisites met! You can now run the bootstrap script."
    Write-BootstrapInfo "`nTo start the bootstrap process, run: .\bootstrap.ps1"
}

Write-BootstrapInfo "`nFor help and options, run: Get-Help .\bootstrap.ps1 -Full"