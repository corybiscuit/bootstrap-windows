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

.PARAMETER ConfigPath
    Path to custom configuration files directory (default: ./config)

.EXAMPLE
    .\bootstrap.ps1
    Run interactive bootstrap with prompts for component selection

.EXAMPLE
    .\bootstrap.ps1 -ConfigPath "C:\custom\config"
    Run bootstrap with custom configuration path
#>

param(
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

    # Interactive component selection
    Write-BootstrapInfo "`nBootstrap Component Selection"
    Write-Host "This bootstrap can install the following components:" -ForegroundColor White
    Write-Host "  1. Scoop - CLI-based applications (git, node, python, docker, etc.)" -ForegroundColor Gray
    Write-Host "  2. WinGet - GUI applications (browsers, productivity tools, etc.)" -ForegroundColor Gray
    Write-Host ""
    
    # Ask about Scoop
    $installScoop = $true
    $scoopResponse = Read-Host "Install Scoop and CLI applications? (Y/n)"
    if ($scoopResponse -like "n*") {
        $installScoop = $false
        Write-BootstrapInfo "Scoop installation will be skipped"
    }
    
    # Ask about WinGet
    $installWinGet = $true
    $wingetResponse = Read-Host "Install WinGet and GUI applications? (Y/n)"
    if ($wingetResponse -like "n*") {
        $installWinGet = $false
        Write-BootstrapInfo "WinGet installation will be skipped"
    }
    
    Write-Host ""

    # Install and configure Scoop (CLI applications)
    if ($installScoop) {
        Write-BootstrapInfo "Setting up Scoop and CLI applications..."
        & ".\scripts\setup-scoop.ps1" -ConfigPath $ConfigPath
        if ($LASTEXITCODE -ne 0) {
            throw "Scoop setup failed with exit code $LASTEXITCODE"
        }
    } else {
        Write-BootstrapInfo "Skipping Scoop setup as requested"
    }

    # Install and configure WinGet (GUI applications)
    if ($installWinGet) {
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