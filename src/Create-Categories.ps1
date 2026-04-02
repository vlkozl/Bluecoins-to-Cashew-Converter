<#
.SYNOPSIS
    Extracts categories from Bluecoins HTML export and creates a markdown file.
.DESCRIPTION
    This script reads a Bluecoins HTML export file, extracts all unique categories
    from transaction data, and outputs a markdown file for reference.
.PARAMETER bluecoinsFile
    The filename of the Bluecoins HTML export file (will be read from .\bluecoins folder).
.PARAMETER categoriesFile
    The filename for the resulting categories markdown file (will be saved to .\ folder).
.EXAMPLE
    .\Create-Categories.ps1 -bluecoinsFile "transactions.html" -categoriesFile "Bluecoins Categories.md"
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
        Get-ChildItem -Path ".\" -Filter "*.md" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "$word*" } |
            ForEach-Object { $_.Name }
    })]
    [string]$categoriesFile
)

Import-Module (Join-Path $PSScriptRoot "Common.psm1") -Force

# Construct full paths
$bluecoinsFile = Join-Path ".\bluecoins" $bluecoinsFile
$outDir = ".\"
$categoriesFile = Join-Path $outDir $categoriesFile

Assert-FileExists -Path $bluecoinsFile -Label "Input file"

# Read content
$content = Get-Content $bluecoinsFile -Raw -Encoding UTF8

$regexMatches = Get-BluecoinsRows -Content $content

$categoryStats = @{}  # hashtable to store: key=category, value=@{type=..., count=...}

foreach ($match in $regexMatches) {
    $type = $match.Groups[2].Value.Trim()
    $category = $match.Groups[6].Value.Trim()
    
    # Skip empty categories
    if ([string]::IsNullOrWhiteSpace($category)) { 
        continue
    }
    
    # Map Bluecoins Type to general category
    $generalCategory = switch ($type) {
        "Expense" { "Expenses" }
        "Income" { "Income" }
        default { $type }
    }

    # Create key for hashtable
    $key = "$($generalCategory)::$($category)"
    
    if (-not $categoryStats.ContainsKey($key)) {
        $categoryStats[$key] = @{
            category = $category
            general = $generalCategory
            count = 0
        }
    }
    
    $categoryStats[$key].count++
}

# Group by general category and sort by count
$expenseCategories = [System.Collections.Generic.List[object]]::new()
$incomeCategories = [System.Collections.Generic.List[object]]::new()

foreach ($stat in $categoryStats.Values) {
    $item = @{
        name = $stat.category
        count = $stat.count
    }
    
    switch ($stat.general) {
        "Expenses" { $expenseCategories.Add($item) }
        "Income" { $incomeCategories.Add($item) }
    }
}

# Sort each group by count (descending)
$expenseCategories = $expenseCategories | Sort-Object -Property count -Descending
$incomeCategories = $incomeCategories | Sort-Object -Property count -Descending

# Generate markdown content
$markdown = @()
$markdown += "# Bluecoins Categories"
$markdown += ""
$markdown += "This file contains all unique categories extracted from Bluecoins transactions, sorted by frequency."
$markdown += "Bluecoins export does not have Category Groups, so categories are listed flat."
$markdown += ""
$markdown += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$markdown += ""

# Expenses section
$markdown += "## Expenses"
$markdown += ""
foreach ($cat in $expenseCategories) {
    $markdown += "- $($cat.name)"
}
$markdown += ""

# Income section
$markdown += "## Income"
$markdown += ""
foreach ($cat in $incomeCategories) {
    $markdown += "- $($cat.name)"
}
$markdown += ""

# Write to file
$markdown | Out-File -FilePath $categoriesFile -Encoding UTF8

$totalCategories = $expenseCategories.Count + $incomeCategories.Count
Write-Host "Categories extraction complete." -ForegroundColor Green
Write-Host "  Expenses: $($expenseCategories.Count)" -ForegroundColor Cyan
Write-Host "  Income: $($incomeCategories.Count)" -ForegroundColor Cyan
Write-Host "  Total: $totalCategories categories" -ForegroundColor Cyan
Write-Host "Output saved to $categoriesFile" -ForegroundColor Green
