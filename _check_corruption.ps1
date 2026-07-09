$bytes = [System.IO.File]::ReadAllBytes('C:\bamabao\app\lib\screens\home\home_screen.dart')
$idx = [System.Text.Encoding]::UTF8.GetString($bytes).IndexOf('?? 今日用药')
if ($idx -ge 0) {
    Write-Host "Found at char offset: $idx"
    $surrounding = [System.Text.Encoding]::UTF8.GetString($bytes).Substring([Math]::Max(0,$idx-5), 30)
    Write-Host "Context: '$surrounding'"
    # Check actual bytes around the ?? 
    Write-Host "Bytes at $($idx * 1) through $($idx*1 + 20) in UTF-16 position..."
    for ($i = $idx; $i -lt $idx + 25; $i++) {
        $b = $bytes[$i]
        Write-Host ("  byte[{0}] = 0x{1:X2} ('{2}')" -f $i, $b, [char]$b)
    }
}
