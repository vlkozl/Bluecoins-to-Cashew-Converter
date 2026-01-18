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
param(
    [CmdletBinding()]
    [Parameter(Mandatory = $true)] $bluecoinsFile,
    [Parameter(Mandatory = $true)] $categoriesFile
)

# Construct full paths
$bluecoinsFile = Join-Path ".\bluecoins" $bluecoinsFile
$outDir = ".\"
$categoriesFile = Join-Path $outDir $categoriesFile

# Create Out directory if it doesn't exist
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
    Write-Host "Created directory: $outDir" -ForegroundColor Cyan
}

# Check if input file exists
if (-not (Test-Path $bluecoinsFile)) {
    Write-Error "Input file '$bluecoinsFile' not found."
    exit 1
}

# Read content
$content = Get-Content $bluecoinsFile -Raw -Encoding UTF8

# Regex to parse rows - extract category (group 6)
# Table structure: <tr>...<td>Date</td><td>Type</td><td>Name</td><td>Amount</td><td>Currency</td><td>Category</td><td>Account</td><td class="notes">Notes</td>...</tr>
$pattern = '(?s)<tr>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td.*?>(.*?)</td>\s*</tr>'

$regexMatches = [regex]::Matches($content, $pattern)

$categoryStats = @{}  # hashtable to store: key=category, value=@{type=..., count=...}

foreach ($match in $regexMatches) {
    # Skip header row
    if ($match.Groups[1].Value -eq "Date") { continue }

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
$expenseCategories = @()
$incomeCategories = @()

foreach ($stat in $categoryStats.Values) {
    $item = @{
        name = $stat.category
        count = $stat.count
    }
    
    switch ($stat.general) {
        "Expenses" { $expenseCategories += $item }
        "Income" { $incomeCategories += $item }
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
