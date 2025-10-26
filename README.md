# CodeQL C/C++ Scanner Setup

This repository contains scripts to set up and run CodeQL scanning for C/C++ projects without requiring a build, using the new `build-mode: none` feature available in CodeQL 2.23.3+.

## Features

- ✅ **No Build Required**: Scan C/C++ code without compilation
- ✅ **One-Shot Setup**: Automated CodeQL CLI installation
- ✅ **Easy Scanning**: Simple script to scan any C/C++ project
- ✅ **Multiple Formats**: Output results in SARIF, CSV, or JSON
- ✅ **Security & Quality**: Runs comprehensive security and code quality queries

## Prerequisites

- Windows with PowerShell 5.1 or PowerShell Core 7+
- Git (for cloning CodeQL query packs)
- Internet connection (for initial setup)

## Quick Start

### 1. Set Up CodeQL

Run the setup script once to install CodeQL CLI and queries:

```powershell
.\setup-codeql.ps1
```

This will:
- Download the latest CodeQL CLI for Windows
- Extract it to `codeql-home` directory
- Clone the CodeQL standard queries repository
- Create configuration files

### 2. Configure Environment (Optional)

To add CodeQL to your PATH for the current session:

```powershell
. .\setup-env.ps1
```

### 3. Scan Your C/C++ Project

```powershell
.\scan-cpp.ps1 -ProjectPath "C:\path\to\your\cpp\project"
```

Or scan a project in the current directory:

```powershell
.\scan-cpp.ps1 -ProjectPath ".\my-project"
```

## Advanced Usage

### Custom Output Directory

```powershell
.\scan-cpp.ps1 -ProjectPath ".\my-project" -OutputDir ".\custom-results"
```

### Different Output Formats

```powershell
# CSV format
.\scan-cpp.ps1 -ProjectPath ".\my-project" -Format csv

# JSON format
.\scan-cpp.ps1 -ProjectPath ".\my-project" -Format json

# SARIF format (default, GitHub compatible)
.\scan-cpp.ps1 -ProjectPath ".\my-project" -Format sarif
```

### Custom Database Name

```powershell
.\scan-cpp.ps1 -ProjectPath ".\my-project" -DatabaseName "my-custom-db"
```

## How It Works

### Build Mode: None

CodeQL 2.23.3 introduced `build-mode: none` for C/C++, which allows scanning without compiling the project. This is particularly useful for:

- Large codebases where building is complex
- Projects with multiple build configurations
- Quick security checks during development
- CI/CD pipelines where build setup is complicated

### Scanning Process

1. **Database Creation**: CodeQL extracts the source code structure without building
2. **Analysis**: Runs security and quality queries against the database
3. **Results**: Generates a report in your chosen format

## Output Files

After scanning, you'll find:

```
codeql-results/
├── cpp-database/          # CodeQL database
└── scan-results-*.sarif   # Scan results (timestamped)
```

## SARIF Results

SARIF (Static Analysis Results Interchange Format) files can be:
- Viewed in VS Code with the SARIF Viewer extension
- Uploaded to GitHub for code scanning alerts
- Integrated with other security tools

## Troubleshooting

### CodeQL Not Found

If you get "CodeQL not found" error, make sure you ran `setup-codeql.ps1` first.

### Git Not Installed

The setup script requires Git to clone the queries repository. Install Git from: https://git-scm.com/

### No C/C++ Files Found

Ensure your project path contains `.c`, `.cpp`, `.cc`, `.cxx`, `.h`, `.hpp` files.

### Build Mode Issues

If you need to scan with a build (older CodeQL versions or specific scenarios):

```powershell
# Modify scan-cpp.ps1 to remove --build-mode=none
# and add build commands
```

## References

- [CodeQL 2.23.3 Announcement](https://github.blog/changelog/2025-10-23-codeql-2-23-3-adds-a-new-rust-query-rust-support-and-easier-c-c-scanning/)
- [CodeQL Documentation](https://codeql.github.com/docs/)
- [CodeQL C/C++ Analysis](https://codeql.github.com/docs/codeql-language-guides/codeql-for-c-cpp/)

## License

These scripts are provided as-is for use with GitHub CodeQL.
