<#
.SYNOPSIS
    Creates interactive HTML visualizations from process reports using PSWriteHTML.

.DESCRIPTION
    This script reads process report data (CSV or JSON) and generates HTML visualizations
    focusing on number of processes per user using PSWriteHTML module.

.PARAMETER InputFile
    Path to the process report file (CSV or JSON). Supports wildcards.

.PARAMETER OutputFile
    Path for the output HTML file. If not specified, generates a timestamped filename.

.PARAMETER ShowReport
    Automatically open the generated HTML report in default browser.
    Default: $true

.EXAMPLE
    ./sample-visualization.ps1 -InputFile "reports/ProcessReport_20250617_120000.csv"

.EXAMPLE
    ./sample-visualization.ps1 -InputFile "reports/ProcessReport*.json" -ShowReport $false

.NOTES
    MIT License - Copyright (c) 2025 Quantum Shepard
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "",
    
    [Parameter(Mandatory = $false)]
    [bool]$ShowReport = $true
)

#region Functions

function Test-Dependencies {
    <#
    .SYNOPSIS
        Checks if required modules are installed. Installs if missing.
    
    .DESCRIPTION
        Verifies that PSWriteHTML module is available and imports it.
        If not installed, attempts to install it from PSGallery.
    
    .OUTPUTS
        Returns $true if dependencies are satisfied, $false otherwise.
    #>
    [CmdletBinding()]
    param()
    
    Write-Host "`nChecking dependencies..." -ForegroundColor Cyan
    
    # Define required module and minimum version for compatibility
    $requiredModule = "PSWriteHTML"
    $minimumVersion = [Version]"0.0.183"
    $dependenciesMet = $true
    
    try {
        # First check: Is the module already loaded in the current session?
        # This avoids redundant imports and speeds up execution
        $importedModule = Get-Module -Name $requiredModule -ErrorAction SilentlyContinue
        if ($importedModule) {
            Write-Host "✓ $requiredModule module is already loaded (Version: $($importedModule.Version))" -ForegroundColor Green
            return $true
        }
        
        # Second check: Is the module installed on the system?
        # Get-Module -ListAvailable searches all module paths
        Write-Host "Checking for $requiredModule module..." -ForegroundColor Yellow
        $installedModule = Get-Module -ListAvailable -Name $requiredModule | 
            Sort-Object Version -Descending | 
            Select-Object -First 1
        
        if ($installedModule) {
            Write-Host "Found $requiredModule version $($installedModule.Version)" -ForegroundColor Gray
            
            # Version check: Ensure we have a compatible version
            # Older versions may lack required cmdlets or have bugs
            if ($installedModule.Version -lt $minimumVersion) {
                Write-Warning "$requiredModule version $($installedModule.Version) is installed, but version $minimumVersion or higher is recommended."
                Write-Host "Attempting to update $requiredModule..." -ForegroundColor Yellow
                
                try {
                    # Update-Module requires the module to have been installed via Install-Module
                    Update-Module -Name $requiredModule -Force -ErrorAction Stop
                    Write-Host "✓ $requiredModule module updated successfully!" -ForegroundColor Green
                }
                catch {
                    # Update might fail if module was installed manually or with different scope
                    Write-Warning "Could not update $requiredModule automatically: $_"
                    Write-Host "Please update manually: Update-Module -Name $requiredModule -Force" -ForegroundColor Yellow
                }
            }
            
            # Import the module into the current session
            # This makes all PSWriteHTML cmdlets available
            Write-Host "Importing $requiredModule module..." -ForegroundColor Yellow
            Import-Module $requiredModule -ErrorAction Stop
            Write-Host "✓ $requiredModule module imported successfully!" -ForegroundColor Green
            
        } else {
            # Module not installed - attempt automatic installation
            Write-Warning "$requiredModule module is not installed."
            
            # Verify we can access PowerShell Gallery before attempting install
            # This prevents confusing errors if network/proxy issues exist
            $canInstall = $true
            try {
                # Test connectivity to PSGallery
                $null = Find-Module -Name $requiredModule -Repository PSGallery -ErrorAction Stop
            }
            catch {
                Write-Error "Cannot access PSGallery: $_"
                $canInstall = $false
            }
            
            if ($canInstall) {
                Write-Host "Installing $requiredModule module from PSGallery..." -ForegroundColor Yellow
                
                # Get user consent before installing software
                # This follows security best practices
                $response = Read-Host "Do you want to install $requiredModule? (Y/N)"
                if ($response -eq 'Y' -or $response -eq 'y') {
                    try {
                        # NuGet provider is required for Install-Module to work
                        # Check and install if missing (common on fresh systems)
                        $nugetProvider = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
                        if (-not $nugetProvider) {
                            Write-Host "Installing NuGet provider..." -ForegroundColor Yellow
                            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser
                        }
                        
                        # Install module with specific parameters:
                        # - MinimumVersion: Ensures compatibility
                        # - Force: Overwrites existing older versions
                        # - AllowClobber: Prevents command conflicts
                        # - Scope CurrentUser: No admin rights needed
                        # - Repository PSGallery: Official source
                        Install-Module -Name $requiredModule `
                                     -MinimumVersion $minimumVersion `
                                     -Force `
                                     -AllowClobber `
                                     -Scope CurrentUser `
                                     -Repository PSGallery `
                                     -ErrorAction Stop
                        
                        Write-Host "✓ $requiredModule module installed successfully!" -ForegroundColor Green
                        
                        # Import the newly installed module immediately
                        Import-Module $requiredModule -ErrorAction Stop
                        Write-Host "✓ $requiredModule module imported successfully!" -ForegroundColor Green
                        
                    }
                    catch {
                        # Installation failed - provide actionable error message
                        Write-Error "Failed to install $requiredModule module: $_"
                        $dependenciesMet = $false
                    }
                } else {
                    # User declined installation
                    Write-Host "Installation cancelled by user." -ForegroundColor Yellow
                    $dependenciesMet = $false
                }
            } else {
                # Cannot access PSGallery - provide manual installation instructions
                Write-Error "Cannot install $requiredModule module. Please install manually:"
                Write-Host "Install-Module -Name $requiredModule -Force -AllowClobber" -ForegroundColor Yellow
                $dependenciesMet = $false
            }
        }
        
        # Final verification: Ensure module is now loaded and available
        if ($dependenciesMet) {
            $loadedModule = Get-Module -Name $requiredModule -ErrorAction SilentlyContinue
            if ($loadedModule) {
                Write-Host "`n✓ All dependencies satisfied!" -ForegroundColor Green
                Write-Host "  $requiredModule version: $($loadedModule.Version)" -ForegroundColor Gray
                
                # Show available commands to help users understand capabilities
                $commandCount = (Get-Command -Module $requiredModule).Count
                Write-Host "  Available commands: $commandCount" -ForegroundColor Gray
            } else {
                # Module should be loaded but isn't - unexpected error
                Write-Error "$requiredModule module could not be loaded."
                $dependenciesMet = $false
            }
        }
        
    }
    catch {
        # Catch-all for unexpected errors during dependency check
        Write-Error "Error checking dependencies: $_"
        $dependenciesMet = $false
    }
    
    # Provide helpful next steps if dependencies aren't met
    if (-not $dependenciesMet) {
        Write-Host "`nDependency check failed. Please resolve the issues above and try again." -ForegroundColor Red
        Write-Host "For more information, visit: https://github.com/EvotecIT/PSWriteHTML" -ForegroundColor Yellow
    }
    
    return $dependenciesMet
}

