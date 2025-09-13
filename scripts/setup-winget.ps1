<#
.SYNOPSIS
    Sets up WinGet package manager and installs GUI-based applications.

.DESCRIPTION
    This script ensures WinGet is available and installs
    a predefined set of GUI-based applications from configuration files.

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

Write-BootstrapHeader "WinGet Setup"

try {
    # Check if WinGet is available
    if (Test-CommandExists "winget") {
        Write-BootstrapInfo "WinGet is available"
        
        # Update sources
        Write-BootstrapInfo "Updating WinGet sources..."
        winget source update
    } else {
        Write-BootstrapInfo "WinGet not found, attempting to install..."
        
        # WinGet comes with Windows 10 version 1709+ and Windows 11
        # For older systems or if missing, try to install from Microsoft Store
        try {
            # Try to install App Installer which includes WinGet
            Write-BootstrapInfo "Installing App Installer (includes WinGet)..."
            
            # Download and install the latest App Installer
            $AppInstallerUrl = "https://aka.ms/getwinget"
            $TempFile = Join-Path $env:TEMP "AppInstaller.msixbundle"
            
            Invoke-WebRequest -Uri $AppInstallerUrl -OutFile $TempFile
            Add-AppxPackage -Path $TempFile
            
            Remove-Item $TempFile -Force
            
            # Verify installation
            Start-Sleep -Seconds 5
            if (-not (Test-CommandExists "winget")) {
                throw "WinGet installation failed or not available in PATH"
            }
            
            Write-BootstrapSuccess "WinGet installed successfully"
        } catch {
            Write-BootstrapError "Failed to install WinGet: $($_.Exception.Message)"
            Write-BootstrapInfo "Please install WinGet manually from the Microsoft Store"
            return
        }
    }

    # Accept source agreements
    Write-BootstrapInfo "Accepting WinGet source agreements..."
    winget list --accept-source-agreements | Out-Null

    # Determine which applications to install
    $AppsToInstall = @{}
    
    if ($SelectedCategories.Count -gt 0) {
        Write-BootstrapInfo "Using user-selected categories and applications"
        $AppsToInstall = $SelectedCategories
    } else {
        # Load GUI applications configuration
        $GuiAppsFile = Join-Path $ConfigPath "winget-apps.json"
        if (Test-Path $GuiAppsFile) {
            Write-BootstrapInfo "Loading GUI applications from: $GuiAppsFile"
            $GuiApps = Get-Content $GuiAppsFile | ConvertFrom-Json
            
            # Convert to hashtable for consistent processing
            foreach ($category in $GuiApps.PSObject.Properties.Name) {
                $AppsToInstall[$category] = $GuiApps.$category
            }
        } else {
            Write-BootstrapInfo "Using default GUI applications list"
            $AppsToInstall = @{
                "browsers" = @(
                    @{ id = "Google.Chrome"; name = "Google Chrome" },
                    @{ id = "Mozilla.Firefox"; name = "Mozilla Firefox" }
                )
                "productivity" = @(
                    @{ id = "Microsoft.Office"; name = "Microsoft Office" },
                    @{ id = "Adobe.Acrobat.Reader.64-bit"; name = "Adobe Acrobat Reader" },
                    @{ id = "Notion.Notion"; name = "Notion" }
                )
                "development" = @(
                    @{ id = "Microsoft.VisualStudioCode"; name = "Visual Studio Code" },
                    @{ id = "JetBrains.IntelliJIDEA.Community"; name = "IntelliJ IDEA Community" },
                    @{ id = "Postman.Postman"; name = "Postman" },
                    @{ id = "Docker.DockerDesktop"; name = "Docker Desktop" }
                )
                "utilities" = @(
                    @{ id = "7zip.7zip"; name = "7-Zip" },
                    @{ id = "WinRAR.WinRAR"; name = "WinRAR" },
                    @{ id = "VideoLAN.VLC"; name = "VLC Media Player" },
                    @{ id = "Spotify.Spotify"; name = "Spotify" }
                )
                "communication" = @(
                    @{ id = "Microsoft.Teams"; name = "Microsoft Teams" },
                    @{ id = "SlackTechnologies.Slack"; name = "Slack" },
                    @{ id = "Discord.Discord"; name = "Discord" }
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
                $appId = if ($app -is [string]) { $app } else { $app.id }
                $appName = if ($app -is [string]) { $app } else { $app.name }
                
                Write-BootstrapInfo "Installing: $appName"
                
                # Install with accept agreements and silent mode
                winget install --id $appId --accept-package-agreements --accept-source-agreements --silent
                
                if ($LASTEXITCODE -eq 0) {
                    Write-BootstrapSuccess "Installed: $appName"
                } else {
                    Write-BootstrapWarning "Installation may have failed for: $appName (exit code: $LASTEXITCODE)"
                }
            } catch {
                Write-BootstrapWarning "Failed to install: $appName - $($_.Exception.Message)"
            }
        }
    }

    # Update all installed applications
    Write-BootstrapInfo "Updating all WinGet applications..."
    winget upgrade --all --accept-package-agreements --accept-source-agreements --silent

    Write-BootstrapSuccess "WinGet setup completed successfully!"

} catch {
    Write-BootstrapError "WinGet setup failed: $($_.Exception.Message)"
    exit 1
}