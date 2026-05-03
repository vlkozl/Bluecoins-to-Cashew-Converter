<#
.SYNOPSIS
    Extracts account names from a Bluecoins HTML export and creates or updates a markdown file.
.DESCRIPTION
    Reads a Bluecoins HTML export file, extracts all unique account names from transaction data,
    and writes them to a markdown file in the categories folder.
    On subsequent runs the existing file is preserved and only new accounts are appended.
    Use -Overwrite to regenerate from scratch.
.PARAMETER bluecoinsFile
    The filename of the Bluecoins HTML export file (will be read from .\bluecoins folder).
.PARAMETER accountsFile
    The filename for the resulting accounts markdown file (will be saved to .\tools folder).
.PARAMETER Overwrite
    If set, ignore any existing accounts file and regenerate entirely from HTML.
.EXAMPLE
    .\Create-Accounts.ps1 -bluecoinsFile "transactions.html" -accountsFile "bluecoins_accounts.md"
.EXAMPLE
    .\Create-Accounts.ps1 -bluecoinsFile "transactions.html" -accountsFile "bluecoins_accounts.md" -Overwrite
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
        Get-ChildItem -Path ".\tools\" -Filter "*.md" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "$word*" } |
            ForEach-Object { $_.Name }
    })]
    [string]$accountsFile,

    [switch]$Overwrite
)

Import-Module (Join-Path $PSScriptRoot "Common.psm1") -Force

$BluecoinsDir = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\bluecoins"))
$ToolsDir     = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\tools"))
Initialize-Directory -Path $ToolsDir

$bluecoinsPath = Join-Path $BluecoinsDir $bluecoinsFile
$accountsPath  = Join-Path $ToolsDir     $accountsFile

Assert-FileExists -Path $bluecoinsPath -Label "Input file"

# Load existing accounts from markdown (unless -Overwrite)
$existingAccounts = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

if (-not $Overwrite -and (Test-Path $accountsPath)) {
    Get-Content $accountsPath -Encoding UTF8 | ForEach-Object {
        if ($_ -match '^- (.+)$') {
            [void]$existingAccounts.Add($Matches[1].Trim())
        }
    }
}

# Parse HTML for account names
$content = Get-Content $bluecoinsPath -Raw -Encoding UTF8
$regexMatches = Get-BluecoinsRows -Content $content

$newAccounts = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

foreach ($match in $regexMatches) {
    $account = $match.Groups[7].Value.Trim()
    if (-not [string]::IsNullOrWhiteSpace($account) -and -not $existingAccounts.Contains($account)) {
        [void]$newAccounts.Add($account)
    }
}

# Merge and sort
$allAccounts = [System.Collections.Generic.List[string]]::new()
foreach ($a in $existingAccounts) { $allAccounts.Add($a) }
foreach ($a in $newAccounts)       { $allAccounts.Add($a) }
$allAccounts = $allAccounts | Sort-Object

# Generate markdown
$markdown = @()
$markdown += "# Bluecoins Accounts"
$markdown += ""
$markdown += "All unique account names extracted from Bluecoins transactions, sorted alphabetically."
$markdown += ""
$markdown += "Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$markdown += ""
$markdown += "## Accounts"
$markdown += ""
foreach ($account in $allAccounts) {
    $markdown += "- $account"
}
$markdown += ""

$markdown | Out-File -FilePath $accountsPath -Encoding UTF8

Write-Host "Accounts extraction complete." -ForegroundColor Green
Write-Host "  Existing accounts preserved: $($existingAccounts.Count)" -ForegroundColor Cyan
Write-Host "  New accounts added: $($newAccounts.Count)" -ForegroundColor Cyan
Write-Host "  Total: $($allAccounts.Count) accounts" -ForegroundColor Cyan
Write-Host "Output saved to $accountsPath" -ForegroundColor Green
