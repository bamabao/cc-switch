import json, os, urllib.request

APP_ID = os.environ.get('FEISHU_APP_ID', 'cli_aae24b7babb8dbda')
APP_SECRET = os.environ.get('FEISHU_APP_SECRET', '')
USER_OPEN_ID = os.environ.get('FEISHU_USER_OPEN_ID', '')

body = json.dumps({'app_id': APP_ID, 'app_secret': APP_SECRET}).encode()
req = urllib.request.Request('https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal',
    data=body, headers={'Content-Type': 'application/json'}, method='POST')
resp = json.loads(urllib.request.urlopen(req, timeout=10).read())
token = resp.get('tenant_access_token', '')

msg_content = json.dumps({
    "text": "【爸妈宝 v3.9 更新完成】\n\n🎉 新增「我的医生」功能！\n首页点「我的医生」卡片即可给医生留言咨询\n\n📱 患者版下载：\nhttp://192.168.10.3:8888\n\n👨‍⚕️ 医生版下载：\nhttp://192.168.10.3:8888/爸妈宝医生版.apk\n\n📊 运营大屏：\nhttp://192.168.10.3:8888/dashboard.html\n\n📱 管理端：\nhttp://192.168.10.3:8888/admin.html\n\n💳 套餐订阅：\nhttp://192.168.10.3:8888/subscribe.html"
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
    print(f'code={resp2.get("code")} msg={resp2.get("msg")}')
    if resp2.get('code') == 0:
        print('✅ 最新下载地址已发送到飞书！')
except urllib.error.HTTPError as e:
    print(f'HTTP错误: {e.code} {e.read().decode()[:300]}')
