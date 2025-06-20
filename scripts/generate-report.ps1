<#
.SYNOPSIS
Retrieves a report of all running processes on the system, including their names, IDs, and owners.
.DESCRIPTION
    This function retrieves a report of all running processes on the system, including their names, IDs, and owners.
    It uses the Get-Process cmdlet to gather information about each process and returns a structured report.
.PARAMETER Format
    Specifies the output format for the report. Valid values: CSV, JSON, Both
    Default: CSV
.PARAMETER OutputPath
    Specifies the custom output path for the report files.
    Default: ./reports/
.EXAMPLE
    generate-report.ps1 -Format JSON -OutputPath C:\Reports\
    Retrieves a report of all running processes in JSON format and saves it to C:\Reports\.
#>

function Get-WindowsProcessReport {
    <#
      .SYNOPSIS
      Retrieves a report of all running processes on the system, including their names, IDs, and owners.
    #>
    
    Write-Host "`nGenerating process report..." -ForegroundColor Cyan
    
    # Step 1: Get all processes using Get-Process for all users
    # Note: -IncludeUserName requires elevated permissions to get owner info for all processes
    Write-Host "Retrieving all running processes..."
    
    try {
        # Attempt to get all processes with user information
        # This requires administrator privileges for complete data
        $allProcesses = Get-Process -IncludeUserName -ErrorAction Stop
        
        Write-Host "Successfully retrieved $($allProcesses.Count) processes" -ForegroundColor Green
        
        # Analyze the quality of data retrieved
        # Some processes may not have user information even with admin rights
        $processesWithUsers = $allProcesses | Where-Object { $_.UserName }
        $processesWithoutUsers = $allProcesses | Where-Object { -not $_.UserName }
        
        Write-Host "Processes with user information: $($processesWithUsers.Count)"
        Write-Host "Processes without user information: $($processesWithoutUsers.Count)" -ForegroundColor Yellow
        
        # Inform user about system processes that typically don't have user info
        if ($processesWithoutUsers.Count -gt 0) {
            Write-Host "Note: Some system processes may not have user information available" -ForegroundColor Yellow
        }
        
        # Get unique users to show process distribution
        # This helps understand which accounts are running processes
        $uniqueUsers = $processesWithUsers | Select-Object -ExpandProperty UserName -Unique | Sort-Object
        Write-Host "Processes running under $($uniqueUsers.Count) different users:"
        $uniqueUsers | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
        
        # Show sample of processes for verification
        # Helps user confirm data is being collected correctly
        Write-Host "`nSample of retrieved processes:" -ForegroundColor Yellow
        $allProcesses | Select-Object -First 5 | ForEach-Object {
            $user = if ($_.UserName) { $_.UserName } else { "N/A" }
            Write-Host "  PID: $($_.Id.ToString().PadLeft(6)) | Name: $($_.ProcessName.PadRight(25)) | User: $user" -ForegroundColor Gray
        }
        
        return $allProcesses
        
    }
    catch [System.ComponentModel.Win32Exception] {
        # This specific exception occurs when running without admin privileges
        Write-Error "Access denied. This operation requires elevated permissions (Run as Administrator)."
        Write-Host "Error: Unable to retrieve process information with user details" -ForegroundColor Red
        Write-Host "Please run this script as Administrator to get complete process information" -ForegroundColor Yellow
        throw
    }
    catch {
        # Generic error handler for unexpected issues
        Write-Error "Failed to retrieve process information: $_"
        Write-Host "Error type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
        Write-Host "Error message: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Get-MacOSProcessReport {
    param([switch]$IncludeUserName)
    
    Write-Verbose "Collecting macOS process information..."
    
    # Get total system memory using sysctl
    # This is needed to calculate memory percentages
    $memInfo = & sysctl -n hw.memsize
    $totalMemoryMB = [math]::Round($memInfo / 1MB, 2)

    $psOutput = & ps -axo pid,user,%cpu,rss,comm,lstart -r
    
    # Skip header line and parse each process
    $processes = $psOutput | Select-Object -Skip 1 | ForEach-Object {
        # Regular expression to parse ps output
        # Captures: PID, USER, CPU%, Memory(KB), Command, Start Time
        if ($_ -match '^\s*(\d+)\s+(\S+)\s+([\d.]+)\s+(\d+)\s+(.+?)\s+(\w+\s+\w+\s+\d+\s+[\d:]+\s+\d+)') {
            $pid = [int]$matches[1]
            $user = $matches[2]
            $cpuPercent = [decimal]$matches[3]
            $memoryKB = [int]$matches[4]
            $processName = Split-Path -Leaf $matches[5]  # Extract just the process name
            $startTimeStr = $matches[6]
            
            # Convert memory from KB to MB for consistency with Windows
            $memoryMB = [math]::Round($memoryKB / 1024, 2)
            $memoryPercent = [math]::Round(($memoryMB / $totalMemoryMB) * 100, 2)
            
            # Get CPU time using separate ps command
            # Format: minutes:seconds.hundredths
            $cpuTimeOutput = & ps -p $pid -o time= 2>$null
            $cpuTimeSeconds = 0
            if ($cpuTimeOutput -match '(\d+):(\d+)\.(\d+)') {
                $minutes = [int]$matches[1]
                $seconds = [int]$matches[2]
                $cpuTimeSeconds = ($minutes * 60) + $seconds
            }
            
            # Attempt to get full executable path
            # This may fail for some system processes
            $processPath = "Unknown"
            try {
                $pathOutput = & ps -p $pid -o comm= 2>$null
                if ($pathOutput) {
                    $processPath = $pathOutput.Trim()
                }
            }
            catch {
                Write-Verbose "Could not get path for PID $pid"
            }
            
            # Return object matching Windows format for consistency
            [PSCustomObject]@{
                PID = $pid
                ProcessName = $processName
                User = if ($IncludeUserName) { $user } else { "Unknown" }
                CPUTimeSeconds = $cpuTimeSeconds
                CPUPercent = $cpuPercent
                MemoryMB = $memoryMB
                MemoryPercent = $memoryPercent
                StartTime = $startTimeStr
                Path = $processPath
            }
        }
    }
    
    return $processes
}

function Export-ReportToCsv {
    <#
    .SYNOPSIS
        Exports the process report to a CSV file with execution summary.
    
    .DESCRIPTION
        Converts process data to CSV format with standardized columns and generates
        a text summary file containing execution metadata and top consumers.
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Diagnostics.Process[]]$ProcessReport,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutFile,
        [string]$reportsPath = (Join-Path -Path $PSScriptRoot -ChildPath '..\reports\' | Resolve-Path -Relative)
    )
    
    begin {
        Write-Host "`nExporting process report to CSV..." -ForegroundColor Cyan
        Write-Host "Received $($ProcessReport.Count) processes to export" -ForegroundColor Green
        
        # Show sample of data to be exported for verification
        Write-Host "Sample of processes to export:" -ForegroundColor Yellow
        $ProcessReport | Select-Object -First 3 | ForEach-Object {
            $user = if ($_.UserName) { $_.UserName } else { "N/A" }
            Write-Host "  PID: $($_.Id) | Name: $($_.ProcessName) | User: $user" -ForegroundColor Gray
        }
    }
    
    process {
        # Initialize variables for error handling and return value
        $csvFilePath = $null
        $csvData = $null
        
        try {
            # Step 2: Convert the report to CSV format with all required fields
            Write-Host "`nConverting process data to CSV format..."
            
            # Create structured objects with all required fields for CSV export
            # This ensures consistent column structure regardless of OS
            $csvData = $ProcessReport | ForEach-Object {
                # Calculate CPU time in seconds from TimeSpan object
                $cpuTime = if ($_.TotalProcessorTime) { $_.TotalProcessorTime.TotalSeconds } else { 0 }
                
                # Convert memory values from bytes to MB for readability
                $workingSetMB = [math]::Round($_.WorkingSet64 / 1MB, 2)
                $pagedMemoryMB = [math]::Round($_.PagedMemorySize64 / 1MB, 2)
                
                # Cache total system memory for performance
                # Only query once instead of for each process
                if (-not $script:totalMemory) {
                    $script:totalMemory = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory
                }
                
                # Calculate memory percentage relative to total system memory
                $memoryPercentage = if ($script:totalMemory -gt 0) {
                    [math]::Round(($_.WorkingSet64 / $script:totalMemory) * 100, 2)
                } else { 0 }
                
                # Create standardized object structure for CSV export
                [PSCustomObject]@{
                    PID = $_.Id
                    ProcessName = $_.ProcessName
                    User = if ($_.UserName) { $_.UserName } else { "N/A" }
                    CPUTimeSeconds = $cpuTime
                    CPUPercentage = "N/A"  # Real-time CPU % requires multiple samples over time
                    WorkingSetMB = $workingSetMB
                    PagedMemoryMB = $pagedMemoryMB
                    TotalMemoryMB = $workingSetMB + $pagedMemoryMB
                    MemoryPercentage = $memoryPercentage
                    Handles = $_.HandleCount
                    Threads = $_.Threads.Count
                    StartTime = if ($_.StartTime) { $_.StartTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "N/A" }
                    Path = if ($_.Path) { $_.Path } else { "N/A" }
                }
            }
            
            Write-Host "Successfully converted $($csvData.Count) processes to CSV format" -ForegroundColor Green
            
            # Show sample of converted data for verification
            Write-Host "Sample of converted data:" -ForegroundColor Yellow
            $csvData | Select-Object -First 2 | ForEach-Object {
                Write-Host "  $($_.ProcessName): PID=$($_.PID), User=$($_.User), Memory=$($_.WorkingSetMB)MB ($($_.MemoryPercentage)%)" -ForegroundColor Gray
            }
            
            # Use provided OutFile parameter directly as full path
            $csvFilePath = $OutFile

            Write-Host "Target path: $csvFilePath"
            
            # Export data to CSV with UTF8 encoding for international character support
            try {
                $csvData | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
            }
            catch {
                throw "Failed to write CSV file: $_"
            }
            
            # Verify file was created and show file info
            if (Test-Path -Path $csvFilePath) {
                $fileInfo = Get-Item -Path $csvFilePath
                Write-Host "CSV file saved successfully!" -ForegroundColor Green
                Write-Host "File size: $([math]::Round($fileInfo.Length / 1KB, 2)) KB"
                Write-Host "Location: $csvFilePath"
                
                # Show first few lines of the file for verification
                Write-Host "`nFirst 3 lines of CSV file:" -ForegroundColor Yellow
                Get-Content -Path $csvFilePath -TotalCount 3 | ForEach-Object {
                    Write-Host "  $_" -ForegroundColor Gray
                }
                
                # Generate execution summary with key statistics
                Write-Host "`nGenerating execution summary..."
                $summaryFileName = $OutFile -replace '\.csv$', '_summary.txt'
                $summaryPath = $summaryFileName
                
                # Create comprehensive summary with metadata and statistics
                $summary = @"
Process Report Execution Summary
================================
Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Computer: $computerName
User: $env:USERDOMAIN\$env:USERNAME
PowerShell Version: $($PSVersionTable.PSVersion)
OS Version: $($PSVersionTable.OS)

Statistics
----------
Total Processes: $($csvData.Count)
Processes with User Info: $(($csvData | Where-Object { $_.User -ne 'N/A' }).Count)
Unique Users: $(($csvData | Where-Object { $_.User -ne 'N/A' } | Select-Object -ExpandProperty User -Unique).Count)

Top Memory Consumers (Top 5)
----------------------------
$($csvData | Sort-Object -Property TotalMemoryMB -Descending | Select-Object -First 5 | ForEach-Object {
    "{0,-30} {1,10:N2} MB ({2,6:N2}%)" -f $_.ProcessName, $_.TotalMemoryMB, $_.MemoryPercentage
} | Out-String)

Report Location: $csvFilePath
Summary Location: $summaryPath
"@
                
                # Save summary file - don't fail entire operation if this fails
                try {
                    $summary | Out-File -FilePath $summaryPath -Encoding UTF8 -ErrorAction Stop
                    Write-Host "Execution summary saved: $summaryPath" -ForegroundColor Green
                }
                catch {
                    Write-Warning "Failed to save execution summary: $_"
                    # Don't fail the entire operation if summary fails
                }
                
            } else {
                throw "CSV file was not created at expected location: $csvFilePath"
            }
            
            # Return the file path for caller reference
            Write-Host "`nCSV export completed successfully!" -ForegroundColor Green
            return $csvFilePath
            
        }
        catch [System.ArgumentException] {
            # Handle invalid input data errors
            Write-Error "Invalid input data: $_"
            Write-Host "Please ensure the ProcessReport contains valid process objects" -ForegroundColor Red
            throw
        }
        catch [System.IO.IOException] {
            # Handle file system errors (disk full, etc.)
            Write-Error "File system error: $_"
            Write-Host "Check disk space and file permissions for: $reportsPath" -ForegroundColor Red
            throw
        }
        catch [System.UnauthorizedAccessException] {
            # Handle permission errors
            Write-Error "Access denied: $_"
            Write-Host "Insufficient permissions to write to: $reportsPath" -ForegroundColor Red
            throw
        }
        catch {
            # Generic error handler with cleanup
            Write-Error "Failed to export process data to CSV: $_"
            Write-Host "Error type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
            Write-Host "Error message: $($_.Exception.Message)" -ForegroundColor Red
            
            # Clean up partial files if they exist to avoid confusion
            if ($csvFilePath -and (Test-Path -Path $csvFilePath)) {
                try {
                    Remove-Item -Path $csvFilePath -Force -ErrorAction SilentlyContinue
                    Write-Host "Cleaned up partial CSV file" -ForegroundColor Yellow
                }
                catch {
                    Write-Warning "Could not clean up partial file: $csvFilePath"
                }
            }
            
            throw
        }
    }
}

