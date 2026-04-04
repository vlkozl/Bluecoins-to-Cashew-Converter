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
    .\ConvertTo-CashewCsv.ps1 -bluecoinsFile "transactions.html" -cashewFile "cashew_import.csv"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ArgumentCompleter({
            param($cmd, $param, $word)
            Get-ChildItem -Path ".\bluecoins\" -Filter "*.html" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "$word*" } |
            ForEach-Object { $_.Name }
        })]
    [string]$bluecoinsFile,

    [Parameter(Mandatory = $true)]
    [ArgumentCompleter({
            param($cmd, $param, $word)
            Get-ChildItem -Path ".\cashew\" -Filter "*.csv" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "$word*" } |
            ForEach-Object { $_.Name }
        })]
    [string]$cashewFile
)

Import-Module (Join-Path $PSScriptRoot "Common.psm1") -Force

$BluecoinsDir = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\bluecoins"))
$CashewDir = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\cashew"))
$CategoriesDir = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\categories"))

Initialize-Directory -Path $BluecoinsDir
Initialize-Directory -Path $CashewDir
Initialize-Directory -Path $CategoriesDir

# Construct full paths
$bluecoinsFile = Join-Path $BluecoinsDir $bluecoinsFile
$cashewFile = Join-Path $CashewDir $cashewFile

# CSV delimiter used in Cashew
$csvDelimiter = ','

# Load category mapping
$mappingFile = Join-Path $CategoriesDir "category-mapping.csv"
$categoryMapping = @{}
if (Test-Path $mappingFile) {
    Import-Csv $mappingFile | ForEach-Object {
        $key = "$($_.bluecoins_type)|$($_.bluecoins_subcategory)"
        $categoryMapping[$key] = $_
    }
}
else {
    Write-Warning "Category mapping file not found: $mappingFile. Categories will not be mapped."
}

Assert-FileExists -Path $bluecoinsFile -Label "Input file"

# Read content
$content = Get-Content $bluecoinsFile -Raw -Encoding UTF8

$regexMatches = Get-BluecoinsRows -Content $content

$cashewData = [System.Collections.Generic.List[object]]::new()

foreach ($match in $regexMatches) {
    $dateStr = $match.Groups[1].Value.Trim()
    $type = $match.Groups[2].Value.Trim()
    $name = $match.Groups[3].Value.Trim()
    $amountStr = $match.Groups[4].Value.Trim()
    $currency = $match.Groups[5].Value.Trim()
    $category = $match.Groups[6].Value.Trim()
    $account = $match.Groups[7].Value.Trim()
    $notes = $match.Groups[8].Value.Trim().replace(",", ".") # Update to your locale format if needed

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

    # Parse Amount (European format: -1.000,50 -> -1000.50)
    $cleanAmountStr = ConvertTo-BluecoinsAmount $amountStr
    $amountVal = $cleanAmountStr -as [double]

    if ($null -eq $amountVal) {
        Write-Warning "Could not parse amount '$amountStr' (row: date='$dateStr', name='$name', type='$type'). Row will have empty amount and income='false'."
        $response = Read-Host "Continue processing? [Y/N]"
        if ($response -notin @('Y', 'y', '')) {
            throw "Aborted by user due to invalid amount."
        }
    }

    # Determine Income (true/false)
    $income = if ($amountVal -gt 0) { "true" } else { "false" }

    # Clean up Notes
    $notes = $notes -replace '\s+', ' '
    $notes = $notes.Trim()

    # Determine category mapping
    $mapKey = "$type|$category"
    if ($categoryMapping.ContainsKey($mapKey)) {
        $map = $categoryMapping[$mapKey]

        # Bluecoins only need subcategory for normal transactions, but for transfers we want to use the category as subcategory in Cashew and ignore the category.
        # This is because Cashew doesn't have a concept of transfer category, but we want to preserve the information from Bluecoins.
        if (!($mapKey -eq 'Transfer|(Transfer)')) {
            $categoryName = $subcategoryName
            $subcategoryName = ''
            $categoryName = $map.cashew_subcategory
            $subcategoryName = ''
        }        
        else {
            $categoryName = $map.cashew_category
            $subcategoryName = $map.cashew_subcategory
        } 
        $color = $map.color
        $icon = $map.icon
    }
    else {
        Write-Warning "No mapping found for: type='$type' category='$category'. Leaving category empty."
        $categoryName = ""
        $subcategoryName = $category
        $color = ""
        $icon = ""
    }

    # Construct object mapping to template
    $cashewTransaction = [PSCustomObject]@{
        'account'          = $account
        'amount'           = $cleanAmountStr
        'currency'         = $currency
        'title'            = $name
        'note'             = $notes
        'date'             = $outputDate
        'income'           = $income
        'type'             = "null"
        'category name'    = $categoryName
        'subcategory name' = $subcategoryName
        'color'            = $color
        'icon'             = $icon
        'emoji'            = ""
        'budget'           = ""
        'objective'        = ""
    }

    $cashewData.Add($cashewTransaction)
}

# Export to CSV w/ Comma delimiter
$cashewData | Export-Csv -Path $cashewFile -NoTypeInformation -Delimiter $csvDelimiter -Encoding UTF8 -UseQuotes Never

Write-Host "Conversion complete." -ForegroundColor Green
Write-Host "Processed $($cashewData.Count) transactions." -ForegroundColor Green
Write-Host "Output saved to $cashewFile" -ForegroundColor Green