function Get-RawData {
    <#
    .SYNOPSIS
        Loads raw data from input CSV or JSON files.
    
    .DESCRIPTION
        Reads process report data from CSV or JSON format and returns a standardized
        PowerShell object array for visualization.
    
    .PARAMETER FilePath
        Path to the input file. Supports wildcards.
    
    .OUTPUTS
        Returns an array of process objects with standardized properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    Write-Host "`nStep 1: Loading raw data..." -ForegroundColor Yellow
    
    try {
        # Resolve file path - handles wildcards and relative paths
        # This allows patterns like "reports/*.csv" or "ProcessReport*.json"
        Write-Verbose "Resolving file path: $FilePath"
        $resolvedPaths = @(Resolve-Path -Path $FilePath -ErrorAction SilentlyContinue)
        
        if ($resolvedPaths.Count -eq 0) {
            throw "No files found matching pattern: $FilePath"
        }
        
        # Handle multiple file matches intelligently
        # When using wildcards, select the most recent file (likely the latest report)
        if ($resolvedPaths.Count -gt 1) {
            Write-Host "Found $($resolvedPaths.Count) files matching pattern. Using most recent..." -ForegroundColor Yellow
            $fileInfo = Get-Item $resolvedPaths | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            $targetFile = $fileInfo.FullName
        } else {
            $targetFile = $resolvedPaths[0].Path
        }
        
        # Display file information for user verification
        $file = Get-Item $targetFile
        Write-Host "Loading file: $($file.Name)" -ForegroundColor Cyan
        Write-Host "File size: $([math]::Round($file.Length / 1KB, 2)) KB" -ForegroundColor Gray
        Write-Host "Last modified: $($file.LastWriteTime)" -ForegroundColor Gray
        
        # Initialize array to hold standardized process data
        $processData = @()
        
        # Handle different file formats based on extension
        switch ($file.Extension.ToLower()) {
            '.csv' {
                Write-Verbose "Detected CSV format"
                Write-Host "Reading CSV data..." -ForegroundColor Yellow
                
                # Import-Csv automatically parses the file into objects
                $rawData = Import-Csv -Path $targetFile -ErrorAction Stop
                
                if ($rawData.Count -eq 0) {
                    throw "CSV file is empty or could not be parsed"
                }
                
                Write-Host "✓ Loaded $($rawData.Count) processes from CSV" -ForegroundColor Green
                
                # Standardize data structure to ensure consistent property types
                # This handles variations in CSV data and prevents type errors
                $processData = $rawData | ForEach-Object {
                    [PSCustomObject]@{
                        PID = [int]$_.PID
                        ProcessName = $_.ProcessName
                        User = $_.User
                        # Handle 'N/A' values in numeric fields by converting to 0
                        CPUTimeSeconds = if ($_.CPUTimeSeconds -eq 'N/A') { 0 } else { [double]$_.CPUTimeSeconds }
                        CPUPercentage = $_.CPUPercentage
                        WorkingSetMB = [double]$_.WorkingSetMB
                        PagedMemoryMB = [double]$_.PagedMemoryMB
                        TotalMemoryMB = [double]$_.TotalMemoryMB
                        MemoryPercentage = [double]$_.MemoryPercentage
                        Handles = [int]$_.Handles
                        Threads = [int]$_.Threads
                        StartTime = $_.StartTime
                        Path = $_.Path
                    }
                }
            }
            
            '.json' {
                Write-Verbose "Detected JSON format"
                Write-Host "Reading JSON data..." -ForegroundColor Yellow
                
                # Read entire file and parse JSON
                $jsonContent = Get-Content -Path $targetFile -Raw -ErrorAction Stop
                $jsonData = $jsonContent | ConvertFrom-Json -ErrorAction Stop
                
                # JSON files may have different structures:
                # 1. Direct array of processes
                # 2. Object with metadata and processes array
                if ($jsonData.PSObject.Properties.Name -contains 'processes') {
                    # Structure with metadata - common in reports with summary info
                    Write-Host "JSON structure: Report with metadata" -ForegroundColor Gray
                    
                    # Display metadata for user information
                    if ($jsonData.metadata) {
                        Write-Host "`nReport Metadata:" -ForegroundColor Cyan
                        Write-Host "  Generated: $($jsonData.metadata.GeneratedAt)" -ForegroundColor Gray
                        Write-Host "  Computer: $($jsonData.metadata.Computer)" -ForegroundColor Gray
                        Write-Host "  User: $($jsonData.metadata.GeneratedBy)" -ForegroundColor Gray
                        Write-Host "  Process Count: $($jsonData.metadata.ProcessCount)" -ForegroundColor Gray
                    }
                    
                    $rawData = $jsonData.processes
                } else {
                    # Direct array structure - simple process list
                    Write-Host "JSON structure: Direct process array" -ForegroundColor Gray
                    $rawData = $jsonData
                }
                
                if ($rawData.Count -eq 0) {
                    throw "JSON file contains no process data"
                }
                
                Write-Host "✓ Loaded $($rawData.Count) processes from JSON" -ForegroundColor Green
                
                # Standardize JSON data with same structure as CSV
                # Handles null values and ensures correct data types
                $processData = $rawData | ForEach-Object {
                    [PSCustomObject]@{
                        PID = [int]$_.PID
                        ProcessName = $_.ProcessName
                        User = $_.User
                        # Handle both 'N/A' strings and null values
                        CPUTimeSeconds = if ($_.CPUTimeSeconds -eq 'N/A' -or $null -eq $_.CPUTimeSeconds) { 0 } else { [double]$_.CPUTimeSeconds }
                        CPUPercentage = $_.CPUPercentage
                        WorkingSetMB = [double]$_.WorkingSetMB
                        PagedMemoryMB = [double]$_.PagedMemoryMB
                        TotalMemoryMB = [double]$_.TotalMemoryMB
                        MemoryPercentage = [double]$_.MemoryPercentage
                        Handles = [int]$_.Handles
                        Threads = [int]$_.Threads
                        StartTime = $_.StartTime
                        Path = $_.Path
                    }
                }
            }
            
            default {
                # Unsupported file type - provide clear error message
                throw "Unsupported file format: $($file.Extension). Supported formats: .csv, .json"
            }
        }
        
        # Validate that we have usable data
        Write-Verbose "Validating loaded data..."
        
        if ($processData.Count -eq 0) {
            throw "No valid process data found in file"
        }
        
        # Calculate and display data statistics for user verification
        Write-Host "`nData Summary:" -ForegroundColor Cyan
        
        # Count unique users excluding system processes marked as 'N/A'
        $uniqueUsers = @($processData | Where-Object { $_.User -ne 'N/A' } | Select-Object -ExpandProperty User -Unique)
        
        # Calculate total memory usage across all processes
        $totalMemoryMB = ($processData | Measure-Object -Property TotalMemoryMB -Sum).Sum
        
        # Display summary statistics
        Write-Host "  Total Processes: $($processData.Count)" -ForegroundColor Gray
        Write-Host "  Unique Users: $($uniqueUsers.Count)" -ForegroundColor Gray
        Write-Host "  Total Memory: $([math]::Round($totalMemoryMB / 1024, 2)) GB" -ForegroundColor Gray
        Write-Host "  System Processes: $(($processData | Where-Object { $_.User -eq 'N/A' }).Count)" -ForegroundColor Gray
        
        # Show sample of loaded data for verification
        Write-Host "`nSample of loaded data (first 3 processes):" -ForegroundColor Yellow
        $processData | Select-Object -First 3 | ForEach-Object {
            Write-Host "  $($_.ProcessName) (PID: $($_.PID)) - User: $($_.User), Memory: $($_.TotalMemoryMB) MB" -ForegroundColor Gray
        }
        
        Write-Host "`n✓ Data loaded and validated successfully!" -ForegroundColor Green
        
        return $processData
        
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        # Specific error for file not found - common user error
        Write-Error "File not found: $FilePath"
        Write-Host "Please ensure the file path is correct and the file exists." -ForegroundColor Red
        throw
    }
    catch [System.Management.Automation.RuntimeException] {
        # Runtime errors often indicate data format issues
        if ($_.Exception.Message -like "*Cannot convert*") {
            Write-Error "Data format error: Unable to parse file contents"
            Write-Host "Please ensure the file contains valid process report data." -ForegroundColor Red
        } else {
            Write-Error "Runtime error: $_"
        }
        throw
    }
    catch {
        # Generic error handler for unexpected issues
        Write-Error "Failed to load data: $_"
        Write-Host "Error type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
        throw
    }
}

