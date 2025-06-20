# Azul-Tooling-Task-CLI

A cross-platform PowerShell Core utility that generates detailed reports of running processes on Windows and macOS. Outputs comprehensive process information including CPU usage, memory consumption, and user ownership in CSV or JSON formats with optional HTML visualizations.

## 🚀 Features

- **Cross-Platform**: Works on Windows and macOS with PowerShell Core
- **Multiple Output Formats**: CSV, JSON, and HTML visualization support
- **Comprehensive Process Data**: PID, process name, user, CPU usage, memory usage, and more
- **Performance Optimized**: Uses background jobs and CIM session reuse for fast data collection
- **Automated Environment Setup**: DSC-based configuration for dependencies
- **CI/CD Ready**: GitHub Actions pipeline with automated testing
- **MIT Licensed**: Open source with permissive licensing

## 📋 Requirements

- PowerShell Core 7.0 or higher
- Windows 10/11 or macOS 10.15+
- Internet connection for initial module installation
- Administrator privileges required for getting detailed information

## 🛠 Installation

1. **Clone the repository:**
   ```powershell
   git clone https://github.com/your-username/azul-tooling-task-cli.git
   cd azul-tooling-task-cli
   ```

2. **Set up environment (recommended):**
   ```powershell
   # Run DSC configuration for automatic setup
   pwsh ./dsc/environment.ps1
   ```
    📖 **For detailed DSC usage and configuration options, see:** [DSC Documentation](dsc/README.MD)

3. **Manual setup (alternative):**
   ```powershell
   # Install required modules
   Install-Module PSWriteHTML -Scope CurrentUser -Force
   
   # Set execution policy
   Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
   ```

## 🎯 Quick Start

### Generate Basic Report
```powershell
# CSV format (default)
pwsh ./scripts/generate-report.ps1

# JSON format
pwsh ./scripts/generate-report.ps1 -OutputFormat JSON

# Custom output location
pwsh ./scripts/generate-report.ps1 -OutputPath "C:\Reports"
```

### Master Executor (Recommended)
```powershell
# Runs DSC setup + report generation + visualization
pwsh ./executor.ps1
```

### Generate Visualization
```powershell
# Create HTML visualization from existing report
pwsh ./scripts/sample-visualization.ps1 -ReportPath "./reports/process-report_COMPUTER_2025-06-19_14-30-15.csv"
```
📊 **For comprehensive visualization guides and examples, see:** [Visualization Documentation](README_Visualization.md)

## 📊 Output Examples

### Process Report Structure
```csv
PID,ProcessName,User,CPUTimeSeconds,CPUPercent,MemoryMB,MemoryPercent,StartTime,Path
1234,chrome,john.doe,45.67,2.1,512.34,3.2,2025-06-19 14:25:10,C:\Program Files\Google\Chrome\chrome.exe
5678,powershell,SYSTEM,12.34,0.8,128.45,0.8,2025-06-19 14:20:05,C:\Windows\System32\powershell.exe
```

### Execution Summary
```
Process Report Execution Summary
Generated: 2025-06-19 14:30:15
Computer: DESKTOP-ABC123
User: john.doe
PowerShell Version: 7.4.0
OS Version: Microsoft Windows NT 10.0.22631.0

Statistics:
- Total Processes: 156
- Total Memory Usage: 8,234.56 MB
- Average Memory per Process: 52.78 MB

Top 5 CPU Consumers (by Total CPU Time):
- chrome (PID: 1234): 45.67s
- firefox (PID: 2345): 32.10s
```

## 🖥 Platform Support

### Windows
- Uses `Get-Process` cmdlet with WMI for user information
- CIM sessions for optimized performance
- Full process path resolution

### macOS
- Uses native `ps` command with PowerShell Core wrappers
- `sysctl` for system memory information
- Cross-platform data normalization

## 📈 Visualization

The tool generates interactive HTML reports with:
- Process count by user (pie chart)
- Top memory consumers (bar chart)
- CPU usage distribution (line chart)
- Process timeline (scatter plot)

```powershell
# Generate visualization
pwsh ./scripts/sample-visualization.ps1 -ReportPath "./reports/your-report.csv"
```

## 🧪 Testing

Run automated tests using Pester:

