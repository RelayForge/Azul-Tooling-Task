# Process Report Visualization Guide - PSWriteHTML

This guide provides simple methods to create interactive HTML visualizations from your process reports using PSWriteHTML.

## Prerequisites

### Required PowerShell Modules

Install the following modules from PSGallery:

```powershell
# Install PSWriteHTML module
Install-Module -Name PSWriteHTML -Force -AllowClobber

# Verify installation
Get-Module -Name PSWriteHTML -ListAvailable
```

**Module Version**: PSWriteHTML 0.0.183 or later

## Quick Start

### Basic HTML Report from CSV

```powershell
# Import modules
Import-Module PSWriteHTML

# Read CSV data
$processData = Import-Csv "reports/ProcessReport_COMPUTER_20250617_120000.csv"

# Create simple HTML report
New-HTML -TitleText "Process Report Visualization" -FilePath "reports/ProcessReport_Visual.html" {
    New-HTMLSection -HeaderText "Process Overview" {
        New-HTMLTable -DataTable $processData -ScrollX -Buttons @('copyHtml5', 'excelHtml5', 'csvHtml5')
    }
} -ShowHTML
```

### Basic HTML Report from JSON

```powershell
# Read JSON data
$jsonData = Get-Content "reports/ProcessReport_COMPUTER_20250617_120000.json" | ConvertFrom-Json
$processData = $jsonData.processes

# Create HTML report
New-HTML -TitleText "Process Report" -FilePath "reports/ProcessReport_Visual.html" {
    New-HTMLTable -DataTable $processData
} -ShowHTML
```

## Visualization Examples

### 1. Processes Per User (Bar Chart)

```powershell
# Read data
$processData = Import-Csv "reports/ProcessReport_COMPUTER_20250617_120000.csv"

# Group by user
$userStats = $processData | Group-Object User | Select-Object @{
    Name='User'; Expression={$_.Name}
}, @{
    Name='ProcessCount'; Expression={$_.Count}
} | Sort-Object ProcessCount -Descending

# Create visualization
New-HTML -TitleText "Processes Per User" -FilePath "reports/ProcessesPerUser.html" {
    New-HTMLChart {
        New-ChartBar -Name "Process Count" -Value $userStats.ProcessCount
    } -Title "Number of Processes per User" -TitleAlignment center -DataLabelsEnabled $true
} -ShowHTML
```

### 2. Top Memory Consumers (Horizontal Bar Chart)

```powershell
# Get top 10 memory consumers
$topMemory = Import-Csv "reports/ProcessReport_COMPUTER_20250617_120000.csv" | 
    Sort-Object {[double]$_.WorkingSetMB} -Descending | 
    Select-Object -First 10

# Create chart
New-HTML -TitleText "Memory Usage Analysis" -FilePath "reports/TopMemory.html" {
    New-HTMLChart -Gradient {
        New-ChartBarOptions -Type barh
        New-ChartBar -Name $topMemory.ProcessName -Value $topMemory.WorkingSetMB
    } -Title "Top 10 Memory Consumers (MB)"
} -ShowHTML
```

### 3. Combined Dashboard

```powershell
# Load data
$data = Import-Csv "reports/ProcessReport_COMPUTER_20250617_120000.csv"

# Calculate statistics
$totalProcesses = $data.Count
$uniqueUsers = ($data.User | Select-Object -Unique).Count
$totalMemoryGB = [math]::Round(($data.WorkingSetMB | Measure-Object -Sum).Sum / 1024, 2)

# Create dashboard
New-HTML -TitleText "Process Report Dashboard" -FilePath "reports/Dashboard.html" {
    # Summary cards
    New-HTMLSection -Invisible {
        New-HTMLPanel {
            New-HTMLText -Text "Total Processes" -Size 20 -Color Blue
            New-HTMLText -Text $totalProcesses -Size 30 -Color Black -FontWeight bold
        }
        New-HTMLPanel {
            New-HTMLText -Text "Unique Users" -Size 20 -Color Green
            New-HTMLText -Text $uniqueUsers -Size 30 -Color Black -FontWeight bold
        }
        New-HTMLPanel {
            New-HTMLText -Text "Total Memory (GB)" -Size 20 -Color Red
            New-HTMLText -Text $totalMemoryGB -Size 30 -Color Black -FontWeight bold
        }
    }
    
    # Charts section
    New-HTMLSection -HeaderText "Visual Analysis" {
        # Processes by user
        New-HTMLPanel {
            $userStats = $data | Group-Object User | Select-Object Name, Count
            New-HTMLChart {
                New-ChartPie -Name $userStats.Name -Value $userStats.Count
            } -Title "Processes by User"
        }
        
        # Memory distribution
        New-HTMLPanel {
            $memoryRanges = @(
                @{Range="0-100 MB"; Count=($data | Where-Object {[double]$_.WorkingSetMB -lt 100}).Count}
                @{Range="100-500 MB"; Count=($data | Where-Object {[double]$_.WorkingSetMB -ge 100 -and [double]$_.WorkingSetMB -lt 500}).Count}
                @{Range="500+ MB"; Count=($data | Where-Object {[double]$_.WorkingSetMB -ge 500}).Count}
            )
            New-HTMLChart {
                New-ChartBar -Name $memoryRanges.Range -Value $memoryRanges.Count
            } -Title "Memory Usage Distribution"
        }
    }
    
    # Detailed table
    New-HTMLSection -HeaderText "Process Details" {
        New-HTMLTable -DataTable $data -ScrollX -Buttons @('copyHtml5', 'excelHtml5') -SearchPane
    }
} -ShowHTML
```

