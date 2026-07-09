import zipfile

apk = r'C:\bamabao\app\build\app\outputs\flutter-apk\app-release.apk'
with zipfile.ZipFile(apk, 'r') as z:
    data = z.read('lib/arm64-v8a/libapp.so')

    # Only use ASCII patterns
    checks = [
        (b'disabled', 'ClayCheckinButton disabled'),
        (b'check_circle', 'Icons.check_circle icon'),
        (b'_remainingCheckins', 'remainingCheckins var'),
        (b'_scheduleRow', 'scheduleRow method'),
        (b'_headerRow', 'headerRow method'),
        (b'_allChecked', 'allChecked getter'),
        (b'_headerDose', 'headerDoseInfo'),
    ]

    found = 0
    for pattern, desc in checks:
        idx = data.find(pattern)
        if idx >= 0:
            found += 1
            print('  OK: ' + desc + ' [' + str(idx) + ']')
        else:
            print('  MISS: ' + desc)

    print()
    print(str(found) + '/' + str(len(checks)) + ' features found')
