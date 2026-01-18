<#
.SYNOPSIS
    Verifies the conversion statistics between Bluecoins HTML export and Cashew CSV import. 
.DESCRIPTION
    This script reads a Bluecoins HTML export file and a Cashew CSV import file,
    compares the number of transactions and Transactions amounts, and checks for income logic consistency.
.PARAMETER bluecoinsFile
    The filename of the Bluecoins HTML export file (will be read from .\bluecoins folder).
.PARAMETER cashewFile
    The filename of the Cashew CSV import file (will be read from .\cashew folder).
.EXAMPLE
    .\Verify.ps1 -bluecoinsFile "transactions.html" -cashewFile "cashew_import.csv"
#>
param(
    [CmdletBinding()]
    [Parameter(Mandatory = $true)] $bluecoinsFile,
    [Parameter(Mandatory = $true)] $cashewFile
)


# Construct full paths
$bluecoinsFile = Join-Path ".\bluecoins" $bluecoinsFile
$cashewFile = Join-Path ".\cashew" $cashewFile

# Check if Bluecoins file exists
if (-not (Test-Path $bluecoinsFile)) {
    Write-Error "Bluecoins file '$bluecoinsFile' not found."
    exit 1
}

# Check if Cashew file exists
if (-not (Test-Path $cashewFile)) {
    Write-Error "Cashew file '$cashewFile' not found."
    exit 1
}

# CSV delimiter used in Cashew CSV
$csvDelimiter = ','

Write-Host "Verifying conversion statistics..."

# --- Analyze Input (HTML) ---
if (-not (Test-Path $bluecoinsFile)) {
    Write-Error "Input file '$bluecoinsFile' not found."
    exit 1
}

$content = Get-Content $bluecoinsFile -Raw -Encoding UTF8
# Regex to parse rows (same as conversion script)
$pattern = '(?s)<tr>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td.*?>(.*?)</td>\s*</tr>'
$mymatches = [regex]::Matches($content, $pattern)

$inputCount = 0
[decimal]$bluecoinsSum = 0.0

foreach ($match in $mymatches) {
    if ($match.Groups[1].Value -eq "Date") { continue }
    
    $inputCount++

    $amountStr = $match.Groups[4].Value.Trim() -replace '\s+', ''
    
    # Parse Amount, remove extra separators (European format: 1.000,50)
    $cleanAmountStr = $amountStr.Replace('.', '').Replace(',', '.')

    try {
        [decimal]$cleanAmount = $cleanAmountStr
        $bluecoinsSum += $cleanAmount
    }
    catch {
        Write-Warning "Could not parse input amount: '$amountStr' (cleaned: '$cleanAmountStr')"
    }
}

# --- Analyze Output (CSV) ---
$csvData = Import-Csv -Path $cashewFile -Delimiter $csvDelimiter -Encoding UTF8
$outputCount = $csvData.Count
[decimal]$cashewSum = 0.0
$incomeErrorCount = 0


# Check Headers
$headers = $csvData[0].PSObject.Properties.Name
$expectedHeaders = "account", "amount", "currency", "title", "note", "date", "income", "type", "category name", "subcategory name", "color", "icon", "emoji", "budget", "objective"
foreach ($h in $expectedHeaders) {
    if ($headers -notcontains $h) {
        Write-Warning "Missing Header: $h"
    }
}

foreach ($row in $csvData) {
    # Amount validation
    try {
        [decimal]$amount = $row.Amount
        $cashewSum += $amount

        # Income Logic Check
        if ($amount -gt 0 -and $row.income -ne "true") {
            $incomeErrorCount++
            if ($incomeErrorCount -lt 3) { Write-Warning "Income logic error row: Amount=$amount, Income=$($row.income)" }
        }
        if ($amount -le 0 -and $row.income -ne "false") {
            $incomeErrorCount++ 
            if ($incomeErrorCount -lt 3) { Write-Warning "Income logic error row: Amount=$amount, Income=$($row.income)" }
        }
    }
    catch {
        Write-Warning "Could not parse CSV amount: '$($row.Amount)'"
    }
}

# --- Report ---
Write-Host "`n--- Results ---"
Write-Host "Bluecoins HTML Transactions Count: $inputCount"
Write-Host "Cashew CSV Transactions Count: $outputCount"

$diffCount = $inputCount - $outputCount
if ($diffCount -eq 0) {
    Write-Host "Transactions Count Check: MATCH" -ForegroundColor Green
}
else {
    Write-Host "Transactions Count Check: MISMATCH (Diff: $diffCount)" -ForegroundColor Red
}

Write-Host "`nBluecoins HTML Transactions Amount: $bluecoinsSum"
Write-Host "Cashew CSV Transactions Amount: $cashewSum"

$diffSum = [math]::Round($bluecoinsSum - $cashewSum, 2)
if ($diffSum -eq 0) {
    Write-Host "Transactions Amount Check: MATCH" -ForegroundColor Green
}
else {
    Write-Host "Transactions Amount Check: MISMATCH (Diff: $diffSum)" -ForegroundColor Red
}

if ($incomeErrorCount -eq 0) {
    Write-Host "Income Logic Check: PASS" -ForegroundColor Green
}
else {
    Write-Host "Income Logic Check: FAIL ($incomeErrorCount errors)" -ForegroundColor Red
}
