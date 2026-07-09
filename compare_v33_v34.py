import zipfile, hashlib, os

v33 = u'C:\\bamabao\\爸妈宝_v3.3.apk'
v34 = u'C:\\bamabao\\app\\build\\app\\outputs\\flutter-apk\\app-release.apk'

def analyze(path, label):
    size = os.path.getsize(path)
    with zipfile.ZipFile(path, 'r') as z:
        zinfo = z.getinfo('lib/arm64-v8a/libapp.so')
        data = z.read('lib/arm64-v8a/libapp.so')
        h = hashlib.sha256(data).hexdigest()[:16]
        features = [p for p in [b'_allChecked', b'_headerDose', b'_buildScheduleRow', b'disabled'] if data.find(p) >= 0]
    print(f'{label}: size={size} ({size/1024/1024:.1f}MB) libapp={zinfo.file_size} sha256={h} features={features}')

analyze(v33, 'v3.3')
analyze(v34, 'v3.4')

print()
print('v3.3 exists:', os.path.exists(v33))
print('v3.4 exists:', os.path.exists(v34))
print('Same file?', os.path.getsize(v33) == os.path.getsize(v34))
