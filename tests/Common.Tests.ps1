$modulePath = Join-Path $PSScriptRoot "..\src\Common.psm1"
Import-Module $modulePath -Force

Describe "ConvertTo-BluecoinsAmount" {
    It "converts European format with thousands separator" {
        ConvertTo-BluecoinsAmount "-1.000,50" | Should Be "-1000.50"
    }
    It "converts integer European amount" {
        ConvertTo-BluecoinsAmount "500,00" | Should Be "500.00"
    }
    It "handles negative small amount" {
        ConvertTo-BluecoinsAmount "-56,80" | Should Be "-56.80"
    }
}

Describe "Protect-CsvField" {
    It "replaces comma with space-dash-space" {
        Protect-CsvField "House, Garden" | Should Be "House - Garden"
    }
    It "leaves clean strings unchanged" {
        Protect-CsvField "Groceries" | Should Be "Groceries"
    }
    It "handles multiple commas" {
        Protect-CsvField "A, B, C" | Should Be "A - B - C"
    }
    It "handles empty string" {
        Protect-CsvField "" | Should Be ""
    }
    It "handles null" {
        Protect-CsvField $null | Should Be ""
    }
}
