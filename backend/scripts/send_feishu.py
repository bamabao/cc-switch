import json, os, urllib.request

APP_ID = os.environ.get('FEISHU_APP_ID', 'cli_aae24b7babb8dbda')
APP_SECRET = os.environ.get('FEISHU_APP_SECRET', '')
USER_OPEN_ID = os.environ.get('FEISHU_USER_OPEN_ID', '')

# 1. 获取token
body = json.dumps({'app_id': APP_ID, 'app_secret': APP_SECRET}).encode()
req = urllib.request.Request('https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal',
    data=body, headers={'Content-Type': 'application/json'}, method='POST')
resp = json.loads(urllib.request.urlopen(req, timeout=10).read())
token = resp.get('tenant_access_token', '')
print(f'Token获取: {"OK" if token else resp}')

# 2. 发送消息（文本）
msg_content = json.dumps({
    "text": "【爸妈宝下载中心】\n\n📱 患者版App下载：\nhttp://192.168.10.3:8888\n\n👨‍⚕️ 医生版App下载：\nhttp://192.168.10.3:8888/爸妈宝医生版.apk\n\n📊 运营数据大屏：\nhttp://192.168.10.3:8888/dashboard.html\n\n📱 手机管理端：\nhttp://192.168.10.3:8888/admin.html\n\n💳 套餐订阅页：\nhttp://192.168.10.3:8888/subscribe.html\n\n💡 请确保手机和电脑在同一WiFi下访问"
}, ensure_ascii=False)

send_body = json.dumps({
    "receive_id": USER_OPEN_ID,
    "msg_type": "text",
    "content": msg_content,
}).encode()

req2 = urllib.request.Request(
    'https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=open_id',
    data=send_body,
    headers={'Content-Type': 'application/json', 'Authorization': f'Bearer {token}'},
    method='POST',
)
try:
    resp2 = json.loads(urllib.request.urlopen(req2, timeout=10).read())
    print(f'发送结果: code={resp2.get("code")} msg={resp2.get("msg")}')
    if resp2.get('code') == 0:
        print('✅ 消息已发送到您的飞书！')
    else:
        print(f'❌ {resp2}')
except urllib.error.HTTPError as e:
    print(f'HTTP错误: {e.code} {e.read().decode()[:300]}')
