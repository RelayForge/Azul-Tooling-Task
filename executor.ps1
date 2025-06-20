# executor.ps1
<#
.SYNOPSIS
    Master script for Azul-Tooling-Task-CLI that validates environment and executes process reporting.

.DESCRIPTION
    This script serves as the main entry point for the Azul-Tooling-Task-CLI tool.
    It performs the following operations:
    1. Executes DSC to verify runtime environment and dependencies
    2. Generates process reports using generate-report.ps1, catering the output file.
    3. Creates visualizations using sample-visualization.ps1 and using as input file the generated report.
    
    The script focuses on implementation simplicity and provides a clean UI experience.

.PARAMETER Format
    Output format for process reports. Valid values: CSV, JSON, Both
    Default: Both

.PARAMETER SkipVisualization
    Skip HTML visualization generation

.PARAMETER SkipDSC
    Skip DSC environment validation. Use with caution.

.EXAMPLE
    .\executor.ps1

.EXAMPLE
    .\executor.ps1 -SkipVisualization -SkipDSC

.NOTES
    - Administrative privileges recommended for complete functionality
    - Automatically handles dependency installation where possible
#>

[CmdletBinding()]
param(
    [ValidateSet('CSV', 'JSON')]
    [string]$OutputFormat = 'CSV',

    [switch]$SkipDSC
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Define paths
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$DSCScript = Join-Path $ProjectRoot 'dsc/environment.ps1'
$GenerateReportScript = Join-Path $ProjectRoot 'scripts/generate-report.ps1'
$VisualizationScript = Join-Path $ProjectRoot 'scripts/sample-visualization.ps1'
$ReportsPath = Join-Path $ProjectRoot 'reports' $outputFileName

# Output file name generation based on date and time
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$outputFileName = Join-Path $ReportsPath "process_report_$timestamp.$OutputFormat"


Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " Azul-Tooling-Task-CLI Executor" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

# Step 1: DSC Environment Validation
if (-not $SkipDSC) {
    Write-Host "[1/3] Validating environment with DSC..." -ForegroundColor Yellow
    if (Test-Path $DSCScript) {
        try {
            pwsh -File $DSCScript
            Write-Host "✓ DSC validation completed successfully." -ForegroundColor Green
        }
        catch {
            Write-Warning "DSC validation failed: $_"
            exit 1
        }
    }
    else {
        Write-Warning "DSC script not found at $DSCScript. Skipping DSC validation."
    }
}
else {
    Write-Host "[1/3] Skipping DSC validation as requested." -ForegroundColor Yellow
}

# Step 2: Generate Process Report
Write-Host "[2/3] Generating process report ($OutputFormat)..." -ForegroundColor Yellow
if (Test-Path $GenerateReportScript) {
    try {
        pwsh -File $GenerateReportScript --format $OutputFormat --output-path $outputFileName
        Write-Host "✓ Process report generated successfully." -ForegroundColor Green
    }
    catch {
        Write-Warning "Report generation failed: $_"
        exit 1
    }
}
else {
    Write-Warning "Report generation script not found at $GenerateReportScript."
    exit 1
}

# Step 3: Generate Visualization
Write-Host "[3/3] Generating visualization..." -ForegroundColor Yellow
if (Test-Path $VisualizationScript) {
    try {
        pwsh -File $VisualizationScript -InputFile $outputFileName
        Write-Host "✓ Visualization generated successfully." -ForegroundColor Green
    }
    catch {
        Write-Warning "Visualization generation failed: $_"
        exit 1
    }
}
else {
    Write-Warning "Visualization script not found at $VisualizationScript."
    exit 1
}

# Execution Summary
$summary = @"
Execution Summary:
------------------
Timestamp          : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Computer           : $env:COMPUTERNAME
User               : $env:USERNAME
PowerShell Version : $($PSVersionTable.PSVersion)
OS Version         : $(if ($IsWindows) { (Get-CimInstance Win32_OperatingSystem).Caption } elseif ($IsMacOS) { "macOS $(sw_vers -productVersion)" } else { "Unknown OS" })
Output Format      : $OutputFormat
DSC Validation     : $(if ($SkipDSC) { "Skipped" } else { "Executed" })
"@

Write-Host "`n$summary" -ForegroundColor Cyan

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " Execution completed successfully!" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Cyan