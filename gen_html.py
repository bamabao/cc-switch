import base64, os

src = r'C:\Users\74897\.openclaw\media\inbound\7a377222-460f-412d-a7c8-36bb08310e89.jpg'
with open(src, 'rb') as f:
    data = f.read()

b64 = base64.b64encode(data).decode()
html = (
    '<html><head><meta charset="utf-8"><title>截图</title></head><body>'
    '<img src="data:image/jpeg;base64,' + b64 + '" style="max-width:100%">'
    '</body></html>'
)
out = r'C:\bamabao\wang_ss.html'
with open(out, 'w') as f:
    f.write(html)
print('ok ' + out)
