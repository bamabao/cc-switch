$files = @(
    @("home_screen.dart", "C:\bamabao\app\lib\screens\home\home_screen.dart", 202, "今日用药"),
    @("home_screen.dart", "C:\bamabao\app\lib\screens\home\home_screen.dart", 222, "预警信息"),
    @("medicines_screen.dart", "C:\bamabao\app\lib\screens\medicines\medicines_screen.dart", 148, "iconMap")
)

foreach ($f in $files) {
    Write-Host "=== $($f[0]) line $($f[2]) ==="
    $lines = Get-Content $f[1] -Encoding UTF8
    $line = $lines[$f[2] - 1]
    Write-Host "Content: $line"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($line)
    Write-Host "Length: $($line.Length) chars, $($bytes.Length) bytes"
    # Show first few relevant bytes
    $idx = $line.IndexOf($f[3])
    if ($idx -gt 0 -and $idx -gt 5) {
        $chunk = $line.Substring($idx - 5, [Math]::Min(20, $line.Length - $idx + 5))
        Write-Host "Context: '$chunk'"
        $byteChunk = [System.Text.Encoding]::UTF8.GetBytes($chunk)
        Write-Host "Bytes: $($byteChunk | ForEach-Object { '0x{0:X2}' -f $_ }) -join ' ')"
    }
    Write-Host ""
}
