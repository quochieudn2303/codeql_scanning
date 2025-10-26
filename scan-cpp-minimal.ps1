#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Minimal CodeQL C/C++ Scanner - Security queries only
.DESCRIPTION
    Runs only security queries for fast scanning (no build required).
    Perfect for quick checks on small codebases or partial file selections.
.PARAMETER ProjectPath
    Path to the C/C++ project to scan
.PARAMETER OutputDir
    Directory to store scan results (default: codeql-results)
.EXAMPLE
    .\scan-cpp-minimal.ps1 -ProjectPath ".\incomplete-files"
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$ProjectPath,
    
    [string]$OutputDir = "$PSScriptRoot\codeql-results",
    
    [string]$DatabaseName = "cpp-database"
)

$ErrorActionPreference = "Stop"

# Resolve paths
$ProjectPath = Resolve-Path $ProjectPath -ErrorAction Stop
$codeqlHome = Join-Path $PSScriptRoot "codeql-home"
$codeqlBin = Join-Path $codeqlHome "codeql\codeql.exe"
$queriesDir = Join-Path $codeqlHome "codeql-repo"

Write-Host "=== CodeQL Minimal Scanner (Security Only) ===" -ForegroundColor Cyan
Write-Host "Project: $ProjectPath" -ForegroundColor Yellow
Write-Host "Mode: Security queries only (FAST)" -ForegroundColor Green

# Verify CodeQL is installed
if (-not (Test-Path $codeqlBin)) {
    Write-Host "Error: CodeQL not found at $codeqlBin" -ForegroundColor Red
    Write-Host "Please run setup-codeql.ps1 first" -ForegroundColor Yellow
    exit 1
}

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$dbPath = Join-Path $OutputDir $DatabaseName
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputFile = Join-Path $OutputDir "minimal-scan-$timestamp.csv"

# Step 1: Create CodeQL Database
Write-Host "`n[Step 1/2] Creating CodeQL database..." -ForegroundColor Yellow

# Remove existing database if it exists
if (Test-Path $dbPath) {
    Write-Host "Removing existing database..." -ForegroundColor Yellow
    Remove-Item -Path $dbPath -Recurse -Force
}

try {
    & $codeqlBin database create $dbPath `
        --language=cpp `
        --source-root=$ProjectPath `
        --build-mode=none `
        --overwrite
    
    if ($LASTEXITCODE -ne 0) {
        throw "Database creation failed"
    }
    Write-Host "✓ Database created" -ForegroundColor Green
} catch {
    Write-Host "Error creating database: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Run security queries
Write-Host "`n[Step 2/2] Running security queries..." -ForegroundColor Yellow

# Use the security-extended suite for faster scanning
$SecuritySuite = "$queriesDir\cpp\ql\src\codeql-suites\cpp-security-extended.qls"

try {
    & $codeqlBin database analyze $dbPath `
        $SecuritySuite `
        --format=csv `
        --output=$outputFile `
        --threads=0
    
    if ($LASTEXITCODE -ne 0) {
        throw "Analysis failed"
    }
    Write-Host "✓ Analysis complete" -ForegroundColor Green
} catch {
    Write-Host "Error during analysis: $_" -ForegroundColor Red
    exit 1
}

# Display results
Write-Host "`n[Results] Minimal Scan Complete" -ForegroundColor Yellow
Write-Host "Results saved to: $outputFile" -ForegroundColor Green

if (Test-Path $outputFile) {
    try {
        $results = Import-Csv $outputFile
        $count = $results.Count
        
        if ($count -eq 0) {
            Write-Host "`n✓ No security issues found!" -ForegroundColor Green
        } else {
            Write-Host "`n⚠ Found $count security issue(s):" -ForegroundColor Yellow
            
            # Display results
            if ($count -le 20) {
                $results | Select-Object -Property Name, Severity, Message | Format-Table -AutoSize
            } else {
                Write-Host "Showing first 20 results..." -ForegroundColor Gray
                $results | Select-Object -First 20 -Property Name, Severity, Message | Format-Table -AutoSize
                Write-Host "... and $($count - 20) more. See $outputFile for full results." -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host "Could not parse results" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Scan Complete! ===" -ForegroundColor Cyan
Write-Host "`nScanned: Security queries only (optimized for speed)" -ForegroundColor Gray
Write-Host "Database: $dbPath" -ForegroundColor Yellow
Write-Host "Results: $outputFile" -ForegroundColor Yellow
Write-Host "`nFor full analysis with all 181 queries:" -ForegroundColor Cyan
Write-Host "  .\scan-cpp.ps1 -ProjectPath `"$ProjectPath`"" -ForegroundColor Gray
