function Check-FileEncodings($dir) {
    $files = Get-ChildItem -Path $dir -Recurse -Filter "*.dart" | Where-Object { $_.Length -lt 500000 }
    
    foreach ($file in $files) {
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        
        # Quick scan for common garbled patterns
        $garbled = $false
        $garbledChars = @()
        
        for ($i = 0; $i -lt [Math]::Min($bytes.Length, 50000); $i++) {
            # Check for high bytes that might be mis-encoded Chinese
            if ($bytes[$i] -ge 0x80) {
                # This byte is a multi-byte UTF-8 char start or continuation
                # Valid UTF-8 ranges:
                # 2-byte: 110xxxxx 10xxxxxx (0xC0-0xDF, 0x80-0xBF)
                # 3-byte: 1110xxxx 10xxxxxx 10xxxxxx (0xE0-0xEF, 0x80-0xBF, 0x80-0xBF)
                # 4-byte: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx (0xF0-0xF7, ...)
                
                if ($bytes[$i] -ge 0xC0 -and $bytes[$i] -le 0xDF) {
                    # 2-byte sequence
                    if ($i + 1 -lt $bytes.Length -and ($bytes[$i+1] -band 0xC0) -eq 0x80) {
                        $i += 1
                        continue
                    }
                    $garbled = $true
                    break
                }
                elseif ($bytes[$i] -ge 0xE0 -and $bytes[$i] -le 0xEF) {
                    # 3-byte sequence
                    if ($i + 2 -lt $bytes.Length -and ($bytes[$i+1] -band 0xC0) -eq 0x80 -and ($bytes[$i+2] -band 0xC0) -eq 0x80) {
                        $i += 2
                        continue
                    }
                    $garbled = $true
                    break
                }
                elseif ($bytes[$i] -ge 0xF0 -and $bytes[$i] -le 0xF7) {
                    # 4-byte sequence
                    if ($i + 3 -lt $bytes.Length) {
                        $ok = ($bytes[$i+1] -band 0xC0) -eq 0x80 -and ($bytes[$i+2] -band 0xC0) -eq 0x80 -and ($bytes[$i+3] -band 0xC0) -eq 0x80
                        if ($ok) { $i += 3; continue }
                    }
                    $garbled = $true
                    break
                }
                else {
                    # Lone continuation byte (0x80-0xBF) or other invalid in this context
                    # But GBK text would have these as valid characters
                    # Check if it's actually common CJK punctuation in GBK
                    $garbled = $true
                    break
                }
            }
        }
        
        if ($garbled) {
            $relPath = $file.FullName.Substring($dir.Length + 1)
            Write-Host "POTENTIAL ISSUE: $relPath"
            Write-Host "  Bytes near position $i: $('{0:X2} {1:X2} {2:X2} {3:X2}' -f $bytes[$i],$bytes[$i+1],$bytes[$i+2],$bytes[$i+3])"
            
            # Try GBK decoding
            try {
                $gbk = [System.Text.Encoding]::GetEncoding("GB2312")
                $gbkText = $gbk.GetString($bytes)
                $utf8Text = [System.Text.Encoding]::UTF8.GetString($bytes)
                if ($gbkText -ne $utf8Text) {
                    Write-Host "  File MAY be GBK-encoded (different from UTF-8 decoding)"
                }
            } catch {
                Write-Host "  GBK check failed: $_"
            }
        }
    }
    
    Write-Host "Scan complete."
}

Check-FileEncodings "C:\bamabao\app\lib"
