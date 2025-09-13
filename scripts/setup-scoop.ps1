<#
.SYNOPSIS
    Sets up Scoop package manager and installs CLI-based applications.

.DESCRIPTION
    This script installs Scoop if not already present and installs
    a predefined set of CLI-based applications from configuration files.

.PARAMETER ConfigPath
    Path to configuration files directory (default: ./config)

.PARAMETER SelectedCategories
    Hashtable of selected categories and their apps (optional)
#>

param(
    [string]$ConfigPath = ".\config",
    [hashtable]$SelectedCategories = @{}
)

# Import utility functions
. ".\scripts\utilities.ps1"

Write-BootstrapHeader "Scoop Setup"

try {
    # Check if Scoop is already installed
    if (Test-CommandExists "scoop") {
        Write-BootstrapInfo "Scoop is already installed, updating..."
        scoop update
    } else {
        Write-BootstrapInfo "Installing Scoop..."
        
        # Set execution policy for current session
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        
        # Install Scoop
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
        
        if (-not (Test-CommandExists "scoop")) {
            throw "Scoop installation failed"
        }
        
        Write-BootstrapSuccess "Scoop installed successfully"
    }

    # Add useful buckets
    Write-BootstrapInfo "Adding Scoop buckets..."
    $buckets = @("extras", "versions", "nerd-fonts")
    
    foreach ($bucket in $buckets) {
        try {
            scoop bucket add $bucket
            Write-BootstrapInfo "Added bucket: $bucket"
        } catch {
            Write-BootstrapWarning "Failed to add bucket: $bucket"
        }
    }

    # Determine which applications to install
    $AppsToInstall = @{}
    
    if ($SelectedCategories.Count -gt 0) {
        Write-BootstrapInfo "Using user-selected categories and applications"
        $AppsToInstall = $SelectedCategories
    } else {
        # Load CLI applications configuration
        $CliAppsFile = Join-Path $ConfigPath "scoop-apps.json"
        if (Test-Path $CliAppsFile) {
            Write-BootstrapInfo "Loading CLI applications from: $CliAppsFile"
            $CliApps = Get-Content $CliAppsFile | ConvertFrom-Json
            
            # Convert to hashtable for consistent processing
            foreach ($category in $CliApps.PSObject.Properties.Name) {
                $AppsToInstall[$category] = $CliApps.$category
            }
        } else {
            Write-BootstrapInfo "Using default CLI applications list"
            $AppsToInstall = @{
                "essential" = @(
                    "git",
                    "curl",
                    "wget",
                    "7zip",
                    "nodejs",
                    "python",
                    "vim"
                )
                "development" = @(
                    "vscode",
                    "docker",
                    "terraform",
                    "azure-cli",
                    "aws",
                    "kubectl",
                    "helm"
                )
                "utilities" = @(
                    "grep",
                    "sed",
                    "jq",
                    "yq",
                    "tree",
                    "which",
                    "touch"
                )
            }
        }
    }

    # Install applications by category
    foreach ($category in $AppsToInstall.Keys) {
        $apps = $AppsToInstall[$category]
        Write-BootstrapInfo "Installing $category applications ($($apps.Count) apps)..."
        
        foreach ($app in $apps) {
            try {
                Write-BootstrapInfo "Installing: $app"
                scoop install $app
                Write-BootstrapSuccess "Installed: $app"
            } catch {
                Write-BootstrapWarning "Failed to install: $app - $($_.Exception.Message)"
            }
        }
    }

    # Configure Git if installed
    if (Test-CommandExists "git") {
        Write-BootstrapInfo "Configuring Git..."
        try {
            # Set basic Git configuration (user can override later)
            git config --global init.defaultBranch main
            git config --global core.autocrlf true
            git config --global core.editor "code --wait"
            Write-BootstrapSuccess "Git configured with default settings"
        } catch {
            Write-BootstrapWarning "Failed to configure Git: $($_.Exception.Message)"
        }
    }

    # Update all installed applications
    Write-BootstrapInfo "Updating all Scoop applications..."
    scoop update *

    Write-BootstrapSuccess "Scoop setup completed successfully!"

} catch {
    Write-BootstrapError "Scoop setup failed: $($_.Exception.Message)"
    exit 1
}