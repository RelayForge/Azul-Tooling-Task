# DSC Environment Configuration Documentation

## Overview

The environment.ps1 script uses PowerShell Desired State Configuration (DSC) to establish a consistent, reproducible environment for the Azul-Tooling-Task-CLI project. DSC ensures all required dependencies and configurations are properly set up before running process reporting tasks.

## Why DSC?

**Declarative Configuration**: DSC describes *what* the system should look like rather than *how* to configure it, making setup more reliable and repeatable.

**Idempotency**: Running the configuration multiple times produces the same result without side effects.

**Cross-Platform Compatibility**: Works on both Windows and macOS with PowerShell Core.

**Dependency Management**: Automatically handles prerequisites like PowerShell modules and execution policies.

## What It Configures

The DSC configuration handles these essential setup tasks:

### 1. PowerShell Configuration
- Sets execution policy to `Unrestricted` for CurrentUser scope
- Configures PowerShell Gallery as trusted repository
- Installs `PSWriteHTML` module for visualization capabilities

### 2. Security Settings
- Uses minimal privilege requirements
- Implements safe execution policy scoping
- Graceful degradation when admin privileges unavailable

## Usage Instructions

### Basic Setup
```powershell
# Navigate to project root
cd azul-tooling-task-cli

# Run DSC configuration
pwsh .\dsc\environment.ps1
```

### Advanced Options
```powershell
# Custom paths
pwsh .\dsc\environment.ps1 -ReportsPath "C:\Reports" -ScriptsPath "C:\Scripts"

# Verbose output for troubleshooting
pwsh .\dsc\environment.ps1 -Verbose
```

## How DSC is Implemented

**Ultra-Light Approach**: Uses `Invoke-DscResource` instead of traditional DSC compilation to avoid WinRM dependencies that cause connection errors.

**Resource Types Used**:
- `File` resource for directory creation
- `Registry` resource for execution policy (when admin privileges available)
- Native PowerShell cmdlets as fallbacks for non-admin scenarios

**Error Handling**: Implements graceful degradation when administrator privileges aren't available, ensuring the script works in restricted environments.

## Troubleshooting

### Common Issues

**"Execution policy restriction"**
```powershell
# Solution: Run with admin privileges or use bypass
pwsh -ExecutionPolicy Bypass .\dsc\environment.ps1
```

**"Module installation failed"**
```powershell
# Check PowerShell Gallery access
Get-PSRepository -Name "PSGallery"

# Reset if needed
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
```

**"Access denied creating directories"**
```powershell
# Ensure write permissions to target location
# Or specify alternative path with write access
pwsh .\dsc\environment.ps1 -ReportsPath "$env:USERPROFILE\AzulReports"
```

**"ConnectionError: WinRM service not available"**
- This error is **completely avoided** by using `Invoke-DscResource` instead of `Start-DscConfiguration`
- No WinRM or remote management services required
- Configuration applies directly to local system

### Verification

Check configuration success:
```powershell
# Check module availability
Get-Module PSWriteHTML -ListAvailable

# Verify execution policy
Get-ExecutionPolicy -Scope CurrentUser
```

## Benefits for Azul-Tooling-Task-CLI

1. **Consistent Environment**: Ensures all team members have identical setups
2. **Automated Dependencies**: No manual module installation required
3. **Permission Handling**: Adapts to different privilege levels automatically
4. **Cross-Platform Ready**: Works on Windows and macOS PowerShell Core
5. **MIT Compliant**: Maintains proper licensing throughout all operations
6. **WinRM-Free**: Eliminates connection errors by avoiding remote management dependencies

This DSC approach eliminates "works on my machine" issues and provides a solid foundation for reliable process reporting functionality while maintaining the MIT license requirements and avoiding WinRM connectivity problems.