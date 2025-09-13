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
    }

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

} catch {
    Write-BootstrapError "Bootstrap failed: $($_.Exception.Message)"
    exit 1
}