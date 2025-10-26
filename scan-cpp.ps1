#!/usr/bin/env pwsh
<#
.SYNOPSIS
    CodeQL scanning script for C/C++ projects
.DESCRIPTION
    Scans C/C++ projects using CodeQL without requiring a build (build-mode: none).
    This uses the new feature available in CodeQL 2.23.3+
.PARAMETER ProjectPath
    Path to the C/C++ project to scan
.PARAMETER OutputDir
    Directory to store scan results (default: codeql-results)
.PARAMETER Format
    Output format: sarif, csv, or json (default: sarif)
.EXAMPLE
    .\scan-cpp.ps1 -ProjectPath "C:\MyProject"
.EXAMPLE
    .\scan-cpp.ps1 -ProjectPath ".\my-cpp-app" -Format csv
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

Write-Host "=== CodeQL C/C++ Scanner ===" -ForegroundColor Cyan
Write-Host "Project: $ProjectPath" -ForegroundColor Yellow
Write-Host "Output: $OutputDir" -ForegroundColor Yellow

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
$outputFile = Join-Path $OutputDir "scan-results-$timestamp.$fileExtension"

# Step 1: Create CodeQL Database (without build!)
Write-Host "`n[Step 1/3] Creating CodeQL database..." -ForegroundColor Yellow
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

# Step 2: Analyze the database
Write-Host "`n[Step 2/3] Analyzing code with security queries..." -ForegroundColor Yellow

try {
    & $codeqlBin database analyze $dbPath `
        "$queriesDir\cpp\ql\src\codeql-suites\cpp-security-and-quality.qls" `
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
Write-Host "`n[Step 3/3] Scan Results" -ForegroundColor Yellow
Write-Host "Results saved to: $outputFile" -ForegroundColor Green

# If SARIF format, try to show a summary
if (($Format -like "sarif*") -and (Test-Path $outputFile)) {
    try {
        $sarifContent = Get-Content $outputFile -Raw | ConvertFrom-Json
        $runs = $sarifContent.runs
        
        if ($runs -and $runs.Count -gt 0) {
            $results = $runs[0].results
            if ($results) {
                Write-Host "`nFound $($results.Count) issues:" -ForegroundColor Yellow
                
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
                Write-Host "`nNo issues found! ✓" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "Could not parse SARIF results for summary" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Scan Complete! ===" -ForegroundColor Cyan
Write-Host "`nDatabase: $dbPath" -ForegroundColor Yellow
Write-Host "Results: $outputFile" -ForegroundColor Yellow

# Additional analysis commands
Write-Host "`nTip: You can query the database with:" -ForegroundColor Cyan
Write-Host "  $codeqlBin query run <query.ql> --database=$dbPath" -ForegroundColor Gray
Write-Host "`nOr generate different format:" -ForegroundColor Cyan
Write-Host "  $codeqlBin database analyze $dbPath <suite> --format=csv --output=results.csv" -ForegroundColor Gray
