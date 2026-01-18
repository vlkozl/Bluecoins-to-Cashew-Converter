
# Bluecoins-to-Cashew Converter

A PowerShell utility for converting [Bluecoins](http://bluecoinsapp.com/) HTML export into [Cashew](https://github.com/jameskokoska/Cashew) CSV format with
basic verification.

## 🔍 Overview

- **Input:** Bluecoins transactions export in HTML
- **Transform:** Extracts Date, Amount, Category, Account, Notes
- **Output:** Cashew CSV (comma-delimited, `yyyy-MM-dd HH:mm` format) ready for import into Cashew app

## 🔑 Key Files

| File | Purpose |
| ---- | ------- |
| `src/Convert.ps1` | Primary converter (HTML → Cashew CSV) |
| `src/Verify.ps1` | Complete verification script |
| `src/Create-Categories.ps1` | Category creation utility |
| `template/cashew-template2.csv` | CSV format reference |
| `template/categories.md` | Category mapping reference |

## :memo: Important conventions

Adjust to your needs in `src/Convert.ps1`

- **Dates:** Parsed as `dd.MM.yy`, output as `yyyy-MM-dd HH:mm:ss`
- **Amounts:** European format (`.` thousands, `,` decimals)
- **CSV:** Comma-delimited with no quotes (`-UseQuotes Never`)
- **Income:** Set to `true` when amount > 0

## :rocket: Quick Start

1. Export Bluecoins transactions in HTML format. Exclude VOID transactions.
2. Use `src/Create-Categories.ps1` to create a list of categories used in Bluecoins. A markdown file with Categories is to be created.
3. Manually add categories and subcategories in Cashew app using markdown file from the previous step. This is optional but helpful step to get proper category structure upon data import to Cashew.
4. Use `src/Convert.ps1` to convert transactions into Cashew CSV format.
5. (optional) Use `Verify.ps1` to make sure conversion is correct.
6. Import resulting CSV file into Cashew
7. Done

## :gear: Examples

Create Categories map from Bluecoins HTML

```powershell
src/Create-Categories.ps1 -bluecoinsFile transactions.html -categoriesFile bluecoins_categories.md
```

Convert Bluecoins HTML export:

```powershell
src/Convert.ps1 -bluecoinsFile transactions.html -cashewFile bluecoins_to_cashew.csv
```

Validate the output:

```powershell
src/Verify.ps1 -bluecoinsFile transactions.html -cashewFile bluecoins_to_cashew.csv
```

## 📢 Feedback & Contributions

Feel free to use, adjust to your needs, or open issues or pull requests for bugs, improvements, or new features.

See `copilot-instructions.md` for detailed development guidelines.
