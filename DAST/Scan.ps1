<#
.SYNOPSIS
  Full end-to-end DAST scan + report + SSC upload via Fortify ConfigurationToolCLI.

.DESCRIPTION
  Requires:
    - DAST.ConfigurationToolCLI.exe in the same folder
    - MyScanSettings.json configured
    - .NET 6+ runtime installed
#>

param(
  [string]$CliExe      = ".\DAST.ConfigurationToolCLI.exe",
  [string]$Settings    = ".\MyScanSettings.json",
  [int]   $PollSeconds = 10
)

# 1. Start the scan
Write-Host "Starting DAST scan..."
$startOutput = & $CliExe scan `
    -settings $Settings `
    -start

if ($startOutput -match 'Scan ID:\s*(\d+)') {
    $scanId = $Matches[1]
    Write-Host "✅ Scan launched: ID $scanId"
} else {
    Write-Error "❌ Failed to parse Scan ID from:`n$startOutput"
    exit 1
}

# 2. Poll for status
$status = ""
do {
    Start-Sleep -Seconds $PollSeconds
    $status = & $CliExe scan -id $scanId -status
    Write-Host "Status: $status"
} until ($status -in 'Completed','Failed')

if ($status -ne 'Completed') {
    Write-Warning "Scan ended with status: $status"
}

# 3. Generate HTML report
$reportFile = "Scan_${scanId}.html"
Write-Host "Generating report ($reportFile)..."
& $CliExe report `
    -id $scanId `
    -format html `
    -output $reportFile

Write-Host "✅ Report written to: $PWD\$reportFile"

# 4. Upload to Fortify SSC
Write-Host "Uploading scan to Fortify SSC..."
& $CliExe ssc upload `
    -settings $Settings `
    -id $scanId

Write-Host "✅ Scan $scanId pushed to SSC."
