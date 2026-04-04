# AGENTS.md

This file provides guidance to AI coding agents working with this repository.

## Project Overview

PowerShell utility that converts [Bluecoins](http://bluecoinsapp.com/) HTML transaction exports into [Cashew](https://github.com/jameskokoska/Cashew) CSV format for import.

## References

- [Cashew FAQ](https://cashewapp.web.app/faq.html) — Official Cashew app help and import/export documentation
- [Cashew GitHub](https://github.com/jameskokoska/Cashew) — Source code for the Cashew app (repo: `jameskokoska/Cashew`)

## Tools

**Code search:** Use Serena MCP tools first (`find_symbol`, `search_for_pattern`, `get_symbols_overview`, etc.) for any navigation or search task. Fall back to Grep only if Serena is unavailable or returns no results.

**Cashew source/references:** Use the GitHub MCP (`get_file_contents`, `search_code`, `list_directory`, etc.) to fetch source code or reference files from `jameskokoska/Cashew` when you need to understand Cashew's expected CSV format, field semantics, or import behavior.

## Commands

All scripts require `pwsh` (cross-platform PowerShell). Use `-ExecutionPolicy Bypass` if needed on Windows.

**Convert transactions:**
```PowerShell
pwsh -ExecutionPolicy Bypass -File src/ConvertTo-CashewCsv.ps1 -bluecoinsFile transactions.html -cashewFile bluecoins_to_cashew.csv
```

**Extract categories:**
```PowerShell
pwsh src/Create-Categories.ps1 -bluecoinsFile transactions.html -categoriesFile bluecoins_categories.md
```

**Generate/update category mapping:**
```PowerShell
pwsh src/Create-CategoryMapping.ps1 -bluecoinsFile transactions.html
# Add -Overwrite to regenerate from scratch
```

**Verify conversion:**
```PowerShell
pwsh src/Verify.ps1 -bluecoinsFile transactions.html -cashewFile bluecoins_to_cashew.csv
```

Recommended workflow order: `Create-Categories.ps1` (explore categories) → `Create-CategoryMapping.ps1` (scaffold mapping CSV) → fill in `cashew_category` column manually → `ConvertTo-CashewCsv.ps1` → `Verify.ps1`.

There is no automated test suite — `Verify.ps1` is the primary validation tool. Run it after every conversion change.

## Architecture

Data flow:
```
bluecoins/*.html → Create-CategoryMapping.ps1 → categories/category-mapping.csv (user edits)
bluecoins/*.html + categories/category-mapping.csv → ConvertTo-CashewCsv.ps1 → cashew/*.csv → Verify.ps1
```

All scripts import `src/Common.psm1` which centralizes: the shared regex pattern, `ConvertTo-BluecoinsAmount`, `Assert-FileExists`, and `Initialize-Directory`. Changes to parsing logic belong there.

**`src/ConvertTo-CashewCsv.ps1`** — Main converter. Parses each transaction row, transforms fields, outputs comma-delimited CSV with no quotes.

**`src/Verify.ps1`** — Validates output by comparing transaction count, amount sum, and income logic consistency between the source HTML and output CSV.

**`src/Create-Categories.ps1`** — Extracts unique categories from HTML, groups by Expense/Income, outputs a markdown file sorted by frequency.

**`src/Create-CategoryMapping.ps1`** — Scaffolds `categories/category-mapping.csv` from the HTML export. New rows get an empty `cashew_category` and `cashew_subcategory` copied from Bluecoins. Existing user-filled values are preserved on re-run (use `-Overwrite` to regenerate from scratch). Run this once before the first conversion, then fill in the `cashew_category` column manually.

**`src/Common.psm1`** — Shared module: `Get-BluecoinsRows` (regex parser), `ConvertTo-BluecoinsAmount` (amount formatter), `Assert-FileExists`, `Initialize-Directory` (creates missing working directories).

**`template/cashew-template2.csv`** — Reference for the expected CSV header and column order.

**`categories/category-mapping.csv`** — Required at runtime. Maps `bluecoins_type|bluecoins_subcategory` → `cashew_category|cashew_subcategory`. Missing rows produce a warning and fall back to empty category.

## Critical Implementation Details

**HTML parsing:** Single regex in `Common.psm1` targets 8-column `<tr>/<td>` rows. All scripts use it via `Get-BluecoinsRows`.

**Date format:** Input `dd.MM.yy` → output `yyyy-MM-dd HH:mm:ss` via `[DateTime]::ParseExact(..., "dd.MM.yy", $null)`.

**Amount parsing (European format):** `-1.000,50` → remove dots (thousands) → replace comma with dot → `-1000.50`. This string replacement chain is fragile; test with edge cases.

**Income logic:** `income = "true"` when parsed amount > 0, `"false"` otherwise. Verify.ps1 checks this consistency.

**CSV quoting:** Scripts use `-UseQuotes Never`. Commas inside field values will break imports. Verify.ps1 checks for this. If you change the delimiter or quoting, update `Verify.ps1` and `template/*` together.

**Category mapping:** Driven entirely by `categories/category-mapping.csv` (columns: `bluecoins_type`, `bluecoins_subcategory`, `cashew_category`, `cashew_subcategory`). The Transfer→"Balance Correction" rule is in the CSV, not hardcoded. Missing mappings fall back to empty `category name` + original subcategory, with a warning.

**Notes comma sanitization:** Commas in the notes field are replaced with `.` during conversion to prevent CSV corruption. This happens silently.

**Directory structure:** Scripts resolve paths relative to CWD. Input HTML must be in `.\bluecoins\`, output CSV goes to `.\cashew\`, category mapping lives in `.\categories\`. All three directories are created automatically on first run via `Initialize-Directory`. Run scripts from the repo root.

**CSV columns (expected by Verify.ps1):**
`account, amount, currency, title, note, date, income, type, category name, subcategory name, color, icon, emoji, budget, objective`

## Editing Checklist

For any non-trivial change:
1. Update the relevant `src/*.ps1` script(s)
2. Run a local conversion with a Bluecoins HTML file
3. Run `Verify.ps1` — Count, Sum, and Income logic must all pass
4. If output format (delimiter, headers, quoting) changed — update `template/*` and `Verify.ps1`

Make small, focused changes: parsing, formatting, and verification are separate concerns — change one per PR.
