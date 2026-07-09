function Inspect-Emoji($path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    
    Write-Host "=== $path ==="
    
    # Find lines with emoji-adjacent patterns (double question marks, etc.)
    $lines = $text -split "`n"
    $lineNum = 0
    foreach ($line in $lines) {
        $lineNum++
        # Check for double question marks which suggest emoji corruption
        if ($line -match "\?\?.+今日") {
            Write-Host "  Line $lineNum: DOUBLE QUESTION MARKS FOUND!"
            Write-Host "    Content: $line"
        }
    }
    
    # Check bytes around any non-ASCII content
    # Specifically look for the byte sequences of emoji (which are 4-byte UTF-8: F0 9F...)
    for ($i = 0; $i -lt $bytes.Length - 3; $i++) {
        if ($bytes[$i] -eq 0xF0 -and $bytes[$i+1] -eq 0x9F) {
            $emoji = $text.Substring($i, 4)
            Write-Host "  Found emoji at byte $i: U+$('{0:X5}' -f [int][char]$emoji) surrounded by: '...$($text.Substring([Math]::Max(0,$i-10), [Math]::Min(20, $text.Length - [Math]::Max(0,$i-10))))...'"
            break
        }
    }
    
    # Check if there are any improper CJK characters (GBK remnants)
    $gbkIssues = $false
    for ($i = 0; $i -lt $text.Length - 1; $i++) {
        $code = [int]$text[$i]
        if ($code -ge 0x4E00 -and $code -le 0x9FFF) {
            # Valid CJK, skip
            continue
        }
        # Check for code points in the CJK extensions or private use areas that could indicate encoding issues
        if ($code -ge 0xE000 -and $code -le 0xF8FF) {
            Write-Host "  WARNING: Private Use Area char U+$('{0:X4}' -f $code) at position $i - possible encoding corruption"
            $gbkIssues = $true
        }
    }
    
    if (-not $gbkIssues) {
        Write-Host "  No GBK remnants found"
    }
    Write-Host ""
}

Inspect-Emoji "C:\bamabao\app\lib\screens\home\home_screen.dart"
Inspect-Emoji "C:\bamabao\app\lib\screens\medicines\medicines_screen.dart"
Inspect-Emoji "C:\bamabao\app\lib\screens\profile\settings_screen.dart"
Inspect-Emoji "C:\bamabao\app\lib\screens\profile\messages_screen.dart"
Inspect-Emoji "C:\bamabao\app\lib\services\voice_service.dart"
