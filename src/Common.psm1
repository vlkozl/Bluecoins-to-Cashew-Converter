# Shared pattern for parsing Bluecoins HTML export rows.
# Table structure: <tr>...<td>Date</td><td>Type</td><td>Name</td><td>Amount</td><td>Currency</td><td>Category</td><td>Account</td><td class="notes">Notes</td>...</tr>
$BluecoinsPattern = '(?s)<tr>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td.*?>(.*?)</td>\s*</tr>'
function Get-BluecoinsRows {
<#
.SYNOPSIS
    Parses transaction rows from a Bluecoins HTML export.
.DESCRIPTION
    Extracts all 8-column table rows from the Bluecoins HTML export content
    and returns them as regex match objects, skipping the header row.
    Groups: 1=Date, 2=Type, 3=Name, 4=Amount, 5=Currency, 6=Category, 7=Account, 8=Notes.
.PARAMETER Content
    The raw HTML string read from a Bluecoins export file.
.OUTPUTS
    [System.Text.RegularExpressions.Match[]]
.EXAMPLE
    $content = Get-Content ".\bluecoins\transactions.html" -Raw -Encoding UTF8
    $rows = Get-BluecoinsRows -Content $content
#>
    param([string]$Content)
    [regex]::Matches($Content, $BluecoinsPattern) |
        Where-Object { $_.Groups[1].Value -ne "Date" }
}

function ConvertTo-BluecoinsAmount {
<#
.SYNOPSIS
    Parses a Bluecoins European-format amount string into a clean decimal string.
.DESCRIPTION
    Removes whitespace, strips thousands-separator dots, and replaces the decimal
    comma with a dot. Returns a string suitable for direct cast to [decimal] or [double].
    Input example: "-1.000,50" -> Output: "-1000.50"
.PARAMETER AmountStr
    The raw amount string from a Bluecoins HTML export cell.
.OUTPUTS
    [string]
.EXAMPLE
    [decimal](ConvertTo-BluecoinsAmount "-1.000,50")  # returns -1000.50
#>
    param([string]$AmountStr)
    ($AmountStr -replace '\s+', '').Replace('.', '').Replace(',', '.')
}

function Assert-FileExists {
<#
.SYNOPSIS
    Exits the script with an error if the specified file does not exist.
.PARAMETER Path
    The full path to the file to check.
.PARAMETER Label
    A human-readable label for the file used in the error message (e.g. "Input file").
.EXAMPLE
    Assert-FileExists -Path $bluecoinsFile -Label "Input file"
#>
    param([string]$Path, [string]$Label = "File")
    if (-not (Test-Path $Path)) {
        Write-Error "$Label '$Path' not found."
        exit 1
    }
}

Export-ModuleMember -Function Get-BluecoinsRows, ConvertTo-BluecoinsAmount, Assert-FileExists
