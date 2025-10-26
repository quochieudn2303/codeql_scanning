#!/usr/bin/env pwsh
<#
.SYNOPSIS
    One-shot setup script for CodeQL CLI
.DESCRIPTION
    Downloads and sets up CodeQL CLI with the latest version that supports
    C/C++ scanning without building (build-mode: none)
#>

param(
    [string]$InstallDir = "$PSScriptRoot\codeql-home"
)

$ErrorActionPreference = "Stop"

Write-Host "=== CodeQL Setup Script ===" -ForegroundColor Cyan
Write-Host "Installing CodeQL to: $InstallDir" -ForegroundColor Yellow

# Create installation directory
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Write-Host "Created directory: $InstallDir" -ForegroundColor Green
}

# Download CodeQL CLI
$codeqlZip = Join-Path $InstallDir "codeql.zip"
$codeqlUrl = "https://github.com/github/codeql-cli-binaries/releases/latest/download/codeql-win64.zip"

Write-Host "`nDownloading CodeQL CLI..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $codeqlUrl -OutFile $codeqlZip -UseBasicParsing
    Write-Host "Downloaded CodeQL CLI successfully" -ForegroundColor Green
} catch {
    Write-Host "Error downloading CodeQL: $_" -ForegroundColor Red
    exit 1
}

# Extract CodeQL
Write-Host "`nExtracting CodeQL..." -ForegroundColor Yellow
try {
    Expand-Archive -Path $codeqlZip -DestinationPath $InstallDir -Force
    Write-Host "Extracted CodeQL successfully" -ForegroundColor Green
    Remove-Item $codeqlZip -Force
} catch {
    Write-Host "Error extracting CodeQL: $_" -ForegroundColor Red
    exit 1
}

# Set up CodeQL binary path
$codeqlBin = Join-Path $InstallDir "codeql\codeql.exe"

if (Test-Path $codeqlBin) {
    Write-Host "`nVerifying CodeQL installation..." -ForegroundColor Yellow
    & $codeqlBin version
    Write-Host "`nCodeQL installed successfully!" -ForegroundColor Green
} else {
    Write-Host "Error: CodeQL binary not found at $codeqlBin" -ForegroundColor Red
    exit 1
}

# Clone CodeQL standard queries repository
$queriesDir = Join-Path $InstallDir "codeql-repo"
Write-Host "`nCloning CodeQL standard queries..." -ForegroundColor Yellow

if (Test-Path $queriesDir) {
    Write-Host "Queries directory already exists, updating..." -ForegroundColor Yellow
    Push-Location $queriesDir
    git pull
    Pop-Location
} else {
    try {
        git clone --depth 1 https://github.com/github/codeql.git $queriesDir
        Write-Host "Cloned CodeQL queries successfully" -ForegroundColor Green
    } catch {
        Write-Host "Error cloning queries: $_" -ForegroundColor Red
        Write-Host "Make sure git is installed and available in PATH" -ForegroundColor Yellow
        exit 1
    }
}

# Create config file for easier scanning
$configContent = @"
name: cpp-security-and-quality

queries:
  - uses: security-and-quality

# C/C++ specific configuration
paths-ignore:
  - "**/test/**"
  - "**/tests/**"
  - "**/build/**"
  - "**/node_modules/**"
"@

$configFile = Join-Path $PSScriptRoot "codeql-config.yml"
Set-Content -Path $configFile -Value $configContent -Encoding UTF8
Write-Host "`nCreated CodeQL config file: $configFile" -ForegroundColor Green

# Create environment setup script
$envScript = @"
# Add CodeQL to PATH for this session
`$env:PATH = "$InstallDir\codeql;`$env:PATH"
`$env:CODEQL_HOME = "$InstallDir"
Write-Host "CodeQL environment configured!" -ForegroundColor Green
Write-Host "CodeQL binary: $codeqlBin" -ForegroundColor Yellow
"@

$envFile = Join-Path $PSScriptRoot "setup-env.ps1"
Set-Content -Path $envFile -Value $envScript -Encoding UTF8
Write-Host "Created environment setup script: $envFile" -ForegroundColor Green

Write-Host "`n=== Setup Complete! ===" -ForegroundColor Cyan
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Run: . .\setup-env.ps1   (to add CodeQL to your PATH)"
Write-Host "2. Run: .\scan-cpp.ps1 <path-to-your-cpp-project>" -ForegroundColor Green
Write-Host "`nCodeQL Home: $InstallDir" -ForegroundColor Yellow
Write-Host "CodeQL Binary: $codeqlBin" -ForegroundColor Yellow
Write-Host "Queries: $queriesDir" -ForegroundColor Yellow
