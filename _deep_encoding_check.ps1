function Check-FileEncoding($path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    
    # Check each character for common encoding corruption signatures
    $issues = @()
    for ($i = 0; $i -lt $text.Length; $i++) {
        $c = $text[$i]
        $code = [int]$c
        # Check for single-byte replacements that indicate wrong encoding
        # Backwards question mark, control chars in middle of text
        if ($code -eq 0xFFFD -or $code -eq 65533) {
            $issues += "Replacement char at pos $i"
            break
        }
    }
    
    # Look for problematic GBK/ANSI encoding artifacts in Chinese text
    $lines = $text -split "`n"
    $lineNum = 0
    foreach ($line in $lines) {
        $lineNum++
        $trimmed = $line.Trim()
        if ($trimmed -eq "") { continue }
        # Try to detect if line contains any corrupted Chinese characters
        $garbled = $false
        for ($i = 0; $i -lt [Math]::Min($trimmed.Length, 50); $i++) {
            $code = [int]$trimmed[$i]
            # Check for code points in the "garbled" range that indicate encoding issues
            if ($code -ge 0x80 -and $code -le 0xBF -and $i -gt 0) {
                # This could be a multi-byte continuation byte that wasn't decoded correctly
                $garbled = $true
            }
        }
    }
    
    # Simple check: try to find any Chinese text and see if it displays correctly
    Write-Host "FILE: $path"
    Write-Host "  Size: $($bytes.Length) bytes"
    Write-Host "  First bytes hex: $('{0:X2} {1:X2} {2:X2} {3:X2}' -f $bytes[0],$bytes[1],$bytes[2],$bytes[3])"
    
    # Check for BOM
    $hasBOM = $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    Write-Host "  Has UTF-8 BOM: $hasBOM"
    
    # Try to detect if it's actually UTF-8 by checking for common encoding errors
    $isValidUtf8 = $true
    try {
        $null = [System.Text.Encoding]::UTF8.GetString($bytes)
        # Re-encode and compare length to detect substitution
        $roundTrip = [System.Text.Encoding]::UTF8.GetBytes($text)
        if ($roundTrip.Length -ne $bytes.Length) {
            Write-Host "  WARNING: Round-trip encoding changed length ($($bytes.Length) -> $($roundTrip.Length))"
            $isValidUtf8 = $false
        }
    } catch {
        Write-Host "  INVALID UTF-8: $_"
        $isValidUtf8 = $false
    }
    
    if ($isValidUtf8) {
        Write-Host "  Valid UTF-8: Yes"
    }
    Write-Host ""
}

$targets = @(
    'C:\bamabao\app\lib\config\theme.dart',
    'C:\bamabao\app\lib\config\api_config.dart',
    'C:\bamabao\app\lib\models\medication.dart',
    'C:\bamabao\app\lib\models\medication_dose.dart',
    'C:\bamabao\app\lib\screens\home\home_screen.dart',
    'C:\bamabao\app\lib\services\api_service.dart',
    'C:\bamabao\app\lib\services\voice_service.dart',
    'C:\bamabao\app\lib\services\local_database_service.dart',
    'C:\bamabao\app\lib\widgets\dosage_input.dart',
    'C:\bamabao\app\lib\widgets\reminder_dialog.dart',
    'C:\bamabao\app\lib\widgets\clay_time_picker.dart',
    'C:\bamabao\app\lib\widgets\time_slot_selector.dart',
    'C:\bamabao\app\lib\screens\medicines\add_medicine_screen.dart'
)

foreach ($t in $targets) {
    if (Test-Path $t) {
        Check-FileEncoding $t
    } else {
        Write-Host "FILE: $t"
        Write-Host "  NOT FOUND"
        Write-Host ""
    }
}
