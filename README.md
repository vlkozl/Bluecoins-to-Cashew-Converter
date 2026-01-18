
# Bluecoins-Convert

A PowerShell utility that converts Bluecoins HTML exports into Cashew CSV format.

## Overview

- **Input:** Bluecoins HTML exports (table rows with transaction data)
- **Transform:** Extracts Date, Amount, Category, Account, and Notes
- **Output:** Cashew CSV (comma-delimited, `yyyy-MM-dd HH:mm:ss` format)

## Key Files

| File | Purpose |
|------|---------|
| `src/Convert-BluecoinsToCashew.ps1` | Primary converter |
| `src/Verify-*.ps1` | Validation scripts |
| `template/cashew-template2.csv` | CSV format reference |
| `template/categories.md` | Category mapping reference |

## Important Details

- **Dates:** Parsed as `dd.MM.yy`, output as `yyyy-MM-dd HH:mm:ss`
- **Amounts:** European format (`.` thousands, `,` decimals)
- **CSV:** Comma-delimited with no quotes (`-UseQuotes Never`)
- **Income:** Set to `true` when amount > 0

## Quick Start

Convert a Bluecoins HTML export:

```powershell
pwsh -ExecutionPolicy Bypass -File src/Convert-BluecoinsToCashew.ps1 `
    -inputFile input/transactions_list-20251221.html `
    -outputFile result/bluecoins_to_cashew_v2.csv
```

Validate the output:

```powershell
pwsh src/Verify-V2Output.ps1
pwsh src/Verify-CsvParsing.ps1
pwsh src/Verify-ConversionStats.ps1
```


See `copilot-instructions.md` for detailed development guidelines.
