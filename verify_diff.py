import zipfile, os

v33 = r'C:\bamabao\爸妈宝_v3.3.apk'
v34 = r'C:\bamabao\app\build\app\outputs\flutter-apk\app-release.apk'

print('=== APK size ===')
print(f'v3.3: {os.path.getsize(v33)} bytes')
print(f'v3.4: {os.path.getsize(v34)} bytes')

with zipfile.ZipFile(v33, 'r') as z:
    d33 = z.read('lib/arm64-v8a/libapp.so')
with zipfile.ZipFile(v34, 'r') as z:
    d34 = z.read('lib/arm64-v8a/libapp.so')

print(f'v3.3 libapp.so: {len(d33)} bytes')
print(f'v3.4 libapp.so: {len(d34)} bytes')

# Chinese string patterns (encoded as bytes)
chinese_checks = [
    (b'\xe5\x89\xa9\xe4\xbd\x99', '剩余'),
    (b'\xe6\xac\xa1\xe5\xbe\x85\xe6\x9c\x8d\xe7\x94\xa8', '次待服用'),
    (b'\xe4\xbb\x8a\xe6\x97\xa5\xe5\x85\xb1', '今日共'),
    (b'\xe6\x9c\xaa\xe6\x9c\x8d\xe7\x94\xa8', '未服用'),
]
print()
print('=== Chinese strings ===')
for pat, label in chinese_checks:
    in33 = d33.find(pat) >= 0
    in34 = d34.find(pat) >= 0
    status = 'BOTH' if (in33 and in34) else ('NEW' if in34 else 'REMOVED')
    print(f'  {label:10s}  v3.3={"YES" if in33 else "NO "}  v3.4={"YES" if in34 else "NO "}  [{status}]')

# Code feature patterns
code_checks = [
    (b'disabled', 'disabled'),
    (b'_allChecked', '_allChecked'),
    (b'_headerDose', '_headerDose'),
    (b'_remainingCheckins', '_remainingCheckins'),
    (b'_buildScheduleRow', '_buildScheduleRow'),
    (b'onCheckinTap', 'onCheckinTap'),
    (b'scheduleRow', 'scheduleRow'),
    (b'headerRow', 'headerRow'),
]
print()
print('=== Code features ===')
for pat, label in code_checks:
    in33 = d33.find(pat) >= 0
    in34 = d34.find(pat) >= 0
    if in33 != in34:
        print(f'  {label:25s}  DIFF: v3.3={"YES" if in33 else "NO "}  v3.4={"YES" if in34 else "NO "}')
    # else:
    #     print(f'  {label:25s}  SAME: {"YES" if in33 else "NO "}')