### 4. Time-Based Analysis (If StartTime Available)

```powershell
# Process start times by hour
$data = Import-Csv "reports/ProcessReport_COMPUTER_20250617_120000.csv" | 
    Where-Object {$_.StartTime -ne "N/A"}

$hourlyStarts = $data | ForEach-Object {
    [datetime]::Parse($_.StartTime).Hour
} | Group-Object | Select-Object @{Name='Hour';Expression={$_.Name}}, Count

New-HTML -TitleText "Process Timeline" -FilePath "reports/Timeline.html" {
    New-HTMLChart {
        New-ChartLine -Name "Process Starts" -Value $hourlyStarts.Count
        New-ChartAxisX -Names (0..23)
    } -Title "Processes Started by Hour"
} -ShowHTML
```

## Quick Reference

### Minimal Table

```powershell
$data = Import-Csv "report.csv"
New-HTML {
    New-HTMLTable -DataTable $data
} -FilePath "table.html" -ShowHTML
```

### Minimal Chart

```powershell
$data = Import-Csv "report.csv" | Group-Object User
New-HTML {
    New-HTMLChart {
        New-ChartBar -Name $data.Name -Value $data.Count
    }
} -FilePath "chart.html" -ShowHTML
```

### Export Options

```powershell
# Add export buttons to tables
New-HTMLTable -DataTable $data -Buttons @('copyHtml5', 'excelHtml5', 'csvHtml5', 'pdfHtml5')

# Enable search pane
New-HTMLTable -DataTable $data -SearchPane

# Add filtering
New-HTMLTable -DataTable $data -Filtering
```

## Tips for Best Results

1. **Data Preparation**
   - Convert numeric strings to numbers: `[double]$_.WorkingSetMB`
   - Handle "N/A" values: `Where-Object {$_.User -ne "N/A"}`

2. **Performance**
   - Limit large datasets: `Select-Object -First 1000`
   - Pre-aggregate data for charts

3. **Styling**
   - Use `-ShowHTML` to auto-open in browser
   - Customize colors with `-Color` parameter
   - Add gradients with `-Gradient` switch

## Common Issues

**Issue: Module not found**
```powershell
# Ensure module is installed
Install-Module PSWriteHTML -Force -Scope CurrentUser
```

**Issue: Charts not displaying**
```powershell
# Use absolute paths for output
$outputPath = Join-Path (Get-Location) "reports/visual.html"
```

**Issue: Large datasets slow to load**
```powershell
# Paginate table data
New-HTMLTable -DataTable $data -PagingLength 25
```

## Complete Example Script

Save as `visualize-pswritehtml.ps1`:

```powershell
param(
    [string]$InputFile = "reports/ProcessReport*.csv",
    [string]$OutputFile = "reports/ProcessVisualization.html"
)

# Import module
Import-Module PSWriteHTML -ErrorAction Stop

# Find latest report
$latestReport = Get-ChildItem $InputFile | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $latestReport) {
    Write-Error "No report file found"
    exit 1
}

# Load data
Write-Host "Loading data from: $($latestReport.Name)"
$data = Import-Csv $latestReport.FullName

# Create visualization
New-HTML -TitleText "Process Report Analysis" -FilePath $OutputFile {
    # Add your visualization code here
    New-HTMLTable -DataTable $data -ScrollX
} -ShowHTML

Write-Host "Visualization saved to: $OutputFile"
```

## Next Steps

- Automate visualization generation after each report
- Create scheduled tasks for regular reporting
- Customize CSS for corporate branding
- Integrate with monitoring dashboards

---

For more advanced features, see [PSWriteHTML documentation](https://github.com/EvotecIT/PSWriteHTML).