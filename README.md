
# Bluecoins-to-Cashew Converter

A PowerShell utility for converting [Bluecoins](http://bluecoinsapp.com/) HTML export into [Cashew](https://github.com/jameskokoska/Cashew) CSV format with
basic verification.

## 🔍 Overview

- **Input:** Bluecoins transactions export in HTML
- **Transform:** Extracts Date, Amount, Category, Account, Notes
- **Output:** Cashew CSV (comma-delimited, `yyyy-MM-dd HH:mm:ss` format) ready for import into Cashew app

## 🔑 Key Files

| File | Purpose |
| ---- | ------- |
| `src/ConvertTo-CashewCsv.ps1` | Primary converter (HTML → Cashew CSV) |
| `src/Verify.ps1` | Verification script |
| `src/Create-Categories.ps1` | Extracts Bluecoins categories to markdown |
| `src/Create-CategoryMapping.ps1` | Scaffolds category mapping CSV |
| `categories/category-mapping.csv` | Maps Bluecoins categories → Cashew categories |
| `template/cashew-template2.csv` | CSV format reference |

## :memo: Important conventions

Adjust to your needs in `src/ConvertTo-CashewCsv.ps1`

- **Dates:** Parsed as `dd.MM.yy`, output as `yyyy-MM-dd HH:mm:ss`
- **Amounts:** European format (`.` thousands, `,` decimals)
- **CSV:** Comma-delimited with no quotes (`-UseQuotes Never`)
- **Income:** Set to `true` when amount > 0

## :rocket: Quick Start

1. Export Bluecoins transactions in HTML format. Exclude VOID transactions.
2. Use `src/Create-Categories.ps1` to extract a list of categories used in Bluecoins as a markdown file.
3. (Optional) Manually create matching categories and subcategories in the Cashew app using the markdown from the previous step.
4. Use `src/Create-CategoryMapping.ps1` to scaffold `categories/category-mapping.csv` from the HTML export.
5. Fill in the `cashew_category` column in `category-mapping.csv` to map each Bluecoins category to its Cashew equivalent.
6. Use `src/ConvertTo-CashewCsv.ps1` to convert transactions into Cashew CSV format.
7. (Optional) Use `src/Verify.ps1` to confirm the conversion is correct.
8. Import the resulting CSV file into Cashew.

## :gear: Examples

Extract categories from Bluecoins HTML:

```powershell
pwsh src/Create-Categories.ps1 -bluecoinsFile transactions.html -categoriesFile bluecoins_categories.md
```

Scaffold category mapping CSV (re-run without `-Overwrite` to preserve existing mappings):

```powershell
pwsh src/Create-CategoryMapping.ps1 -bluecoinsFile transactions.html
pwsh src/Create-CategoryMapping.ps1 -bluecoinsFile transactions.html -Overwrite
```

Convert Bluecoins HTML export:

```powershell
pwsh src/ConvertTo-CashewCsv.ps1 -bluecoinsFile transactions.html -cashewFile bluecoins_to_cashew.csv
```

Validate the output:

```powershell
pwsh src/Verify.ps1 -bluecoinsFile transactions.html -cashewFile bluecoins_to_cashew.csv
```

## 📢 Feedback & Contributions

Feel free to use, adjust to your needs, or open issues or pull requests for bugs, improvements, or new features.
