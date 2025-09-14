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

function Test-HostnameValid {
    <#
    .SYNOPSIS
        Validates if a hostname is valid according to Windows naming rules.
    #>
    param([string]$Hostname)
    
    # Windows hostname rules:
    # - Must be 1-15 characters
    # - Can contain letters, numbers, and hyphens
    # - Cannot start or end with hyphen
    # - Cannot contain special characters
    
    if ([string]::IsNullOrWhiteSpace($Hostname)) {
        return $false
    }
    
    if ($Hostname.Length -gt 15) {
        return $false
    }
    
    if ($Hostname -match '^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$') {
        return $true
    }
    
    return $false
}

function Set-ComputerHostname {
    <#
    .SYNOPSIS
        Sets the computer hostname.
    #>
    param([string]$NewHostname)
    
    # Validate hostname
    if (-not (Test-HostnameValid $NewHostname)) {
        throw "Invalid hostname: '$NewHostname'. Hostname must be 1-15 characters, contain only letters, numbers, and hyphens, and not start or end with hyphen."
    }
    
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

function Test-IPAddress {
    <#
    .SYNOPSIS
        Validates if a string is a valid IP address.
    #>
    param([string]$IPAddress)
    
    try {
        $null = [System.Net.IPAddress]::Parse($IPAddress)
        return $true
    } catch {
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
    
    # Validate IP addresses
    if (-not (Test-IPAddress $IPAddress)) {
        throw "Invalid IP address format: $IPAddress"
    }
    if (-not (Test-IPAddress $SubnetMask)) {
        throw "Invalid subnet mask format: $SubnetMask"
    }
    if ($Gateway -and -not (Test-IPAddress $Gateway)) {
        throw "Invalid gateway address format: $Gateway"
    }
    if ($DNSServer -and -not (Test-IPAddress $DNSServer)) {
        throw "Invalid DNS server address format: $DNSServer"
    }
    
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
            
            # Convert PSCustomObject to hashtable and validate values
            $config.PSObject.Properties | ForEach-Object {
                if ($_.Name -notlike "_*") {  # Skip metadata fields
                    $value = $_.Value
                    if (-not [string]::IsNullOrWhiteSpace($value)) {
                        # Validate hostname
                        if ($_.Name -eq "hostname" -and -not (Test-HostnameValid $value)) {
                            Write-BootstrapWarning "Invalid hostname in config file: '$value'. Will prompt for valid hostname."
                        }
                        # Validate IP addresses
                        elseif ($_.Name -in @("ipAddress", "gateway", "dnsServer", "subnetMask") -and -not (Test-IPAddress $value)) {
                            Write-BootstrapWarning "Invalid IP address in config file for $($_.Name): '$value'. Will prompt for valid address."
                        }
                        else {
                            $networkConfig[$_.Name] = $value
                        }
                    }
                }
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
        do {
            $hostname = Read-Host "Enter new hostname (current: $currentHostname, ENTER to skip)"
            if ([string]::IsNullOrWhiteSpace($hostname)) {
                break
            }
            if (Test-HostnameValid $hostname) {
                $networkConfig["hostname"] = $hostname
                break
            } else {
                Write-BootstrapWarning "Invalid hostname. Must be 1-15 characters, letters/numbers/hyphens only, cannot start/end with hyphen."
            }
        } while ($true)
    }
    
    # Static IP configuration
    Write-Host "`nStatic IP Configuration:" -ForegroundColor Yellow
    Write-Host "Leave all fields empty to keep current DHCP configuration" -ForegroundColor Gray
    
    if (-not $networkConfig.ContainsKey("ipAddress") -or [string]::IsNullOrWhiteSpace($networkConfig["ipAddress"])) {
        do {
            $ipAddress = Read-Host "Enter static IP address (e.g., 192.168.1.100, ENTER to skip)"
            if ([string]::IsNullOrWhiteSpace($ipAddress)) {
                break
            }
            if (Test-IPAddress $ipAddress) {
                $networkConfig["ipAddress"] = $ipAddress
                
                # Get subnet mask
                if (-not $networkConfig.ContainsKey("subnetMask") -or [string]::IsNullOrWhiteSpace($networkConfig["subnetMask"])) {
                    do {
                        $subnetMask = Read-Host "Enter subnet mask (default: 255.255.255.0, ENTER for default)"
                        if ([string]::IsNullOrWhiteSpace($subnetMask)) {
                            $networkConfig["subnetMask"] = "255.255.255.0"
                            break
                        }
                        if (Test-IPAddress $subnetMask) {
                            $networkConfig["subnetMask"] = $subnetMask
                            break
                        } else {
                            Write-BootstrapWarning "Invalid subnet mask format. Please enter a valid IP address format (e.g., 255.255.255.0)."
                        }
                    } while ($true)
                }
                
                # Get gateway
                if (-not $networkConfig.ContainsKey("gateway") -or [string]::IsNullOrWhiteSpace($networkConfig["gateway"])) {
                    do {
                        $gateway = Read-Host "Enter gateway address (e.g., 192.168.1.1)"
                        if ([string]::IsNullOrWhiteSpace($gateway)) {
                            Write-BootstrapWarning "Gateway is required for static IP configuration."
                        } elseif (Test-IPAddress $gateway) {
                            $networkConfig["gateway"] = $gateway
                            break
                        } else {
                            Write-BootstrapWarning "Invalid gateway address format. Please enter a valid IP address."
                        }
                    } while ($true)
                }
                
                # Get DNS server
                if (-not $networkConfig.ContainsKey("dnsServer") -or [string]::IsNullOrWhiteSpace($networkConfig["dnsServer"])) {
                    do {
                        $dnsServer = Read-Host "Enter DNS server address (e.g., 8.8.8.8, ENTER to skip)"
                        if ([string]::IsNullOrWhiteSpace($dnsServer)) {
                            break
                        }
                        if (Test-IPAddress $dnsServer) {
                            $networkConfig["dnsServer"] = $dnsServer
                            break
                        } else {
                            Write-BootstrapWarning "Invalid DNS server address format. Please enter a valid IP address."
                        }
                    } while ($true)
                }
                break
            } else {
                Write-BootstrapWarning "Invalid IP address format. Please enter a valid IP address (e.g., 192.168.1.100)."
            }
        } while ($true)
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