function Export-ReportToJson {
    <#
    .SYNOPSIS
        Exports the process report to a JSON file with metadata.
    
    .DESCRIPTION
        Converts process data to JSON format with metadata section and generates
        a text summary file containing execution information and top consumers.
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Diagnostics.Process[]]$ProcessReport,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutFile,
        [string]$reportsPath = (Join-Path -Path $PSScriptRoot -ChildPath '..\reports\' | Resolve-Path -Relative)
    )
    
    begin {
        Write-Host "`nExporting process report to JSON..." -ForegroundColor Cyan
        
        Write-Host "Received $($ProcessReport.Count) processes to export" -ForegroundColor Green
        
        # Show sample of data to be exported for verification
        Write-Host "Sample of processes to export:" -ForegroundColor Yellow
        $ProcessReport | Select-Object -First 3 | ForEach-Object {
            $user = if ($_.UserName) { $_.UserName } else { "N/A" }
            Write-Host "  PID: $($_.Id) | Name: $($_.ProcessName) | User: $user" -ForegroundColor Gray
        }
    }
    
    process {
        # Initialize variables for error handling and return value
        $jsonFilePath = $null
        $jsonData = $null
        
        try {
            # Convert the report to JSON format with structured data
            Write-Host "`nConverting process data to JSON format..."
            
            # Create structured objects matching CSV format for consistency
            $jsonData = $ProcessReport | ForEach-Object {
                # Calculate CPU time from TimeSpan object
                $cpuTime = if ($_.TotalProcessorTime) { $_.TotalProcessorTime.TotalSeconds } else { 0 }
                
                # Convert memory values from bytes to MB
                $workingSetMB = [math]::Round($_.WorkingSet64 / 1MB, 2)
                $pagedMemoryMB = [math]::Round($_.PagedMemorySize64 / 1MB, 2)
                
                # Cache total system memory for performance
                if (-not $script:totalMemory) {
                    $script:totalMemory = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory
                }
                
                # Calculate memory percentage
                $memoryPercentage = if ($script:totalMemory -gt 0) {
                    [math]::Round(($_.WorkingSet64 / $script:totalMemory) * 100, 2)
                } else { 0 }
                
                # Create standardized object structure
                [PSCustomObject]@{
                    PID = $_.Id
                    ProcessName = $_.ProcessName
                    User = if ($_.UserName) { $_.UserName } else { "N/A" }
                    CPUTimeSeconds = $cpuTime
                    CPUPercentage = "N/A"  # Real-time CPU % requires sampling
                    WorkingSetMB = $workingSetMB
                    PagedMemoryMB = $pagedMemoryMB
                    TotalMemoryMB = $workingSetMB + $pagedMemoryMB
                    MemoryPercentage = $memoryPercentage
                    Handles = $_.HandleCount
                    Threads = $_.Threads.Count
                    StartTime = if ($_.StartTime) { $_.StartTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "N/A" }
                    Path = if ($_.Path) { $_.Path } else { "N/A" }
                }
            }
            
            Write-Host "Successfully converted $($jsonData.Count) processes to JSON format" -ForegroundColor Green
            
            # Show sample of converted data
            Write-Host "Sample of converted data:" -ForegroundColor Yellow
            $jsonData | Select-Object -First 2 | ForEach-Object {
                Write-Host "  $($_.ProcessName): PID=$($_.PID), User=$($_.User), Memory=$($_.WorkingSetMB)MB ($($_.MemoryPercentage)%)" -ForegroundColor Gray
            }
            
            # Use provided OutFile parameter directly
            $jsonFilePath = $OutFile
            
            Write-Host "Target path: $jsonFilePath"
            
            # Create metadata object with report generation details
            # This helps track when and where the report was generated
            $metadata = @{
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                GeneratedBy = "$env:USERDOMAIN\$env:USERNAME"
                Computer = $computerName
                PowerShellVersion = $PSVersionTable.PSVersion.ToString()
                OSVersion = $PSVersionTable.OS
                ProcessCount = $jsonData.Count
                UniqueUsers = @($jsonData | Where-Object { $_.User -ne 'N/A' } | Select-Object -ExpandProperty User -Unique).Count
            }
            
            # Create final JSON structure with metadata and process data
            $jsonOutput = @{
                metadata = $metadata
                processes = $jsonData
            }
            
            # Export data to JSON with proper formatting (not compressed for readability)
            try {
                $jsonOutput | ConvertTo-Json -Depth 10 -Compress:$false | Out-File -FilePath $jsonFilePath -Encoding UTF8 -ErrorAction Stop
            }
            catch {
                throw "Failed to write JSON file: $_"
            }
            
            # Verify file was created and show info
            if (Test-Path -Path $jsonFilePath) {
                $fileInfo = Get-Item -Path $jsonFilePath
                Write-Host "JSON file saved successfully!" -ForegroundColor Green
                Write-Host "File size: $([math]::Round($fileInfo.Length / 1KB, 2)) KB"
                Write-Host "Location: $jsonFilePath"
                
                # Show preview of JSON structure for verification
                Write-Host "`nJSON structure preview:" -ForegroundColor Yellow
                $jsonContent = Get-Content -Path $jsonFilePath -Raw | ConvertFrom-Json
                Write-Host "  Metadata:" -ForegroundColor Gray
                Write-Host "    - Generated: $($jsonContent.metadata.GeneratedAt)" -ForegroundColor Gray
                Write-Host "    - Processes: $($jsonContent.metadata.ProcessCount)" -ForegroundColor Gray
                Write-Host "    - Users: $($jsonContent.metadata.UniqueUsers)" -ForegroundColor Gray
                Write-Host "  First process: $($jsonContent.processes[0].ProcessName) (PID: $($jsonContent.processes[0].PID))" -ForegroundColor Gray
                
                # Generate execution summary matching CSV format
                Write-Host "`nGenerating execution summary..."
                $summaryFileName = $OutFile -replace '\.json$', '_summary.txt'
                $summaryPath = $summaryFileName
                
                # Calculate top memory consumers for summary
                $topMemoryProcesses = $jsonData | Sort-Object -Property TotalMemoryMB -Descending | Select-Object -First 5
                
                # Create comprehensive summary
                $summary = @"
Process Report Execution Summary
================================
Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Computer: $computerName
User: $env:USERDOMAIN\$env:USERNAME
PowerShell Version: $($PSVersionTable.PSVersion)
OS Version: $($PSVersionTable.OS)

Statistics
----------
Total Processes: $($jsonData.Count)
Processes with User Info: $(($jsonData | Where-Object { $_.User -ne 'N/A' }).Count)
Unique Users: $(($jsonData | Where-Object { $_.User -ne 'N/A' } | Select-Object -ExpandProperty User -Unique).Count)

Top Memory Consumers (Top 5)
----------------------------
$($topMemoryProcesses | ForEach-Object {
    "{0,-30} {1,10:N2} MB ({2,6:N2}%)" -f $_.ProcessName, $_.TotalMemoryMB, $_.MemoryPercentage
} | Out-String)

Report Location: $jsonFilePath
Summary Location: $summaryPath
"@
                
                # Save summary - don't fail entire operation if this fails
                try {
                    $summary | Out-File -FilePath $summaryPath -Encoding UTF8 -ErrorAction Stop
                    Write-Host "Execution summary saved: $summaryPath" -ForegroundColor Green
                }
                catch {
                    Write-Warning "Failed to save execution summary: $_"
                }
                
            } else {
                throw "JSON file was not created at expected location: $jsonFilePath"
            }
            
            # Return the file path for caller reference
            Write-Host "`nJSON export completed successfully!" -ForegroundColor Green
            return $jsonFilePath
            
        }
        catch [System.ArgumentException] {
            # Handle invalid input data
            Write-Error "Invalid input data: $_"
            Write-Host "Please ensure the ProcessReport contains valid process objects" -ForegroundColor Red
            throw
        }
        catch [System.IO.IOException] {
            # Handle file system errors
            Write-Error "File system error: $_"
            Write-Host "Check disk space and file permissions for: $reportsPath" -ForegroundColor Red
            throw
        }
        catch [System.UnauthorizedAccessException] {
            # Handle permission errors
            Write-Error "Access denied: $_"
            Write-Host "Insufficient permissions to write to: $reportsPath" -ForegroundColor Red
            throw
        }
        catch {
            # Generic error handler with cleanup
            Write-Error "Failed to export process data to JSON: $_"
            Write-Host "Error type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
            Write-Host "Error message: $($_.Exception.Message)" -ForegroundColor Red
            
            # Clean up partial files to avoid confusion
            if ($jsonFilePath -and (Test-Path -Path $jsonFilePath)) {
                try {
                    Remove-Item -Path $jsonFilePath -Force -ErrorAction SilentlyContinue
                    Write-Host "Cleaned up partial JSON file" -ForegroundColor Yellow
                }
                catch {
                    Write-Warning "Could not clean up partial file: $jsonFilePath"
                }
            }
            
            throw
        }
    }
}

