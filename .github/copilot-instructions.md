# Copilot / Agent Guidance — Bluecoins-to-Cashew Converter

This repo converts Bluecoins HTML exports into Cashew CSV templates using small PowerShell utilities. The goal of these instructions is to help an AI coding agent be immediately productive and avoid changes that break the fragile CSV parsing conventions.

## Key files

- src/ConvertTo-CashewCsv.ps1 — primary converter (HTML -> Cashew CSV).
- src/Verify.ps1 — unified verification script.
- src/Create-Categories.ps1 — category extraction and mapping utility.
- template/cashew-template2.csv — CSV header and example row (comma-delimited example).
- template/cashew-template.csv — older template.

## Big picture

- Input: exported Bluecoins HTML files in bluecoins/ folder (table rows with <tr>/<td>). The scripts use a regex to extract the columns.
- Transform: src/ConvertTo-CashewCsv.ps1 parses Date, Amount, Category, Account, Notes and maps them to the Cashew schema.
- Output: CSV files in cashew/ folder (comma-delimited, verified for integrity and correctness with Verify.ps1).

## Important implementation details (do not change lightly)

- HTML parsing: a single regex in the converter targets table rows. Keep the same pattern if you modify parsing, and add unit tests or updated verify scripts when changing capture groups.
- Date format: input dates are parsed from dd.MM.yy; outputs must be yyyy-MM-dd HH:mm:ss (see converter's ParseExact). Preserve this format unless you update all downstream checks.
- Amount parsing: amounts use European formatting (thousands . and decimals ,). Converter removes thousands separators and replaces , with . for numeric conversion. Be careful when changing string replacements.
- Income logic: income field is set to true when parsed numeric amount > 0, otherwise false. Type is written as 
ull by default.
- CSV quirks: converters call Export-Csv -UseQuotes Never. That means delimiters inside raw fields will break imports — verification scripts check for this. Prefer to keep quoting or update Verify.ps1 if you change delimiter/quoting.

> Note: There are inconsistencies between templates (semicolon vs comma). The converter currently writes comma-delimited CSV; other scripts/templates expect semicolon. When modifying delimiters, update all Verify.ps1 and template/* accordingly.

## Developer workflows (how to run & validate)

- Convert a file:

```powershell
pwsh -ExecutionPolicy Bypass -File src/ConvertTo-CashewCsv.ps1 -bluecoinsFile transactions.html -cashewFile bluecoins_to_cashew_.csv
```

- Quick validation (runs several checks against the HTML input and CSV output):

```powershell
pwsh src/Verify.ps1 -bluecoinsFile transactions.html -cashewFile bluecoins_to_cashew_.csv
```

## Patterns and conventions to follow in PRs

- Small, focused changes: the parsing and CSV formatting logic is brittle — change only a single concern per PR (parsing, formatting, or verification).
- Keep -UseQuotes Never intent explicit: either preserve it or update all verification scripts and templates to reflect quoting/delimiter changes.
- When adjusting the regex or date parsing, add or update the verify script that reproduces the same checks (count, sum, income logic).
- Prefer PowerShell pwsh cross-platform calls (Windows devs may use powershell, CI should call pwsh).

## Examples to reference when coding

- Date conversion: see src/ConvertTo-CashewCsv.ps1 parse block using [DateTime]::ParseExact(..., "dd.MM.yy", ...).
- Amount cleanup: see replacements .Replace('.', '') then .Replace(',', '.') before casting to [double].
- CSV header expected by verification: account, amount, currency, title, note, date, income, type, category name, subcategory name, color, icon, emoji, budget, objective (see src/Verify.ps1).

## Editing checklist for larger changes

1. Update src/* script(s).
2. Run pwsh local conversion with an example file from Bluecoins.
3. Run src/Verify.ps1 and ensure Count/Sum/Income logic pass.
4. Update template/* if output format (delimiter/headers/quoting) changed.
5. Document the change in this file briefly.

If anything is unclear or you'd like me to include CI steps or automated tests, tell me which area you want expanded and I'll update this file.