function Create-Report {
    <#
    .SYNOPSIS
        Generates an HTML report focusing on number of processes per user.
    
    .DESCRIPTION
        Creates an interactive HTML visualization showing process distribution
        by user with charts and detailed tables using PSWriteHTML.
    
    .PARAMETER ProcessData
        Array of process objects with standardized properties.
    
    .PARAMETER OutputPath
        Path where the HTML report will be saved.
    
    .OUTPUTS
        Returns $true if report was created successfully, $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$ProcessData,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    Write-Host "`nStep 2: Creating visualization report..." -ForegroundColor Yellow
    
    try {
        # Verify PSWriteHTML module is available before proceeding
        if (-not (Get-Module -Name PSWriteHTML)) {
            throw "PSWriteHTML module is not loaded. Please run Test-Dependencies first."
        }
        
        # Calculate processes per user statistics
        # This is the core analysis for our visualization
        Write-Host "Calculating processes per user..." -ForegroundColor Yellow
        
        # Group processes by user and calculate aggregate statistics
        # Group-Object creates collections of processes for each unique user
        $userStats = $ProcessData | 
            Group-Object -Property User | 
            Select-Object @{
                Name = 'User'
                Expression = { $_.Name }
            }, @{
                Name = 'ProcessCount'
                Expression = { $_.Count }
            }, @{
                Name = 'TotalMemoryMB'
                Expression = { 
                    # Sum total memory usage for all processes owned by this user
                    [math]::Round(($_.Group | Measure-Object -Property TotalMemoryMB -Sum).Sum, 2)
                }
            }, @{
                Name = 'AvgMemoryMB'
                Expression = { 
                    # Calculate average memory per process for this user
                    [math]::Round(($_.Group | Measure-Object -Property TotalMemoryMB -Average).Average, 2)
                }
            }, @{
                Name = 'Percentage'
                Expression = { 
                    # Calculate what percentage of total processes this user owns
                    [math]::Round(($_.Count / $ProcessData.Count) * 100, 2)
                }
            } | Sort-Object ProcessCount -Descending  # Sort by process count for charts
        
        # Display calculated statistics for verification
        Write-Host "`nUser Statistics:" -ForegroundColor Cyan
        Write-Host "  Total Users: $($userStats.Count)" -ForegroundColor Gray
        Write-Host "  Total Processes: $($ProcessData.Count)" -ForegroundColor Gray
        
        # Show top users by process count - helps identify heavy users
        Write-Host "`nTop 5 Users by Process Count:" -ForegroundColor Cyan
        $userStats | Select-Object -First 5 | ForEach-Object {
            Write-Host ("  {0,-30} {1,4} processes ({2,5:N1}%)" -f $_.User, $_.ProcessCount, $_.Percentage) -ForegroundColor Gray
        }
        
        # Generate output filename if not specified
        # This ensures we always have a valid output path
        if (-not $OutputPath) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $OutputPath = "reports/ProcessVisualization_$timestamp.html"
        }
        
        # Ensure output directory exists - create if necessary
        # This prevents file write errors due to missing directories
        $outputDir = Split-Path -Parent $OutputPath
        if ($outputDir -and -not (Test-Path $outputDir)) {
            Write-Host "Creating output directory: $outputDir" -ForegroundColor Yellow
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }
        
        Write-Host "`nGenerating HTML report..." -ForegroundColor Yellow
        
        # Create the HTML report using PSWriteHTML DSL (Domain Specific Language)
        # ShowHTML:$false prevents automatic browser launch (controlled by caller)
        New-HTML -TitleText "Process Report - Processes per User" -FilePath $OutputPath -ShowHTML:$false {
            
            # Header section with title and timestamp
            # Invisible section doesn't create a visual container
            New-HTMLSection -Invisible {
                New-HTMLContainer {
                    New-HTMLText -Text "Process Report Analysis" -Size 28 -Color "#1e3a8a" -FontWeight bold -Alignment center
                    New-HTMLText -Text "Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Size 12 -Color "#64748b" -Alignment center
                    New-HTMLHorizontalLine
                }
            }
            
            # Summary Statistics Section - Key metrics at a glance
            # CanCollapse allows users to hide/show this section
            New-HTMLSection -HeaderText "Overview" -CanCollapse {
                # Four panels showing primary metrics
                New-HTMLPanel {
                    New-HTMLText -Text "Total Processes" -Size 16 -Color "#2563eb"
                    New-HTMLText -Text $ProcessData.Count -Size 32 -FontWeight bold
                }
                New-HTMLPanel {
                    New-HTMLText -Text "Unique Users" -Size 16 -Color "#7c3aed"
                    New-HTMLText -Text $userStats.Count -Size 32 -FontWeight bold
                }
                New-HTMLPanel {
                    New-HTMLText -Text "System Processes" -Size 16 -Color "#dc2626"
                    New-HTMLText -Text ($ProcessData | Where-Object { $_.User -eq 'N/A' }).Count -Size 32 -FontWeight bold
                }
                New-HTMLPanel {
                    New-HTMLText -Text "User Processes" -Size 16 -Color "#059669"
                    New-HTMLText -Text ($ProcessData | Where-Object { $_.User -ne 'N/A' }).Count -Size 32 -FontWeight bold
                }
            }
            
            # Main visualization section - Process count charts
            New-HTMLSection -HeaderText "Processes per User Distribution" {
                
                # Bar Chart - Shows top 15 users by process count
                # Limited to 15 for readability on typical screens
                New-HTMLPanel {
                    New-HTMLChart -Gradient {
                        New-ChartBarOptions -Distributed  # Each bar gets different color
                        
                        # Add data for top 15 users only
                        $topUsers = $userStats | Select-Object -First 15
                        foreach ($userStat in $topUsers) {
                            # Truncate long usernames to fit chart labels
                            # Domain\Username can be quite long
                            $userName = if ($userStat.User.Length -gt 25) { 
                                $userStat.User.Substring(0, 25) + "..." 
                            } else { 
                                $userStat.User 
                            }
                            New-ChartBar -Name $userName -Value $userStat.ProcessCount
                        }
                    } -Title "Number of Processes per User (Top 15)" -TitleAlignment center -Height 400
                }
                
                # Pie Chart - Shows relative distribution
                # Groups small users into "Others" category
                New-HTMLPanel {
                    New-HTMLChart {
                        # Only show users with >2% of processes individually
                        # This prevents tiny, unreadable pie slices
                        $threshold = 2  # Minimum percentage to show separately
                        $significantUsers = $userStats | Where-Object { $_.Percentage -ge $threshold }
                        $otherUsers = $userStats | Where-Object { $_.Percentage -lt $threshold }
                        
                        # Add significant users to pie chart
                        foreach ($userStat in $significantUsers) {
                            # Include count in label for clarity
                            New-ChartPie -Name "$($userStat.User) ($($userStat.ProcessCount))" -Value $userStat.ProcessCount
                        }
                        
                        # Combine all small users into "Others" slice
                        if ($otherUsers) {
                            $otherCount = ($otherUsers | Measure-Object -Property ProcessCount -Sum).Sum
                            New-ChartPie -Name "Others ($otherCount)" -Value $otherCount
                        }
                    } -Title "Process Distribution by User" -TitleAlignment center -Height 400
                }
            }
            
            # Memory Usage Analysis - Secondary visualization
            # Shows which users consume the most memory
            New-HTMLSection -HeaderText "Memory Usage Analysis" {
                New-HTMLChart -Gradient {
                    New-ChartBarOptions -Type bar
                    
                    # Show top 10 memory consumers only
                    # Memory usage often follows different pattern than process count
                    $topMemoryUsers = $userStats | Sort-Object TotalMemoryMB -Descending | Select-Object -First 10
                    foreach ($userStat in $topMemoryUsers) {
                        # Convert to GB for more readable numbers
                        $memoryGB = [math]::Round($userStat.TotalMemoryMB / 1024, 2)
                        New-ChartBar -Name $userStat.User -Value $memoryGB
                    }
                } -Title "Total Memory Usage by User (GB) - Top 10" -TitleAlignment center -Height 350
            }
            
            # Detailed statistics table with all users
            # Provides complete data with sorting/filtering capabilities
            New-HTMLSection -HeaderText "Detailed User Statistics" {
                New-HTMLTable -DataTable $userStats -ScrollX -Buttons @('copyHtml5', 'excelHtml5', 'csvHtml5', 'print') `
                    -SearchPane -PagingLength 25 -FilteringLocation Both {
                    
                    # Conditional formatting to highlight heavy users
                    # Red background for users with many processes
                    New-HTMLTableCondition -Name 'ProcessCount' -ComparisonType number -Operator gt -Value 50 -BackgroundColor '#fee2e2' -Color '#991b1b'
                    # Yellow background for moderate process counts
                    New-HTMLTableCondition -Name 'ProcessCount' -ComparisonType number -Operator gt -Value 20 -BackgroundColor '#fef3c7' -Color '#92400e'
                    # Pink background for high memory usage
                    New-HTMLTableCondition -Name 'TotalMemoryMB' -ComparisonType number -Operator gt -Value 5000 -BackgroundColor '#fce7f3' -Color '#9f1239'
                }
            }
            
            # Complete process details - collapsed by default
            # This table can be very large, so it's hidden initially
            New-HTMLSection -HeaderText "All Process Details" -Collapsed {
                New-HTMLText -Text "Detailed information about all processes" -Size 12 -Color "#6b7280"
                
                # Full process table with export capabilities
                New-HTMLTable -DataTable $ProcessData -ScrollX -ScrollY -ScrollCollapse `
                    -Buttons @('copyHtml5', 'excelHtml5', 'csvHtml5') `
                    -SearchPane -PagingLength 50 -FilteringLocation Top {
                    
                    # Highlight high memory usage processes
                    New-HTMLTableCondition -Name 'MemoryPercentage' -ComparisonType number -Operator gt -Value 5 -BackgroundColor '#dc2626' -Color 'white'
                    New-HTMLTableCondition -Name 'MemoryPercentage' -ComparisonType number -Operator gt -Value 2 -BackgroundColor '#f59e0b' -Color 'white'
                    New-HTMLTableCondition -Name 'TotalMemoryMB' -ComparisonType number -Operator gt -Value 1000 -BackgroundColor '#fbbf24'
                }
            }
            
            # Footer with generation info and version
            New-HTMLSection -Invisible {
                New-HTMLHorizontalLine
                New-HTMLText -Text "Generated by Azul-Tooling-Task-CLI - Process Visualization Tool" -Size 10 -Color "#9ca3af" -Alignment center
                New-HTMLText -Text "Report created with PSWriteHTML v$((Get-Module PSWriteHTML).Version)" -Size 9 -Color "#d1d5db" -Alignment center
            }
        }
        
        # Verify the report was created successfully
        if (Test-Path $OutputPath) {
            $fileInfo = Get-Item $OutputPath
            Write-Host "`n✓ HTML report created successfully!" -ForegroundColor Green
            Write-Host "  File: $OutputPath" -ForegroundColor Gray
            Write-Host "  Size: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor Gray
            
            return $true
        } else {
            throw "Report file was not created at expected location: $OutputPath"
        }
        
    }
    catch [System.IO.IOException] {
        # File system errors - disk full, permissions, etc.
        Write-Error "File system error: $_"
        Write-Host "Please check disk space and permissions for: $OutputPath" -ForegroundColor Red
        return $false
    }
    catch {
        # Generic error handler with detailed error info
        Write-Error "Failed to create report: $_"
        Write-Host "Error type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
        Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Show-Usage {
    <#
    .SYNOPSIS
        Function to display usage instructions.
    
    .DESCRIPTION
        Displays comprehensive usage information for the PSWriteHTML visualization script,
        including parameters, examples, and troubleshooting tips.
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Display formatted help text with examples and troubleshooting
        # Using here-string for multi-line formatted text
        Write-Host @"

=== PSWriteHTML Process Visualization Tool ===

DESCRIPTION:
    Creates interactive HTML visualizations from process reports using PSWriteHTML.
    Focuses on processes per user distribution with charts and detailed tables.

SYNOPSIS:
    .\sample-visualization.ps1 -InputFile <path> [-OutputFile <path>] [-ShowReport <bool>]

PARAMETERS:
    -InputFile <string>
        Path to the process report file (CSV or JSON). Supports wildcards.
        Accepts files generated by generate-report.ps1
        
        Examples:
        • "reports\ProcessReport_HOME-W11-RAPTOR_20250616_221838.csv"
        • "reports\ProcessReport*.json"
        • ".\reports\ProcessReport_latest.csv"

    -OutputFile <string> [Optional]
        Path for the output HTML file. If not specified, generates a timestamped filename.
        Default: "reports\ProcessVisualization_YYYYMMDD_HHMMSS.html"
        
        Examples:
        • "reports\MyVisualization.html"
        • "C:\Reports\ProcessAnalysis.html"

    -ShowReport <bool> [Optional]
        Automatically open the generated HTML report in default browser.
        Default: `$true

EXAMPLES:

    Basic usage with CSV file:
    .\sample-visualization.ps1 -InputFile "reports\ProcessReport_HOME-W11-RAPTOR_20250616_221838.csv"

    Generate report without opening browser:
    .\sample-visualization.ps1 -InputFile "reports\ProcessReport*.csv" -ShowReport `$false

    Custom output location:
    .\sample-visualization.ps1 -InputFile "data.json" -OutputFile "analysis\dashboard.html"

    Process latest report (using wildcards):
    .\sample-visualization.ps1 -InputFile "reports\ProcessReport_*.csv"

FEATURES:
    • Interactive HTML dashboard with charts and tables
    • Process distribution by user (bar and pie charts)
    • Memory usage analysis
    • Detailed process statistics
    • Export capabilities (Excel, CSV, PDF)
    • Search and filtering functionality
    • Mobile-responsive design

REQUIREMENTS:
    • PowerShell Core 7.0 or later
    • PSWriteHTML module (auto-installed if missing)
    • Input file in CSV or JSON format from generate-report.ps1

SUPPORTED INPUT FORMATS:
    • CSV files with headers: PID, ProcessName, User, TotalMemoryMB, etc.
    • JSON files with process arrays and metadata
    • Files generated by generate-report.ps1 script

OUTPUT:
    • HTML file with interactive visualizations
    • Summary statistics and charts
    • Detailed process tables with conditional formatting
    • Export buttons for data extraction

TROUBLESHOOTING:

    Error: "PSWriteHTML module is not installed"
    Solution: The script will automatically install the module from PSGallery

    Error: "File not found"
    Solution: Verify the input file path is correct and file exists

    Error: "Cannot bind argument to parameter 'OutputPath'"
    Solution: Ensure output directory exists or use default location

    Error: "No valid process data found"
    Solution: Check that input file contains valid process report data

    Performance issues with large datasets:
    Solution: Consider filtering data or using latest/smaller report files

NOTES:
    • The script creates the output directory if it doesn't exist
    • Wildcards in InputFile will select the most recent matching file
    • Generated reports include timestamp and metadata for reference
    • Charts are optimized for readability (top 15 users, grouped small values)

For more information about process data collection, see:
    .\generate-report.ps1 --help

For visualization examples and advanced usage, see:
    README_Visualization.md in the project documentation

"@ -ForegroundColor Cyan
        
    }
    catch {
        # Error displaying help shouldn't crash the script
        Write-Error "Failed to display usage information: $_"
        Write-Host "Error displaying help. Please check the script documentation." -ForegroundColor Red
    }
}

#endregion

# Main script execution
try {
    Write-Host "`n=== PSWriteHTML Process Visualization ===" -ForegroundColor Cyan
    Write-Host "Starting visualization process..." -ForegroundColor Green
    
    # Step 0: Check dependencies
    # Ensures PSWriteHTML module is available before proceeding
    if (-not (Test-Dependencies)) {
        Write-Error "Required dependencies are not available. Exiting."
        exit 1
    }
    
    # Step 1: Load raw data
    # Reads and standardizes process data from input file
    $processData = Get-RawData -FilePath $InputFile
    
    # Validate we have data to work with
    if (-not $processData -or $processData.Count -eq 0) {
        Write-Error "No data loaded. Cannot proceed with visualization."
        exit 1
    }
    
    Write-Host "`nSuccessfully loaded $($processData.Count) processes for visualization" -ForegroundColor Green
    
    # Generate output filename if not specified
    # Ensures we always have a valid output path with timestamp
    if ([string]::IsNullOrWhiteSpace($OutputFile)) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $OutputFile = "reports/ProcessVisualization_$timestamp.html"
        Write-Host "Generated output filename: $OutputFile" -ForegroundColor Yellow
    }
    
    # Ensure output directory exists
    # Creates directory structure if needed to prevent write errors
    $outputDir = Split-Path -Parent $OutputFile
    if ($outputDir -and -not (Test-Path $outputDir)) {
        Write-Host "Creating output directory: $outputDir" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    # Step 2: Create report
    # Generates the HTML visualization with charts and tables
    $reportCreated = Create-Report -ProcessData $processData -OutputPath $OutputFile
    
    if (-not $reportCreated) {
        Write-Error "Failed to create visualization report."
        exit 1
    }
    
    # Step 3: Open report if requested
    # Launches the HTML file in default browser for immediate viewing
    if ($ShowReport -and $OutputFile) {
        Write-Host "`nOpening report in default browser..." -ForegroundColor Cyan
        if (Test-Path $OutputFile) {
            Start-Process $OutputFile
        }
    }
    
    # Success message with file location
    Write-Host "`n✓ Visualization completed successfully!" -ForegroundColor Green
    Write-Host "Report location: $OutputFile" -ForegroundColor Cyan
    
}
catch {
    # Global error handler for any unhandled exceptions
    Write-Error "Failed to create visualization: $_"
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}