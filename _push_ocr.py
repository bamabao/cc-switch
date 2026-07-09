#!/usr/bin/env python3
"""Push OCR changes via GitHub API"""
import json, base64, os, sys
import requests

# Read base64-encoded token
with open(os.path.join(os.path.dirname(__file__), '_token_b64.txt'), 'r') as f:
    token = base64.b64decode(f.read().strip()).decode('utf-8')

HEADERS = {
    'User-Agent': 'git-push-ocr',
    'Accept': 'application/vnd.github.v3+json',
    'Authorization': 'Bearer ' + token,
}
BASE = 'https://api.github.com/repos/bamabao/cc-switch'

def gh_api(method, path, data=None):
    url_ = BASE + '/' + path
    resp = requests.request(method, url_, json=data, headers=HEADERS, timeout=30)
    if resp.status_code >= 400:
        print('ERROR %d on %s %s: %s' % (resp.status_code, method, path, resp.text[:200]))
        return None
    return resp.json()

def create_blob(filepath):
    with open(filepath, 'rb') as f:
        content = f.read()
    b64 = base64.b64encode(content).decode()
    return gh_api('POST', 'git/blobs', {'content': b64, 'encoding': 'base64'})

def tree_entry(path, sha):
    return {'path': path.replace('\\', '/'), 'mode': '100644', 'type': 'blob', 'sha': sha}

print("Getting current ref...")
ref = gh_api('GET', 'git/ref/heads/main')
if not ref:
    sys.exit(1)
parent_sha = ref['object']['sha']
print('Parent:', parent_sha[:12])

commit = gh_api('GET', 'git/commits/' + parent_sha)
base_tree_sha = commit['tree']['sha']
print('Base tree:', base_tree_sha[:12])

files = [
    'app/lib/config/api_config.dart',
    'app/lib/screens/medicines/add_medicine_screen.dart',
    'app/lib/services/api_service.dart',
    'backend/app/api/ocr.py',
    'backend/app/main.py',
]

print('\nCreating blobs...')
tree_entries = []
for fp in files:
    full = os.path.join(r'C:\bamabao', fp)
    if not os.path.exists(full):
        print('  SKIP', fp)
        continue
    blob = create_blob(full)
    if blob and 'sha' in blob:
        tree_entries.append(tree_entry(fp, blob['sha']))
        print('  OK', fp)
    else:
        print('  FAIL', fp)

print('\nCreating tree with', len(tree_entries), 'entries...')
tree_result = gh_api('POST', 'git/trees', {
    'base_tree': base_tree_sha, 'tree': tree_entries
})
if not tree_result or 'sha' not in tree_result:
    print('FAILED tree')
    sys.exit(1)
print('New tree:', tree_result['sha'][:12])

print('Creating commit...')
new_commit = gh_api('POST', 'git/commits', {
    'message': '[v2.3-pre] 药盒拍照OCR识别+自动填表 (RapidOCR)',
    'tree': tree_result['sha'],
    'parents': [parent_sha],
})
if not new_commit or 'sha' not in new_commit:
    print('FAILED commit')
    sys.exit(1)
print('New commit:', new_commit['sha'][:12])

print('Updating ref...')
ref_update = gh_api('PATCH', 'git/refs/heads/main', {
    'sha': new_commit['sha'], 'force': False
})
if ref_update:
    print('PUSH SUCCESS!')
else:
    print('FAILED ref update')