function Show-Usage {
    <#
    .SYNOPSIS
    Displays usage information for the script, including available options and their descriptions.
    #>
    
    try {
        # Get script name dynamically for accurate display
        $scriptName = Split-Path -Leaf $MyInvocation.PSCommandPath
        if (-not $scriptName) {
            $scriptName = "get-processes_windows.ps1"
        }
        
        # Display comprehensive usage information
        Write-Host @"

Azul-Tooling-Task-CLI - Process Report Generator
=================================================

SYNOPSIS
    Generates detailed reports of running processes on Windows systems.

USAGE
    pwsh $scriptName [options]

OPTIONS
    --format <String>
        Specifies the output format for the report.
        Valid values: CSV, JSON, Both
        Default: CSV

    --output-path <String>
        Specifies custom output path for the report files.
        Default: ./reports/

    --skip-summary
        Skip generation of summary text files.

    --help, -h, -?
        Display this help message.

EXAMPLES
    # Generate CSV report
    pwsh $scriptName --format CSV

    # Generate both CSV and JSON reports
    pwsh $scriptName --format Both

    # Custom output location
    pwsh $scriptName --format JSON --output-path C:\Reports\

REQUIREMENTS
    - PowerShell Core 7.0 or higher
    - Windows operating system
    - Administrator privileges (for complete process information)

OUTPUT
    Reports are saved in the following format:
    - CSV: ProcessReport_COMPUTERNAME_YYYYMMDD_HHMMSS.csv
    - JSON: ProcessReport_COMPUTERNAME_YYYYMMDD_HHMMSS.json
    - Summary: ProcessReport_COMPUTERNAME_YYYYMMDD_HHMMSS_summary.txt

NOTES
    - The script must be run with Administrator privileges to retrieve
      process owner information for all processes.
    - Reports include: PID, Process Name, User, CPU Time, Memory Usage,
      Handles, Threads, Start Time, and Process Path.
    - Memory usage is reported in both MB and percentage of total RAM.

For more information, see the README.md file in the project repository.

"@ -ForegroundColor Cyan
        
    }
    catch {
        # Handle any errors in displaying usage information
        Write-Error "Failed to display usage information: $_"
        Write-Host "Error displaying help. Please check the script documentation." -ForegroundColor Red
    }
}

