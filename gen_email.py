import base64

src = r'C:\Users\74897\.openclaw\media\inbound\077d542c-94dd-4183-926f-986ab52597ef.jpg'
with open(src, 'rb') as f:
    data = f.read()

b64 = base64.b64encode(data).decode()
html = (
    '<html><head><meta charset="utf-8"><title>邮件截图</title></head><body>'
    '<img src="data:image/jpeg;base64,' + b64 + '" style="max-width:100%">'
    '</body></html>'
)
with open(r'C:\bamabao\email_screenshot.html', 'w') as f:
    f.write(html)
print('ok')
