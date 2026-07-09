$dir = "C:\bamabao\app\lib"
$files = Get-ChildItem -Path $dir -Recurse -Filter "*.dart"

foreach ($file in $files) {
    $text = Get-Content $file.FullName -Encoding UTF8 -Raw
    $lines = $text -split "`r`n|`n"
    $lineNum = 0
    foreach ($line in $lines) {
        $lineNum++
        $t = $line.Trim()
        # Look for string literal with ?? that has Chinese or text chars
        # Pattern: 'TEXT??TEXT' or "TEXT??TEXT" where TEXT is Chinese/alpha
        if ($t -match "'[A-Za-z\u4e00-\u9fff]*\?\?" -or $t -match '\?\?[A-Za-z\u4e00-\u9fff]*'') {
            Write-Host "$($file.FullName.Substring($dir.Length + 1))`:L$lineNum`: $t"
        }
    }
}
