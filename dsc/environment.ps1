<#
.SYNOPSIS
    Ultra-light DSC setup for Azul Tooling Task CLI environment without WinRM dependencies
.DESCRIPTION
    This script uses Invoke-DscResource to apply configuration directly,
    avoiding WinRM connection issues while setting up the required environment.
#>

[CmdletBinding()]
param(
)

Write-Host "=== Azul Tooling Environment Setup ===" -ForegroundColor Cyan
Write-Host "Using ultra-light DSC implementation without WinRM" -ForegroundColor Yellow

# Ensure we're running with sufficient privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Warning "Some operations may require administrator privileges"
    Write-Host "Consider running as administrator for full functionality" -ForegroundColor Yellow
}

# Function to safely invoke DSC resources
function Invoke-SafeDscResource {
    param(
        [string]$ResourceName,
        [hashtable]$Properties,
        [string]$Description
    )
    
    Write-Host "Configuring: $Description" -ForegroundColor Green
    
    try {
        $result = Invoke-DscResource -Name $ResourceName -Method Set -Property $Properties -Verbose:$false
        
        if ($result.InDesiredState) {
            Write-Host "  ✓ Already configured" -ForegroundColor DarkGreen
        } else {
            Write-Host "  ✓ Successfully configured" -ForegroundColor Green
        }
        
        return $true
    }
    catch {
        Write-Warning "  ✗ Failed to configure $Description`: $($_.Exception.Message)"
        return $false
    }
}

# 1. Set PowerShell Execution Policy using Registry resource
Write-Host "`n2. Configuring PowerShell Execution Policy..." -ForegroundColor Cyan

if ($isAdmin) {
    # Set execution policy for all users (requires admin)
    $result = Invoke-SafeDscResource -ResourceName "Registry" -Properties @{
        Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell"
        ValueName = "ExecutionPolicy"
        ValueData = "Unrestricted"
        ValueType = "String"
        Ensure = "Present"
    } -Description "PowerShell Execution Policy (All Users)"
} else {
    # Fallback: Set for current user only
    try {
        Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser -Force
        Write-Host "  ✓ Execution Policy set for current user" -ForegroundColor Green
    }
    catch {
        Write-Warning "  ✗ Failed to set execution policy: $($_.Exception.Message)"
    }
}

# 2. Ensure PowerShell Gallery is trusted
Write-Host "`n3. Configuring PowerShell Gallery..." -ForegroundColor Cyan

try {
    $gallery = Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue
    if ($gallery -and $gallery.InstallationPolicy -ne "Trusted") {
        Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
        Write-Host "  ✓ PowerShell Gallery set as trusted" -ForegroundColor Green
    } else {
        Write-Host "  ✓ PowerShell Gallery already trusted" -ForegroundColor DarkGreen
    }
}
catch {
    Write-Warning "  ✗ Failed to configure PowerShell Gallery: $($_.Exception.Message)"
}

# 3. Install required modules using PackageManagement
Write-Host "`n4. Installing required PowerShell modules..." -ForegroundColor Cyan

$requiredModules = @("PSWriteHTML")

foreach ($moduleName in $requiredModules) {
    try {
        $installedModule = Get-Module -Name $moduleName -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        
        if ($installedModule) {
            Write-Host "  ✓ $moduleName already installed (v$($installedModule.Version))" -ForegroundColor DarkGreen
        } else {
            Write-Host "  Installing $moduleName..." -ForegroundColor Yellow
            
            if ($isAdmin) {
                Install-Module -Name $moduleName -Scope AllUsers -Force -AllowClobber
                Write-Host "  ✓ $moduleName installed for all users" -ForegroundColor Green
            } else {
                Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber
                Write-Host "  ✓ $moduleName installed for current user" -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Warning "  ✗ Failed to install $moduleName`: $($_.Exception.Message)"
    }
}

# 4. Verify PowerShell Core version
Write-Host "`n5. Verifying PowerShell version..." -ForegroundColor Cyan

$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ge 7) {
    Write-Host "  ✓ PowerShell Core $psVersion detected" -ForegroundColor Green
} elseif ($psVersion.Major -ge 5) {
    Write-Host "  ⚠ PowerShell $psVersion detected (PowerShell 7+ recommended)" -ForegroundColor Yellow
} else {
    Write-Warning "  ✗ PowerShell version $psVersion may not be compatible"
}

# 6. Generate environment summary
Write-Host "`n=== Environment Setup Summary ===" -ForegroundColor Cyan

$summary = @{
    "Computer Name" = $env:COMPUTERNAME
    "User" = $env:USERNAME
    "PowerShell Version" = "$($PSVersionTable.PSVersion)"
    "OS Version" = [System.Environment]::OSVersion.VersionString
    "Reports Path" = $ReportsPath
    "Scripts Path" = $ScriptsPath
    "Admin Privileges" = $isAdmin
    "Setup Time" = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

$summary.GetEnumerator() | ForEach-Object {
    Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor White
}

Write-Host "`n✓ Environment setup completed!" -ForegroundColor Green
Write-Host "You can now run: .\scripts\generate-report.ps1" -ForegroundColor Yellow