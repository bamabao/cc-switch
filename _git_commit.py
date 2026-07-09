#!/usr/bin/env python
"""Git commit and push via API"""
import subprocess, os, json

env = {k:v for k,v in os.environ.items() if k not in ['HTTP_PROXY','HTTPS_PROXY','http_proxy','https_proxy']}

r = subprocess.run(['git', 'add', '-A'], cwd=r'C:\bamabao', capture_output=True, text=True, timeout=10)
print('add:', r.stdout[:100], r.stderr[:100])

msg = '[v2.3-pre] 药盒拍照OCR识别+自动填表'
r2 = subprocess.run(['git', 'commit', '-m', msg], cwd=r'C:\bamabao', capture_output=True, text=True, timeout=10)
print('commit:', r2.stdout[-300:], r2.stderr[-300:])
print('RC:', r2.returncode)