# Check if no arguments provided - show usage
if (-not $args) { Show-Usage; exit }

# Basic arg-parsing switch
$format = "CSV"  # Default format
$outputPath = $null
$skipSummary = $false
$showHelp = $false

# Parse command line arguments
# Simple argument parser that handles various option formats
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        # Help options
        { $_ -in '--help', '-h', '-?' } {
            $showHelp = $true
            break
        }
        # Format option
        { $_ -in '--format', '-f' } {
            if ($i + 1 -lt $args.Count) {
                $format = $args[$i + 1]
                $i++  # Skip next argument as it's the value
            } else {
                Write-Error "Format option requires a value (CSV, JSON, or Both)"
                exit 1
            }
            break
        }
        # Output path option
        { $_ -in '--output-path', '-o' } {
            if ($i + 1 -lt $args.Count) {
                $outputPath = $args[$i + 1]
                $i++  # Skip next argument as it's the value
            } else {
                Write-Error "Output path option requires a directory path"
                exit 1
            }
            break
        }
        # Skip summary option
        { $_ -in '--skip-summary', '-s' } {
            $skipSummary = $true
            break
        }
        # Legacy support - redirect old options to new format
        { $_ -in '--export-csv' } {
            $format = "CSV"
            break
        }
        { $_ -in '--export-json' } {
            $format = "JSON"
            break
        }
        # Unknown option handler
        default {
            Write-Error "Unknown option: $_"
            Write-Host "Use --help for usage information" -ForegroundColor Yellow
            exit 1
        }
    }
}

