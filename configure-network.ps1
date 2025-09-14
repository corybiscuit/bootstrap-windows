#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Standalone network configuration script for Windows systems.

.DESCRIPTION
    This script provides a quick way to configure network settings without
    running the full bootstrap process. Configures hostname, static IP,
    DNS server, and gateway settings.

.PARAMETER ConfigPath
    Path to configuration files directory (default: ./config)

.EXAMPLE
    .\configure-network.ps1
    Run interactive network configuration

.EXAMPLE
    .\configure-network.ps1 -ConfigPath "C:\custom\config"
    Run network configuration with custom config path
#>

param(
    [string]$ConfigPath = ".\config"
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Import utility functions
. ".\scripts\utilities.ps1"

Write-BootstrapHeader "Windows Network Configuration"

try {
    # Check prerequisites
    Write-BootstrapInfo "Checking prerequisites..."
    Test-Prerequisites

    # Run network configuration
    Write-BootstrapInfo "Starting network configuration..."
    & ".\scripts\setup-network.ps1" -ConfigPath $ConfigPath
    
    if ($LASTEXITCODE -ne 0) {
        throw "Network configuration failed with exit code $LASTEXITCODE"
    }
    
    Write-BootstrapSuccess "Network configuration completed successfully!"
    Write-BootstrapInfo "You may need to restart your computer for hostname changes to take effect."

} catch {
    Write-BootstrapError "Network configuration failed: $($_.Exception.Message)"
    exit 1
}