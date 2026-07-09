$dir = "C:\bamabao\app\lib"
$files = Get-ChildItem -Path $dir -Recurse -Filter "*.dart"

foreach ($file in $files) {
    $text = Get-Content $file.FullName -Encoding UTF8 -Raw
    $lines = $text -split "`r`n|`n"
    $lineNum = 0
    foreach ($line in $lines) {
        $lineNum++
        # Match string literals containing '??' or "??" with surrounding text (these are emoji replacements)
        if ($line -match "'[^']{0,3}\?\?[^']{0,3}'" -or $line -match '"[^"]{0,3}\?\?[^"]{0,3}"') {
            # Check it's not the null-coalescing operator (no variable before ??)
            if ($line -notmatch '\w+\s*\?\?') {
                $relPath = $file.FullName.Substring($dir.Length + 1)
                Write-Host "$relPath`:L$lineNum`: $($line.Trim())"
            }
        }
    }
}
