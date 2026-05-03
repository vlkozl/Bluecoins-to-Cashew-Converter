<#
.SYNOPSIS
    Generates or updates the category mapping CSV for Bluecoins-to-Cashew conversion.
.DESCRIPTION
    Reads a Bluecoins HTML export and scaffolds tools/category-mapping.csv with
    all unique bluecoins_type + bluecoins_subcategory pairs found. By default merges
    with an existing mapping so user-filled cashew_category values are preserved.
    Use -Overwrite to regenerate from scratch.
.PARAMETER bluecoinsFile
    The filename of the Bluecoins HTML export file (read from .\bluecoins folder).
.PARAMETER Overwrite
    If set, ignore any existing category-mapping.csv and regenerate entirely from HTML.
.EXAMPLE
    .\Create-CategoryMapping.ps1 -bluecoinsFile "transactions.html"
.EXAMPLE
    .\Create-CategoryMapping.ps1 -bluecoinsFile "transactions.html" -Overwrite
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

    [switch]$Overwrite
)

Import-Module (Join-Path $PSScriptRoot "Common.psm1") -Force

$ToolsDir     = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\tools"))
$BluecoinsDir = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\bluecoins"))
Initialize-Directory -Path $ToolsDir
Initialize-Directory -Path $BluecoinsDir

# Construct paths
$bluecoinsPath = Join-Path $BluecoinsDir $bluecoinsFile
Assert-FileExists -Path $bluecoinsPath -Label "Input file"
$mappingFile = Join-Path $ToolsDir "category-mapping.csv"

# Load existing mapping (unless -Overwrite)
$existingMapping = @{}   # key: "bluecoins_type|bluecoins_subcategory" -> PSCustomObject row
$existingCount = 0

if (-not $Overwrite -and (Test-Path $mappingFile)) {
    Import-Csv $mappingFile | ForEach-Object {
        $key = "$($_.bluecoins_type)|$($_.bluecoins_subcategory)"
        $existingMapping[$key] = $_
        $existingCount++
    }
}

# Parse HTML
$content = Get-Content $bluecoinsPath -Raw -Encoding UTF8
$regexMatches = Get-BluecoinsRows -Content $content

# Collect unique type|category pairs from HTML
$htmlPairs = [System.Collections.Generic.Dictionary[string, hashtable]]::new()

foreach ($match in $regexMatches) {
    $type = $match.Groups[2].Value.Trim()
    $category = $match.Groups[6].Value.Trim()

    if ([string]::IsNullOrWhiteSpace($category)) { continue }

    $key = "$type|$category"
    if (-not $htmlPairs.ContainsKey($key)) {
        $htmlPairs[$key] = @{ type = $type; category = $category }
    }
}

# Merge: start with all existing rows, append new ones
$allRows = [System.Collections.Generic.List[object]]::new()
$newCount = 0

# Add existing rows first (preserves user edits)
foreach ($row in $existingMapping.Values) {
    $allRows.Add($row)
}

# Append rows for pairs not already in existing mapping
foreach ($pair in $htmlPairs.Values) {
    $key = "$($pair.type)|$($pair.category)"
    if (-not $existingMapping.ContainsKey($key)) {
        if ($pair.type -notin @('Expense', 'Income', 'Transfer')) {
            Write-Host "WARNING: Unknown bluecoins_type '$($pair.type)' for category '$($pair.category)'. Row added but cashew_category must be set manually." -ForegroundColor Yellow
        }

        $allRows.Add([PSCustomObject]@{
                bluecoins_type        = $pair.type
                bluecoins_subcategory = $pair.category
                cashew_category       = ""
                cashew_subcategory    = $pair.category
            })
        $newCount++
    }
}

# Sort: Expense -> Income -> Transfer -> other, then cashew_category, cashew_subcategory
$typeOrder = @{ 'Expense' = 0; 'Income' = 1; 'Transfer' = 2 }
$allRows = $allRows | Sort-Object {
    $order = $typeOrder[$_.bluecoins_type]
    if ($null -eq $order) { $order = 99 }
    $order
}, cashew_category, cashew_subcategory

# Write output CSV (sanitize all fields to prevent CSV corruption with -UseQuotes Never)
$allRows | ForEach-Object {
    [PSCustomObject]@{
        bluecoins_type        = Protect-CsvField $_.bluecoins_type
        bluecoins_subcategory = Protect-CsvField $_.bluecoins_subcategory
        cashew_category       = Protect-CsvField $_.cashew_category
        cashew_subcategory    = Protect-CsvField $_.cashew_subcategory
    }
} | Export-Csv -Path $mappingFile -NoTypeInformation -Delimiter ',' -Encoding UTF8 -UseQuotes Never

# Console output
Write-Host "Category mapping complete."
Write-Host "  Existing rows preserved: $existingCount"
Write-Host "  New rows added: $newCount"
Write-Host "Output saved to $mappingFile"
