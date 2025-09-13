#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Bootstrap script for configuring and installing applications on a new Windows instance.

.DESCRIPTION
    This script automates the setup of a new Windows machine by:
    - Installing Scoop for CLI-based applications
    - Installing WinGet for GUI-based applications
    - Installing predefined sets of applications
    - Configuring basic system settings

.PARAMETER SkipScoop
    Skip Scoop installation and CLI applications

.PARAMETER SkipWinGet
    Skip WinGet installation and GUI applications

.PARAMETER ConfigPath
    Path to custom configuration files directory (default: ./config)

.EXAMPLE
    .\bootstrap.ps1
    Run full bootstrap with default settings

.EXAMPLE
    .\bootstrap.ps1 -SkipScoop
    Run bootstrap but skip Scoop and CLI applications

.EXAMPLE
    .\bootstrap.ps1 -ConfigPath "C:\custom\config"
    Run bootstrap with custom configuration path
#>

param(
    [switch]$SkipScoop,
    [switch]$SkipWinGet,
    [string]$ConfigPath = ".\config"
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Import utility functions
. ".\scripts\utilities.ps1"

Write-BootstrapHeader "Windows Bootstrap Script"

try {
    # Check prerequisites
    Write-BootstrapInfo "Checking prerequisites..."
    Test-Prerequisites

    # Create logs directory
    $LogDir = ".\logs"
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
        Write-BootstrapInfo "Created logs directory: $LogDir"
    }
    
    # Start logging
    $LogFile = Join-Path $LogDir "bootstrap-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    Start-Transcript -Path $LogFile -Append

    # Install and configure Scoop (CLI applications)
    if (-not $SkipScoop) {
        Write-BootstrapInfo "Setting up Scoop and CLI applications..."
        & ".\scripts\setup-scoop.ps1" -ConfigPath $ConfigPath
        if ($LASTEXITCODE -ne 0) {
            throw "Scoop setup failed with exit code $LASTEXITCODE"
        }
    } else {
        Write-BootstrapInfo "Skipping Scoop setup as requested"
    }

    # Install and configure WinGet (GUI applications)
    if (-not $SkipWinGet) {
        Write-BootstrapInfo "Setting up WinGet and GUI applications..."
        & ".\scripts\setup-winget.ps1" -ConfigPath $ConfigPath
        if ($LASTEXITCODE -ne 0) {
            throw "WinGet setup failed with exit code $LASTEXITCODE"
        }
    } else {
        Write-BootstrapInfo "Skipping WinGet setup as requested"
    }

    Write-BootstrapSuccess "Bootstrap completed successfully!"
    Write-BootstrapInfo "You may need to restart your computer to complete some installations."
    
    # Offer to setup PowerShell profile
    Write-BootstrapInfo "`nOptional: Would you like to setup a PowerShell profile with useful aliases and functions?"
    $response = Read-Host "Setup PowerShell profile? (Y/n)"
    if ($response -notlike "n*") {
        try {
            & ".\scripts\setup-profile.ps1"
        } catch {
            Write-BootstrapWarning "Profile setup failed, but this doesn't affect the main bootstrap"
        }
    }
    
    # Stop logging
    Stop-Transcript
    Write-BootstrapInfo "Full log saved to: $LogFile"

} catch {
    Write-BootstrapError "Bootstrap failed: $($_.Exception.Message)"
    
    # Stop logging even on error
    try { Stop-Transcript } catch { }
    
    exit 1
}