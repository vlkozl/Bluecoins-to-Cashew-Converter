<#
.SYNOPSIS
    Converts Bluecoins HTML export to Cashew CSV format.
.DESCRIPTION
    This script reads a Bluecoins HTML export file, extracts transaction data,
    and converts it into a CSV format compatible with Cashew.
.PARAMETER bluecoinsFile
    The filename of the Bluecoins HTML export file (will be read from .\bluecoins folder).
.PARAMETER cashewFile
    The filename for the converted Cashew CSV file (will be saved to .\cashew folder).
.EXAMPLE
    .\Convert.ps1 -bluecoinsFile "transactions.html" -cashewFile "cashew_import.csv"
#>
param(
    [CmdletBinding()]
    [Parameter(Mandatory = $true)] $bluecoinsFile,
    [Parameter(Mandatory = $true)] $cashewFile
)

# Construct full paths
$bluecoinsFile = Join-Path ".\bluecoins" $bluecoinsFile
$cashewFile = Join-Path ".\cashew" $cashewFile

# CSV delimiter used in Cashew
$csvDelimiter = ','

# Check if input file exists
if (-not (Test-Path $bluecoinsFile)) {
    Write-Error "Input file '$bluecoinsFile' not found."
    exit 1
}

# Read content
$content = Get-Content $bluecoinsFile -Raw -Encoding UTF8

# Regex to parse rows
# Table structure: <tr>...<td>Date</td><td>Type</td><td>Name</td><td>Amount</td><td>Currency</td><td>Category</td><td>Account</td><td class="notes">Notes</td>...</tr>
$pattern = '(?s)<tr>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td.*?>(.*?)</td>\s*</tr>'

$regexMatches = [regex]::Matches($content, $pattern)

$cashewData = @()

foreach ($match in $regexMatches) {
    # Skip header row
    if ($match.Groups[1].Value -eq "Date") { continue }

    $dateStr = $match.Groups[1].Value.Trim()
    $name = $match.Groups[3].Value.Trim()
    $amountStr = $match.Groups[4].Value.Trim()
    $currency = $match.Groups[5].Value.Trim()
    $category = $match.Groups[6].Value.Trim()
    $account = $match.Groups[7].Value.Trim()
    $notes = $match.Groups[8].Value.Trim().replace(",", ".") # Update to your locale format if needed

    # If a $category is (Transfer), replace it with Cashew-specific "Balance Correction" category
    if ($category -eq "(Transfer)") {
        $category = "Balance Correction"
    }

    # Parse Date (dd.MM.yy -> yyyy-MM-dd HH:mm:ss)
    try {
        $dateObj = [DateTime]::ParseExact($dateStr, "dd.MM.yy", $null) # Update to your locale format if needed
        # Template example: 2025-12-16 23:30:21
        $outputDate = $dateObj.ToString("yyyy-MM-dd HH:mm:ss")
    }
    catch {
        Write-Warning "Could not parse date: $dateStr"
        $outputDate = $dateStr
    }

    # Parse Amount, remove extra separators
    # Format: -1.000,50 -> Output: -1000,50
    $calcAmountStr = $amountStr -replace '\s+', ''
    $calcAmountStr = $calcAmountStr.Replace('.', '')
    
    # Calculation requires dot decimal
    $cleanAmountStr = $calcAmountStr.Replace(',', '.')
    $amountVal = $cleanAmountStr -as [double]

    # Determine Income (true/false)
    if ($amountVal -gt 0) {
        $income = "true"
    }
    else {
        $income = "false"
    }

    # Clean up Notes
    $notes = $notes -replace '\s+', ' '
    $notes = $notes.Trim()

    # Determine category mapping
    if ($category -eq "Balance Correction") {
        $categoryName = $category
        $subcategoryName = ""
    }
    else {
        $categoryName = ""
        $subcategoryName = $category
    }    

    # Construct object mapping to template
    $cashewTransaction = [PSCustomObject]@{
        'account' = $account
        'amount' = $cleanAmountStr
        'currency' = $currency
        'title' = $name
        'note' = $notes
        'date' = $outputDate
        'income' = $income
        'type' = "null"
        'category name' = $categoryName
        'subcategory name' = $subcategoryName
        'color' = ""
        'icon' = ""
        'emoji' = ""
        'budget' = ""
        'objective' = ""
    }

    $cashewData += $cashewTransaction
}

# Export to CSV w/ Comma delimiter
$cashewData | Export-Csv -Path $cashewFile -NoTypeInformation -Delimiter $csvDelimiter -Encoding UTF8 -UseQuotes Never

Write-Host "Conversion complete. Processed $($cashewData.Count) transactions. Output saved to $cashewFile" -ForegroundColor Green