# Show help if requested
if ($showHelp) {
    Show-Usage
    exit 0
}

# Validate format option
if ($format -notin @("CSV", "JSON", "Both")) {
    Write-Error "Invalid format: $format. Valid values are: CSV, JSON, Both"
    exit 1
}

# Main script execution starts here
Write-Host "`n=== Azul-Tooling-Task-CLI Process Report Generator ===" -ForegroundColor Cyan
Write-Host "Starting process report generation..." -ForegroundColor Green
Write-Host "Format: $format" -ForegroundColor Yellow
if ($outputPath) {
    Write-Host "Output Path: $outputPath" -ForegroundColor Yellow
}
if ($skipSummary) {
    Write-Host "Summary generation: Disabled" -ForegroundColor Yellow
}

function Get-ProcessReportCrossPlatform {
    <#
    .SYNOPSIS
        Cross-platform process information retrieval wrapper.
    
    .DESCRIPTION
        Detects the operating system and calls the appropriate function
        to retrieve process information in a standardized format.
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludeUserName = $true
    )

    Write-Verbose "Detecting operating system..."
    
    # Use PowerShell Core's built-in OS detection variables
    if ($IsWindows) {
        Write-Verbose "Windows detected - using standard Get-Process"
        return Get-WindowsProcessReport -IncludeUserName:$IncludeUserName
    }
    elseif ($IsMacOS) {
        Write-Verbose "macOS detected - using ps command wrapper"
        return Get-MacOSProcessReport -IncludeUserName:$IncludeUserName
    }
    else {
        throw "Unsupported operating system. Only Windows and macOS are supported."
    }
}

