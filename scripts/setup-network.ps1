#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Network configuration script for Windows bootstrap process.

.DESCRIPTION
    This script configures network settings including:
    - Hostname
    - Static IP address
    - DNS server
    - Gateway address

.PARAMETER ConfigPath
    Path to configuration files directory (default: ./config)

.PARAMETER SelectedSettings
    Hashtable of selected network settings to configure

.EXAMPLE
    .\setup-network.ps1
    Run interactive network configuration

.EXAMPLE
    .\setup-network.ps1 -ConfigPath "C:\custom\config"
    Run network configuration with custom config path
#>

param(
    [string]$ConfigPath = ".\config",
    [hashtable]$SelectedSettings = @{}
)

# Import utility functions
. ".\utilities.ps1"

Write-BootstrapHeader "Network Configuration Setup"

function Set-ComputerHostname {
    <#
    .SYNOPSIS
        Sets the computer hostname.
    #>
    param([string]$NewHostname)
    
    try {
        $currentHostname = $env:COMPUTERNAME
        if ($currentHostname -eq $NewHostname) {
            Write-BootstrapInfo "Hostname is already set to: $NewHostname"
            return $true
        }
        
        Write-BootstrapInfo "Setting hostname from '$currentHostname' to '$NewHostname'..."
        Rename-Computer -NewName $NewHostname -Force
        Write-BootstrapSuccess "Hostname set to: $NewHostname (restart required)"
        return $true
    } catch {
        Write-BootstrapError "Failed to set hostname: $($_.Exception.Message)"
        return $false
    }
}

function Set-StaticIPConfiguration {
    <#
    .SYNOPSIS
        Sets static IP configuration for the primary network adapter.
    #>
    param(
        [string]$IPAddress,
        [string]$SubnetMask = "255.255.255.0",
        [string]$Gateway,
        [string]$DNSServer
    )
    
    try {
        # Get the primary network adapter
        $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.PhysicalMediaType -eq "802.3" } | Select-Object -First 1
        
        if (-not $adapter) {
            Write-BootstrapWarning "No active Ethernet adapter found. Checking for any active adapter..."
            $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
        }
        
        if (-not $adapter) {
            throw "No active network adapter found"
        }
        
        Write-BootstrapInfo "Configuring network adapter: $($adapter.Name)"
        
        # Remove existing IP configuration
        Remove-NetIPAddress -InterfaceAlias $adapter.Name -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute -InterfaceAlias $adapter.Name -Confirm:$false -ErrorAction SilentlyContinue
        
        # Calculate prefix length from subnet mask
        $prefixLength = switch ($SubnetMask) {
            "255.255.255.0" { 24 }
            "255.255.0.0" { 16 }
            "255.0.0.0" { 8 }
            default { 24 }
        }
        
        # Set static IP address
        Write-BootstrapInfo "Setting IP address: $IPAddress/$prefixLength"
        New-NetIPAddress -InterfaceAlias $adapter.Name -IPAddress $IPAddress -PrefixLength $prefixLength -DefaultGateway $Gateway
        
        # Set DNS server
        if ($DNSServer) {
            Write-BootstrapInfo "Setting DNS server: $DNSServer"
            Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses $DNSServer
        }
        
        Write-BootstrapSuccess "Static IP configuration applied successfully"
        Write-BootstrapInfo "  IP Address: $IPAddress"
        Write-BootstrapInfo "  Subnet Mask: $SubnetMask"
        Write-BootstrapInfo "  Gateway: $Gateway"
        if ($DNSServer) {
            Write-BootstrapInfo "  DNS Server: $DNSServer"
        }
        
        return $true
    } catch {
        Write-BootstrapError "Failed to set static IP configuration: $($_.Exception.Message)"
        return $false
    }
}

