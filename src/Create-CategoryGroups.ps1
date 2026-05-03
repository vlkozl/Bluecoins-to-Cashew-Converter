<#
.SYNOPSIS
    Extracts unique Category Group Names from a Bluecoins CSV export and creates or updates a markdown file.
.DESCRIPTION
    Reads a Bluecoins CSV export file, extracts all unique Category Group Names, and writes them
    to a markdown file in the tools folder grouped by transaction type (Expenses / Income / Other).
    On subsequent runs the existing file is preserved and only new groups are appended.
    Use -Overwrite to regenerate from scratch.
.PARAMETER bluecoinsFile
    The filename of the Bluecoins CSV export file (will be read from .\bluecoins folder).
.PARAMETER groupsFile
    The filename for the resulting category groups markdown file (will be saved to .\tools folder).
.PARAMETER Overwrite
    If set, ignore any existing groups file and regenerate entirely from CSV.
.EXAMPLE
    .\Create-CategoryGroups.ps1 -bluecoinsFile "transactions.csv" -groupsFile "bluecoins_category_groups.md"
.EXAMPLE
    .\Create-CategoryGroups.ps1 -bluecoinsFile "transactions.csv" -groupsFile "bluecoins_category_groups.md" -Overwrite
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ArgumentCompleter({
        param($cmd, $param, $word)
        Get-ChildItem -Path ".\bluecoins\" -Filter "*.csv" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "$word*" } |
            ForEach-Object { $_.Name }
    })]
    [string]$bluecoinsFile,

    [Parameter(Mandatory = $true)]
    [ArgumentCompleter({
        param($cmd, $param, $word)
        Get-ChildItem -Path ".\tools\" -Filter "*.md" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "$word*" } |
            ForEach-Object { $_.Name }
    })]
    [string]$groupsFile,

    [switch]$Overwrite
)

Import-Module (Join-Path $PSScriptRoot "Common.psm1") -Force

$BluecoinsDir = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\bluecoins"))
$ToolsDir     = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\tools"))
Initialize-Directory -Path $ToolsDir

$bluecoinsPath = Join-Path $BluecoinsDir $bluecoinsFile
$groupsPath    = Join-Path $ToolsDir     $groupsFile

Assert-FileExists -Path $bluecoinsPath -Label "Input file"

# Load existing groups from markdown (unless -Overwrite)
# Track per-section so new entries go into the right section
$existingExpense  = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$existingIncome   = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$existingOther    = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

if (-not $Overwrite -and (Test-Path $groupsPath)) {
    $currentSection = $null
    Get-Content $groupsPath -Encoding UTF8 | ForEach-Object {
        if ($_ -match '^## (.+)$') {
            $currentSection = $Matches[1].Trim()
        } elseif ($_ -match '^- (.+)$') {
            $name = $Matches[1].Trim()
            switch ($currentSection) {
                'Expenses'         { [void]$existingExpense.Add($name) }
                'Income'           { [void]$existingIncome.Add($name) }
                'Other / Transfer' { [void]$existingOther.Add($name) }
            }
        }
    }
}

# Parse CSV
$rows = Import-Csv -Path $bluecoinsPath -Encoding UTF8

$newExpense = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$newIncome  = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$newOther   = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

foreach ($row in $rows) {
    $type  = $row.Type.Trim()
    $group = $row.'Category Group Name'.Trim()

    if ([string]::IsNullOrWhiteSpace($group)) { continue }

    switch ($type) {
        'Expense' {
            if (-not $existingExpense.Contains($group)) { [void]$newExpense.Add($group) }
        }
        'Income' {
            if (-not $existingIncome.Contains($group)) { [void]$newIncome.Add($group) }
        }
        default {
            if (-not $existingOther.Contains($group)) { [void]$newOther.Add($group) }
        }
    }
}

# Merge and sort each section
$allExpense = ($existingExpense + $newExpense | Sort-Object)
$allIncome  = ($existingIncome  + $newIncome  | Sort-Object)
$allOther   = ($existingOther   + $newOther   | Sort-Object)

# Generate markdown
$markdown = @()
$markdown += "# Bluecoins Category Groups"
$markdown += ""
$markdown += "All unique Category Group Names extracted from Bluecoins transactions, sorted alphabetically."
$markdown += ""
$markdown += "Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$markdown += ""

$markdown += "## Expenses"
$markdown += ""
foreach ($g in $allExpense) { $markdown += "- $g" }
$markdown += ""

$markdown += "## Income"
$markdown += ""
foreach ($g in $allIncome) { $markdown += "- $g" }
$markdown += ""

if ($allOther.Count -gt 0) {
    $markdown += "## Other / Transfer"
    $markdown += ""
    foreach ($g in $allOther) { $markdown += "- $g" }
    $markdown += ""
}

$markdown | Out-File -FilePath $groupsPath -Encoding UTF8

$newTotal = $newExpense.Count + $newIncome.Count + $newOther.Count
$allTotal = $allExpense.Count + $allIncome.Count + $allOther.Count
Write-Host "Category groups extraction complete." -ForegroundColor Green
Write-Host "  Expenses: $($allExpense.Count)" -ForegroundColor Cyan
Write-Host "  Income: $($allIncome.Count)" -ForegroundColor Cyan
if ($allOther.Count -gt 0) {
    Write-Host "  Other / Transfer: $($allOther.Count)" -ForegroundColor Yellow
}
Write-Host "  Total: $allTotal groups ($newTotal new)" -ForegroundColor Cyan
Write-Host "Output saved to $groupsPath" -ForegroundColor Green
