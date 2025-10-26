#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fast CodeQL C/C++ Scanner - Security-focused queries only
.DESCRIPTION
    Runs only critical security queries for faster scanning (no build required)
.PARAMETER ProjectPath
    Path to the C/C++ project to scan
.PARAMETER OutputDir
    Directory to store scan results (default: codeql-results)
.PARAMETER Format
    Output format: sarif-latest, csv, or graphtext (default: sarif-latest)
.EXAMPLE
    .\scan-cpp-fast.ps1 -ProjectPath ".\incomplete-files"
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$ProjectPath,
    
    [string]$OutputDir = "$PSScriptRoot\codeql-results",
    
    [ValidateSet("sarif-latest", "sarifv2.1.0", "csv", "graphtext")]
    [string]$Format = "sarif-latest",
    
    [string]$DatabaseName = "cpp-database"
)

$ErrorActionPreference = "Stop"

# Resolve paths
$ProjectPath = Resolve-Path $ProjectPath -ErrorAction Stop
$codeqlHome = Join-Path $PSScriptRoot "codeql-home"
$codeqlBin = Join-Path $codeqlHome "codeql\codeql.exe"
$queriesDir = Join-Path $codeqlHome "codeql-repo"

Write-Host "=== CodeQL C/C++ Fast Scanner ===" -ForegroundColor Cyan
Write-Host "Project: $ProjectPath" -ForegroundColor Yellow
Write-Host "Output: $OutputDir" -ForegroundColor Yellow
Write-Host "Mode: Security queries only (FAST)" -ForegroundColor Green

# Verify CodeQL is installed
if (-not (Test-Path $codeqlBin)) {
    Write-Host "Error: CodeQL not found at $codeqlBin" -ForegroundColor Red
    Write-Host "Please run setup-codeql.ps1 first" -ForegroundColor Yellow
    exit 1
}

# Verify queries directory
if (-not (Test-Path $queriesDir)) {
    Write-Host "Error: CodeQL queries not found at $queriesDir" -ForegroundColor Red
    Write-Host "Please run setup-codeql.ps1 first" -ForegroundColor Yellow
    exit 1
}

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$dbPath = Join-Path $OutputDir $DatabaseName
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
# Map format to file extension
$fileExtension = switch ($Format) {
    "sarif-latest" { "sarif" }
    "sarifv2.1.0" { "sarif" }
    "csv" { "csv" }
    "graphtext" { "txt" }
    default { "sarif" }
}
$outputFile = Join-Path $OutputDir "fast-scan-$timestamp.$fileExtension"

# Step 1: Create CodeQL Database (without build!)
Write-Host "`n[Step 1/2] Creating CodeQL database..." -ForegroundColor Yellow
Write-Host "Using build-mode: none (no compilation required)" -ForegroundColor Green

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
        throw "CodeQL database creation failed with exit code $LASTEXITCODE"
    }
    Write-Host "Database created successfully!" -ForegroundColor Green
} catch {
    Write-Host "Error creating database: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Analyze with security queries only (FAST!)
Write-Host "`n[Step 2/2] Running SECURITY queries only..." -ForegroundColor Yellow
Write-Host "This will be much faster than full analysis!" -ForegroundColor Green

try {
    & $codeqlBin database analyze $dbPath `
        "$queriesDir\cpp\ql\src\codeql-suites\cpp-security-extended.qls" `
        --format=$Format `
        --output=$outputFile `
        --threads=0
    
    if ($LASTEXITCODE -ne 0) {
        throw "CodeQL analysis failed with exit code $LASTEXITCODE"
    }
    Write-Host "Analysis completed successfully!" -ForegroundColor Green
} catch {
    Write-Host "Error during analysis: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Display results
Write-Host "`n[Results] Fast Scan Complete" -ForegroundColor Yellow
Write-Host "Results saved to: $outputFile" -ForegroundColor Green

# If SARIF format, try to show a summary
if (($Format -like "sarif*") -and (Test-Path $outputFile)) {
    try {
        $sarifContent = Get-Content $outputFile -Raw | ConvertFrom-Json
        $runs = $sarifContent.runs
        
        if ($runs -and $runs.Count -gt 0) {
            $results = $runs[0].results
            if ($results) {
                Write-Host "`nFound $($results.Count) security issues:" -ForegroundColor Yellow
                
                # Group by severity
                $bySeverity = $results | Group-Object { 
                    if ($_.properties.severity) { 
                        $_.properties.severity 
                    } elseif ($_.level) {
                        $_.level
                    } else {
                        "unknown"
                    }
                }
                
                foreach ($group in $bySeverity) {
                    $color = switch ($group.Name) {
                        "error" { "Red" }
                        "warning" { "Yellow" }
                        "note" { "Cyan" }
                        default { "White" }
                    }
                    Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor $color
                }
            } else {
                Write-Host "`nNo security issues found! ✓" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "Could not parse SARIF results for summary" -ForegroundColor Yellow
    }
}

# CSV format summary
if ($Format -eq "csv" -and (Test-Path $outputFile)) {
    try {
        $csvResults = Import-Csv $outputFile
        if ($csvResults.Count -gt 0) {
            Write-Host "`nFound $($csvResults.Count) security issues" -ForegroundColor Yellow
            Write-Host "`nTop 10 issues:" -ForegroundColor Cyan
            $csvResults | Select-Object -First 10 | Format-Table -Property Name, Severity -AutoSize
        } else {
            Write-Host "`nNo security issues found! ✓" -ForegroundColor Green
        }
    } catch {
        Write-Host "Could not parse CSV results" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Fast Scan Complete! ===" -ForegroundColor Cyan
Write-Host "`nDatabase: $dbPath" -ForegroundColor Yellow
Write-Host "Results: $outputFile" -ForegroundColor Yellow
Write-Host "`nThis scan was optimized for speed by running security queries only." -ForegroundColor Green
Write-Host "For comprehensive analysis, use scan-cpp.ps1 instead." -ForegroundColor Gray
