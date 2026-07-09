$bytes = [System.IO.File]::ReadAllBytes('C:\bamabao\app\pubspec.yaml')
Write-Host "First 20 bytes (hex):"
for ($i=0; $i -lt 20; $i++) {
    Write-Host ("{0:X2} " -f $bytes[$i]) -NoNewline
}
Write-Host ""
Write-Host "Has UTF8 BOM: " ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
Write-Host "File size: " $bytes.Length

$text = [System.Text.Encoding]::UTF8.GetString($bytes)
Write-Host "--- First 500 chars of UTF8 decode ---"
Write-Host $text.Substring(0, [Math]::Min(500, $text.Length))
