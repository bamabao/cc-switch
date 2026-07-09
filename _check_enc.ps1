$files = @(
    'C:\bamabao\app\lib\config\theme.dart',
    'C:\bamabao\app\lib\config\api_config.dart',
    'C:\bamabao\app\lib\screens\home\home_screen.dart',
    'C:\bamabao\app\lib\services\api_service.dart',
    'C:\bamabao\app\lib\services\voice_service.dart',
    'C:\bamabao\app\lib\screens\medicines\add_medicine_screen.dart',
    'C:\bamabao\app\lib\screens\medicines\medicines_screen.dart',
    'C:\bamabao\app\lib\screens\profile\messages_screen.dart',
    'C:\bamabao\app\lib\models\medication.dart',
    'C:\bamabao\app\pubspec.yaml'
)

foreach ($file in $files) {
    if (Test-Path $file) {
        $bytes = [System.IO.File]::ReadAllBytes($file)
        $hasBOM = ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        Write-Host "$file : size=$($bytes.Length) BOM=$hasBOM"
        Write-Host "  First 5 hex bytes: $('{0:X2} {1:X2} {2:X2} {3:X2} {4:X2}' -f $bytes[0],$bytes[1],$bytes[2],$bytes[3],$bytes[4])"
        
        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
        $first200 = $text.Substring(0, [Math]::Min(200, $text.Length))
        Write-Host "  First 200 chars:"
        Write-Host "  $first200"
        Write-Host ""
    }
}
