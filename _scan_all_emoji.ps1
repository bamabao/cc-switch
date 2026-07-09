$dir = "C:\bamabao\app\lib"
$files = Get-ChildItem -Path $dir -Recurse -Filter "*.dart" | Where-Object { $_.Length -lt 200000 }

foreach ($file in $files) {
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    
    $issues = @()
    $lines = $text -split "`r`n|`n"
    $lineNum = 0
    foreach ($line in $lines) {
        $lineNum++
        # Check for ?? patterns in string literals
        if ($line -match "'[^']*\?\?[^']*'" -or $line -match '"[^"]*\?\?[^"]*"') {
            $relPath = $file.FullName.Substring($dir.Length + 1)
            $issues += "L$lineNum`: $($line.Trim())"
        }
    }
    
    if ($issues.Count -gt 0) {
        Write-Host "=== $($file.FullName.Substring($dir.Length + 1)) ==="
        foreach ($issue in $issues) {
            Write-Host "  $issue"
        }
        Write-Host ""
    }
}