function Get-NetworkSettings {
    <#
    .SYNOPSIS
        Gets network settings from configuration file or user input.
    #>
    param([string]$ConfigPath)
    
    $networkConfig = @{}
    $configFile = Join-Path $ConfigPath "network-config.json"
    
    # Try to load from config file first
    if (Test-Path $configFile) {
        try {
            $config = Get-Content $configFile | ConvertFrom-Json
            Write-BootstrapInfo "Loaded network configuration from: $configFile"
            
            # Convert PSCustomObject to hashtable
            $config.PSObject.Properties | ForEach-Object {
                $networkConfig[$_.Name] = $_.Value
            }
        } catch {
            Write-BootstrapWarning "Failed to read network configuration file: $($_.Exception.Message)"
        }
    }
    
    # Interactive prompts for missing settings
    Write-BootstrapInfo "`nNetwork Configuration Setup"
    Write-Host "Configure network settings for this device. Press ENTER to skip any setting." -ForegroundColor White
    Write-Host ""
    
    # Hostname configuration
    if (-not $networkConfig.ContainsKey("hostname") -or [string]::IsNullOrWhiteSpace($networkConfig["hostname"])) {
        $currentHostname = $env:COMPUTERNAME
        $hostname = Read-Host "Enter new hostname (current: $currentHostname, ENTER to skip)"
        if (-not [string]::IsNullOrWhiteSpace($hostname)) {
            $networkConfig["hostname"] = $hostname
        }
    }
    
    # Static IP configuration
    Write-Host "`nStatic IP Configuration:" -ForegroundColor Yellow
    Write-Host "Leave all fields empty to keep current DHCP configuration" -ForegroundColor Gray
    
    if (-not $networkConfig.ContainsKey("ipAddress") -or [string]::IsNullOrWhiteSpace($networkConfig["ipAddress"])) {
        $ipAddress = Read-Host "Enter static IP address (e.g., 192.168.1.100, ENTER to skip)"
        if (-not [string]::IsNullOrWhiteSpace($ipAddress)) {
            $networkConfig["ipAddress"] = $ipAddress
            
            # Get subnet mask
            if (-not $networkConfig.ContainsKey("subnetMask") -or [string]::IsNullOrWhiteSpace($networkConfig["subnetMask"])) {
                $subnetMask = Read-Host "Enter subnet mask (default: 255.255.255.0, ENTER for default)"
                $networkConfig["subnetMask"] = if ([string]::IsNullOrWhiteSpace($subnetMask)) { "255.255.255.0" } else { $subnetMask }
            }
            
            # Get gateway
            if (-not $networkConfig.ContainsKey("gateway") -or [string]::IsNullOrWhiteSpace($networkConfig["gateway"])) {
                $gateway = Read-Host "Enter gateway address (e.g., 192.168.1.1)"
                if (-not [string]::IsNullOrWhiteSpace($gateway)) {
                    $networkConfig["gateway"] = $gateway
                }
            }
            
            # Get DNS server
            if (-not $networkConfig.ContainsKey("dnsServer") -or [string]::IsNullOrWhiteSpace($networkConfig["dnsServer"])) {
                $dnsServer = Read-Host "Enter DNS server address (e.g., 8.8.8.8, ENTER to skip)"
                if (-not [string]::IsNullOrWhiteSpace($dnsServer)) {
                    $networkConfig["dnsServer"] = $dnsServer
                }
            }
        }
    }
    
    return $networkConfig
}

function Show-CurrentNetworkConfig {
    <#
    .SYNOPSIS
        Shows current network configuration.
    #>
    Write-BootstrapInfo "Current Network Configuration:"
    
    try {
        # Show hostname
        Write-Host "  Hostname: $env:COMPUTERNAME" -ForegroundColor White
        
        # Show IP configuration for active adapters
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        foreach ($adapter in $adapters) {
            Write-Host "  Adapter: $($adapter.Name)" -ForegroundColor Yellow
            
            $ipConfig = Get-NetIPAddress -InterfaceAlias $adapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if ($ipConfig) {
                Write-Host "    IP Address: $($ipConfig.IPAddress)/$($ipConfig.PrefixLength)" -ForegroundColor White
                
                $gateway = Get-NetRoute -InterfaceAlias $adapter.Name -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue
                if ($gateway) {
                    Write-Host "    Gateway: $($gateway.NextHop)" -ForegroundColor White
                }
                
                $dns = Get-DnsClientServerAddress -InterfaceAlias $adapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue
                if ($dns -and $dns.ServerAddresses) {
                    Write-Host "    DNS Servers: $($dns.ServerAddresses -join ', ')" -ForegroundColor White
                }
            }
        }
    } catch {
        Write-BootstrapWarning "Could not retrieve current network configuration: $($_.Exception.Message)"
    }
    
    Write-Host ""
}

# Main execution
try {
    # Show current configuration
    Show-CurrentNetworkConfig
    
    # Get network settings (from config file or user input)
    $networkSettings = if ($SelectedSettings.Count -gt 0) { $SelectedSettings } else { Get-NetworkSettings -ConfigPath $ConfigPath }
    
    if ($networkSettings.Count -eq 0) {
        Write-BootstrapInfo "No network configuration changes requested"
        return
    }
    
    $requiresRestart = $false
    
    # Configure hostname
    if ($networkSettings.ContainsKey("hostname") -and -not [string]::IsNullOrWhiteSpace($networkSettings["hostname"])) {
        if (Set-ComputerHostname -NewHostname $networkSettings["hostname"]) {
            $requiresRestart = $true
        }
    }
    
    # Configure static IP
    if ($networkSettings.ContainsKey("ipAddress") -and -not [string]::IsNullOrWhiteSpace($networkSettings["ipAddress"])) {
        $ipParams = @{
            IPAddress = $networkSettings["ipAddress"]
        }
        
        if ($networkSettings.ContainsKey("subnetMask")) {
            $ipParams["SubnetMask"] = $networkSettings["subnetMask"]
        }
        if ($networkSettings.ContainsKey("gateway")) {
            $ipParams["Gateway"] = $networkSettings["gateway"]
        }
        if ($networkSettings.ContainsKey("dnsServer")) {
            $ipParams["DNSServer"] = $networkSettings["dnsServer"]
        }
        
        Set-StaticIPConfiguration @ipParams
    }
    
    Write-BootstrapSuccess "Network configuration completed successfully!"
    
    if ($requiresRestart) {
        Write-BootstrapWarning "A system restart is required for hostname changes to take effect."
    }
    
} catch {
    Write-BootstrapError "Network configuration failed: $($_.Exception.Message)"
    exit 1
}