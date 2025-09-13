# Configuration Files

This directory contains JSON configuration files that define which applications to install.

## Files

- `scoop-apps.json` - CLI applications installed via Scoop
- `winget-apps.json` - GUI applications installed via WinGet

## Format

### Scoop Apps (scoop-apps.json)
```json
{
  "category-name": [
    "app-name",
    "another-app"
  ]
}
```

### WinGet Apps (winget-apps.json)
```json
{
  "category-name": [
    {
      "id": "Publisher.AppName",
      "name": "Display Name"
    }
  ]
}
```

## Finding App IDs

### For Scoop:
Search available apps: `scoop search <app-name>`
Browse buckets: https://scoop.sh/#/buckets

### For WinGet:
Search available apps: `winget search <app-name>`
Browse packages: https://winget.run/

## Customization Tips

1. **Remove unwanted apps**: Delete entries you don't need
2. **Add new categories**: Create new category sections as needed
3. **Reorder categories**: The order in the file determines installation order
4. **Test changes**: Run `.\test-structure.ps1` to validate JSON syntax

## Example Custom Configuration

```json
{
  "my-essentials": [
    "git",
    "nodejs",
    "python"
  ],
  "my-development": [
    "docker",
    "vscode",
    "postman"
  ]
}
```