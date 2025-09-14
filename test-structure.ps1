<#
.SYNOPSIS
    Test script to validate the bootstrap structure and configuration files.

.DESCRIPTION
    This script validates that all required files are present and configuration
    files are properly formatted without actually installing any applications.
#>

# Import utility functions
. ".\scripts\utilities.ps1"

Write-BootstrapHeader "Bootstrap Structure Test"

$TestsPassed = 0
$TestsFailed = 0

function Test-FileExists {
    param([string]$Path, [string]$Description)
    
    if (Test-Path $Path) {
        Write-BootstrapSuccess "✓ $Description exists: $Path"
        return $true
    } else {
        Write-BootstrapError "✗ $Description missing: $Path"
        return $false
    }
}

function Test-JsonFile {
    param([string]$Path, [string]$Description)
    
    if (-not (Test-Path $Path)) {
        Write-BootstrapError "✗ $Description missing: $Path"
        return $false
    }
    
    try {
        $content = Get-Content $Path | ConvertFrom-Json
        Write-BootstrapSuccess "✓ $Description is valid JSON: $Path"
        return $true
    } catch {
        Write-BootstrapError "✗ $Description has invalid JSON: $Path - $($_.Exception.Message)"
        return $false
    }
}

Write-BootstrapInfo "Testing file structure..."

# Test main files
$MainFiles = @(
    @{ Path = ".\bootstrap.ps1"; Description = "Main bootstrap script" },
    @{ Path = ".\README.md"; Description = "README file" },
    @{ Path = ".\scripts\utilities.ps1"; Description = "Utilities script" },
    @{ Path = ".\scripts\setup-scoop.ps1"; Description = "Scoop setup script" },
    @{ Path = ".\scripts\setup-winget.ps1"; Description = "WinGet setup script" },
    @{ Path = ".\scripts\setup-network.ps1"; Description = "Network configuration script" }
)

foreach ($file in $MainFiles) {
    if (Test-FileExists $file.Path $file.Description) {
        $TestsPassed++
    } else {
        $TestsFailed++
    }
}

# Test configuration files
$ConfigFiles = @(
    @{ Path = ".\config\scoop-apps.json"; Description = "Scoop applications config" },
    @{ Path = ".\config\winget-apps.json"; Description = "WinGet applications config" },
    @{ Path = ".\config\network-config.json"; Description = "Network configuration config" },
    @{ Path = ".\config\network-config.example.json"; Description = "Network configuration example" }
)

foreach ($config in $ConfigFiles) {
    if (Test-JsonFile $config.Path $config.Description) {
        $TestsPassed++
    } else {
        $TestsFailed++
    }
}

# Test directory structure
$Directories = @(
    @{ Path = ".\scripts"; Description = "Scripts directory" },
    @{ Path = ".\config"; Description = "Configuration directory" }
)

foreach ($dir in $Directories) {
    if (Test-FileExists $dir.Path $dir.Description) {
        $TestsPassed++
    } else {
        $TestsFailed++
    }
}

Write-BootstrapInfo "Testing configuration content..."

# Test Scoop apps configuration
try {
    $ScoopApps = Get-Content ".\config\scoop-apps.json" | ConvertFrom-Json
    $categories = $ScoopApps.PSObject.Properties.Name
    Write-BootstrapInfo "Scoop categories found: $($categories -join ', ')"
    
    $totalApps = 0
    foreach ($category in $categories) {
        $count = $ScoopApps.$category.Count
        $totalApps += $count
        Write-BootstrapInfo "  $category`: $count applications"
    }
    Write-BootstrapSuccess "✓ Scoop configuration: $totalApps total applications"
    $TestsPassed++
} catch {
    Write-BootstrapError "✗ Failed to read Scoop configuration: $($_.Exception.Message)"
    $TestsFailed++
}

# Test WinGet apps configuration
try {
    $WinGetApps = Get-Content ".\config\winget-apps.json" | ConvertFrom-Json
    $categories = $WinGetApps.PSObject.Properties.Name
    Write-BootstrapInfo "WinGet categories found: $($categories -join ', ')"
    
    $totalApps = 0
    foreach ($category in $categories) {
        $count = $WinGetApps.$category.Count
        $totalApps += $count
        Write-BootstrapInfo "  $category`: $count applications"
    }
    Write-BootstrapSuccess "✓ WinGet configuration: $totalApps total applications"
    $TestsPassed++
} catch {
    Write-BootstrapError "✗ Failed to read WinGet configuration: $($_.Exception.Message)"
    $TestsFailed++
}

# Test Network configuration
try {
    $NetworkConfig = Get-Content ".\config\network-config.json" | ConvertFrom-Json
    $settings = $NetworkConfig.PSObject.Properties | Where-Object { $_.Name -notlike "_*" }
    Write-BootstrapInfo "Network configuration settings found: $($settings.Name -join ', ')"
    Write-BootstrapSuccess "✓ Network configuration: Valid JSON structure"
    $TestsPassed++
} catch {
    Write-BootstrapError "✗ Failed to read Network configuration: $($_.Exception.Message)"
    $TestsFailed++
}

# Summary
Write-BootstrapHeader "Test Results"
Write-BootstrapInfo "Tests passed: $TestsPassed"
if ($TestsFailed -gt 0) {
    Write-BootstrapError "Tests failed: $TestsFailed"
    exit 1
} else {
    Write-BootstrapSuccess "All tests passed! Bootstrap structure is valid."
    exit 0
}