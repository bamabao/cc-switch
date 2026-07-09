import base64

with open(r'C:\Users\74897\.openclaw\media\inbound\7a377222-460f-412d-a7c8-36bb08310e89.jpg', 'rb') as f:
    data = f.read()

b64 = base64.b64encode(data).decode()
html = '<html><body><img src="data:image/jpeg;base64,' + b64 + '" style="max-width:100%;height:auto"></body></html>'

with open(r'C:\bamabao\wang_screenshot.html', 'w', encoding='utf-8') as f:
    f.write(html)
print('Written ok, size=' + str(len(html)) + ' bytes')
