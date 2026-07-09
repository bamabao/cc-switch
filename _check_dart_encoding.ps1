$files = @(
    'C:\bamabao\app\lib\config\theme.dart',
    'C:\bamabao\app\lib\config\api_config.dart',
    'C:\bamabao\app\lib\screens\home\home_screen.dart',
    'C:\bamabao\app\lib\services\api_service.dart',
    'C:\bamabao\app\lib\services\voice_service.dart',
    'C:\bamabao\app\lib\screens\medicines\add_medicine_screen.dart',
    'C:\bamabao\app\lib\screens\medicines\medicines_screen.dart',
    'C:\bamabao\app\lib\screens\profile\messages_screen.dart',
    'C:\bamabao\app\lib\screens\settings\settings_screen.dart',
    'C:\bamabao\app\lib\models\medication.dart',
    'C:\bamabao\app\lib\models\medication_dose.dart',
    'C:\bamabao\app\pubspec.yaml',
    'C:\bamabao\app\lib\services\local_database_service.dart'
)

foreach ($file in $files) {
    if (Test-Path $file) {
        $bytes = [System.IO.File]::ReadAllBytes($file)
        $hasBOM = ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        Write-Host "$file : size=$($bytes.Length) BOM=$hasBOM"
        
        # Check for non-ASCII characters encoding issue
        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
        
        # Check for any replacements/high-ASCII that could indicate encoding issue
        $badCount = 0
        for ($i=0; $i -lt $text.Length; $i++) {
            $c = $text[$i]
            if ($c -eq "�" -or $c -eq "") {
                $badCount++
            }
        }
        if ($badCount -gt 0) {
            Write-Host "  >> WARNING: $badCount replacement characters found in $file"
        }
        
        # Show any Chinese text lines
        Write-Host "  >> First Chinese text:"
        $lines = $text -split "`r`n|`n"
        foreach ($line in $lines) {
            if ($line -match '[\x{4e00}-\x{9fff}]') {
                Write-Host "    $line"
            }
        }
    } else {
        Write-Host "$file : NOT FOUND"
    }
    Write-Host ""
}
