# tests/test-report-generation.ps1
<#
.SYNOPSIS
    Basic Pester tests for generate-report.ps1 script.

.DESCRIPTION
    Ensures generate-report.ps1 executes successfully and generates a report file.

.NOTES
    MIT License - Copyright (c) 2025 Quantum Shepard
#>

Describe "generate-report.ps1 basic functionality" {

    BeforeAll {
        # Define paths
        $scriptPath = Join-Path $PSScriptRoot '..' 'scripts/generate-report.ps1'
        $reportsPath = Join-Path $PSScriptRoot '..' 'reports'
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $outputFile = Join-Path $reportsPath "process_report_test_$timestamp.csv"
    }

    It "Should generate a CSV report file successfully" {
        # Execute the script with CSV format
        & pwsh -File $scriptPath --format CSV --output-path $outputFile

        # Verify the report file was created
        Test-Path $outputFile | Should -BeTrue
    }

    AfterAll {
        # Cleanup test-generated report file
        if (Test-Path $outputFile) {
            Remove-Item -Path $outputFile -Force
        }
    }
}