# Get process report using cross-platform function
$processReport = Get-ProcessReportCrossPlatform
if (-not $processReport) {
    Write-Error "Failed to generate process report"
    exit 1
}

# Export reports based on format selection
$exportSuccess = $false
$exportedFiles = @()

try {
    # Handle custom output path if provided
    if ($outputPath) {
        # Store original PSScriptRoot and temporarily override it
        $script:originalScriptRoot = $PSScriptRoot
        $script:PSScriptRoot = Split-Path -Parent $outputPath
    }

    # Export based on selected format
    switch ($format) {
        "CSV" {
            $csvPath = Export-ReportToCsv -ProcessReport $processReport -OutFile $outputPath
            if ($csvPath) {
                $exportedFiles += $csvPath
                $exportSuccess = $true
            }
        }
        "JSON" {
            $jsonPath = Export-ReportToJson -ProcessReport $processReport -OutFile $outputPath
            if ($jsonPath) {
                $exportedFiles += $jsonPath
                $exportSuccess = $true
            }
        }
        "Both" {
            # Export both formats
            $csvPath = Export-ReportToCsv -ProcessReport $processReport
            if ($csvPath) {
                $exportedFiles += $csvPath
            }
            
            $jsonPath = Export-ReportToJson -ProcessReport $processReport
            if ($jsonPath) {
                $exportedFiles += $jsonPath
            }
            
            $exportSuccess = ($exportedFiles.Count -gt 0)
        }
    }
}
catch {
    Write-Error "Failed to export report: $_"
    exit 1
}
finally {
    # Restore original PSScriptRoot if it was changed
    if ($outputPath -and $script:originalScriptRoot) {
        $script:PSScriptRoot = $script:originalScriptRoot
    }
}

# Display summary of exported files
if ($exportSuccess) {
    Write-Host "`n=== Export Summary ===" -ForegroundColor Green
    Write-Host "Successfully exported $($exportedFiles.Count) file(s):" -ForegroundColor Green
    foreach ($file in $exportedFiles) {
        Write-Host "  - $file" -ForegroundColor Gray
    }
    Write-Host "`nProcess report generation completed successfully!" -ForegroundColor Green
} else {
    Write-Error "Failed to export any reports"
    exit 1
}

exit 0