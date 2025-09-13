# Bootstrap Windows

A comprehensive set of scripts designed to configure and install applications on a new Windows instance. This bootstrap solution uses:

- **Scoop** for CLI-based applications and development tools
- **WinGet** for GUI-based applications and productivity software

## Features

- 🚀 **Automated Setup**: One-command bootstrap for new Windows machines
- 🛠️ **Package Managers**: Installs and configures Scoop and WinGet
- 📦 **Curated Applications**: Predefined sets of essential, development, and productivity applications
- ⚙️ **Configurable**: Customizable application lists via JSON configuration files
- 🎯 **Categorized**: Applications organized into logical categories (browsers, development, utilities, etc.)
- 🔧 **Error Handling**: Robust error handling and user feedback
- 📋 **Logging**: Detailed logging for troubleshooting

## Quick Start

1. **Clone the repository** (or download the scripts):
   ```powershell
   git clone https://github.com/corybiscuit/bootstrap-windows.git
   cd bootstrap-windows
   ```

2. **Run as Administrator** (required for system-level installations):
   ```powershell
   # Right-click PowerShell and "Run as Administrator"
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   .\bootstrap.ps1
   ```

That's it! The script will handle the rest automatically.

## Usage Options

### Basic Usage
```powershell
# Full bootstrap with all applications
.\bootstrap.ps1

# Skip Scoop and CLI applications
.\bootstrap.ps1 -SkipScoop

# Skip WinGet and GUI applications
.\bootstrap.ps1 -SkipWinGet

# Use custom configuration path
.\bootstrap.ps1 -ConfigPath "C:\custom\config"
```

### Individual Components
You can also run individual setup scripts:

```powershell
# Check prerequisites before running bootstrap
.\check-prerequisites.ps1

# Setup only Scoop and CLI applications
.\scripts\setup-scoop.ps1

# Setup only WinGet and GUI applications
.\scripts\setup-winget.ps1

# Setup PowerShell profile with useful aliases
.\scripts\setup-profile.ps1

# Test configuration files and structure
.\test-structure.ps1
```

## Application Categories

### Scoop (CLI Applications)
- **Essential**: git, curl, wget, 7zip, nodejs, python, vim
- **Development**: vscode, docker, terraform, azure-cli, aws, kubectl, helm, gh
- **Utilities**: grep, sed, jq, yq, tree, which, touch, less, find, fd, ripgrep, bat
- **Optional**: ffmpeg, imagemagick, pandoc, hugo, go, rust, dotnet

### WinGet (GUI Applications)
- **Browsers**: Chrome, Firefox, Edge
- **Productivity**: Adobe Reader, Notion, Obsidian, PowerToys
- **Development**: VS Code, IntelliJ IDEA, Postman, Docker Desktop, Windows Terminal
- **Utilities**: 7-Zip, VLC, Spotify, WinDirStat
- **Communication**: Teams, Slack, Discord, Zoom

## Customization

You can customize the applications to install by modifying the JSON configuration files:

- `config/scoop-apps.json` - CLI applications installed via Scoop
- `config/winget-apps.json` - GUI applications installed via WinGet

### Example: Custom Scoop Configuration
```json
{
  "essential": [
    "git",
    "nodejs",
    "python"
  ],
  "my-tools": [
    "custom-app",
    "another-tool"
  ]
}
```

### Example: Custom WinGet Configuration
```json
{
  "my-apps": [
    {
      "id": "Microsoft.VisualStudioCode",
      "name": "VS Code"
    },
    {
      "id": "Google.Chrome",
      "name": "Chrome"
    }
  ]
}
```

## Prerequisites

- **Windows 10** (version 1709+) or **Windows 11**
- **PowerShell 5.0** or higher
- **Administrator privileges** (required for system installations)
- **Internet connection** (for downloading packages)

## Troubleshooting

### Common Issues

1. **Execution Policy Error**:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

2. **WinGet Not Found**:
   - Install "App Installer" from Microsoft Store
   - Or run Windows Update to get the latest version

3. **Scoop Installation Fails**:
   - Check internet connection
   - Verify PowerShell execution policy
   - Run as Administrator

### Logs
Check the `logs/` directory for detailed installation logs and error messages.

## File Structure

```
bootstrap-windows/
├── bootstrap.ps1                 # Main bootstrap script
├── check-prerequisites.ps1       # Prerequisites verification script  
├── test-structure.ps1            # Configuration validation script
├── scripts/
│   ├── utilities.ps1             # Common utility functions
│   ├── setup-scoop.ps1           # Scoop setup and CLI apps
│   ├── setup-winget.ps1          # WinGet setup and GUI apps
│   └── setup-profile.ps1         # PowerShell profile configuration
├── config/
│   ├── scoop-apps.json           # Scoop applications configuration
│   ├── winget-apps.json          # WinGet applications configuration
│   └── README.md                 # Configuration help
├── logs/                         # Log files (created during execution)
└── README.md                     # This file
```

## Contributing

Feel free to submit issues and enhancement requests! To contribute:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.