```powershell
# Install Pester (if not already installed)
Install-Module Pester -Force -SkipPublisherCheck

# Run all tests
Invoke-Pester

# Run specific test suite
Invoke-Pester -Path "./tests/test-cross-platform.tests.ps1"
```

## 🔧 Configuration

### DSC Environment Setup
The DSC configuration (`dsc/environment.ps1`) automatically:
- Creates required directories (`reports/`, `scripts/`)
- Sets PowerShell execution policy
- Installs PSWriteHTML module
- Configures PowerShell Gallery trust

### Custom Configuration
```powershell
# Custom reports directory
pwsh ./scripts/generate-report.ps1 -OutputPath "$env:USERPROFILE\MyReports"

# Exclude user information (faster execution)
pwsh ./scripts/generate-report.ps1 -SkipUserInfo

# Verbose logging for troubleshooting
pwsh ./scripts/generate-report.ps1 -Verbose
```

## 🚨 Troubleshooting

### Common Issues

**"Execution policy restriction"**
```powershell
# Solution: Set execution policy
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
```

**"Module PSWriteHTML not found"**
```powershell
# Solution: Install module
Install-Module PSWriteHTML -Scope CurrentUser -Force
```

**"Access denied" errors**
```powershell
# Solution: Run with elevated privileges or use current user scope
pwsh -Command "Start-Process pwsh -ArgumentList './scripts/generate-report.ps1' -Verb RunAs"
```

**Cross-platform path issues**
```powershell
# Use PowerShell Core's cross-platform path handling
pwsh ./scripts/generate-report.ps1 -OutputPath (Join-Path $HOME "Reports")
```

### Performance Optimization

For large systems with many processes:
```powershell
# Skip detailed user information for faster execution
pwsh ./scripts/generate-report.ps1 -SkipUserInfo

# Use background jobs for parallel processing (Windows only)
pwsh ./scripts/generate-report.ps1 -UseBackgroundJobs
```

## 🏗 CI/CD Pipeline

The project includes GitHub Actions for automated testing:

```yaml
# .github/workflows/ci.yml
name: PowerShell CI
on: [push, pull_request]
jobs:
  test:
    strategy:
      matrix:
        os: [windows-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - name: Run Tests
        shell: pwsh
        run: |
          Install-Module Pester -Force -SkipPublisherCheck
          Invoke-Pester -Path "./tests/" -OutputFormat NUnitXml -OutputFile TestResults.xml
```

## 📁 Project Structure

```
azul-tooling-task-cli/
├── scripts/
│   ├── generate-report.ps1              # Main report generation script
│   ├── sample-visualization.ps1         # HTML visualization generator
│   └── get-process-cross-platform.ps1   # Cross-platform process collection
├── dsc/
│   └── environment.ps1                  # DSC environment configuration
├── reports/
│   └── .gitkeep                        # Git tracking for reports directory
├── tests/
│   ├── basic.tests.ps1                 # Basic functionality tests
│   ├── test-cross-platform.tests.ps1   # Cross-platform testing
│   └── test-report-generation.tests.ps1 # Report generation tests
├── .github/
│   └── workflows/
│       └── ci.yml                      # GitHub Actions CI pipeline
├── executor.ps1                        # Master execution script
├── pester.config.psd1                  # Pester test configuration
├── README.md                           # This file
├── .gitignore                          # Git ignore rules
└── LICENSE                             # MIT License
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Make your changes following PowerShell best practices
4. Run tests (`Invoke-Pester`)
5. Commit your changes (`git commit -am 'Add new feature'`)
6. Push to the branch (`git push origin feature/new-feature`)
7. Create a Pull Request

### Development Guidelines

- Follow PowerShell approved verbs (Get-, Set-, New-, etc.)
- Include comprehensive error handling
- Add Pester tests for new functionality
- Maintain cross-platform compatibility
- Update documentation for new features

## 📄 License

MIT License

Copyright (c) 2025 Quantum Shepard

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/your-username/azul-tooling-task-cli/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-username/azul-tooling-task-cli/discussions)
- **Documentation**: Check the `docs/` directory for detailed guides
- **PowerShell Core**: [Official Documentation](https://docs.microsoft.com/en-us/powershell/)

---
