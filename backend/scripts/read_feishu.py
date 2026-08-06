import json, os, urllib.request

APP_ID = os.environ.get('FEISHU_APP_ID', 'cli_aae24b7babb8dbda')
APP_SECRET = os.environ.get('FEISHU_APP_SECRET', '')

# 1. 获取token
body = json.dumps({'app_id': APP_ID, 'app_secret': APP_SECRET}).encode()
req = urllib.request.Request('https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal',
    data=body, headers={'Content-Type': 'application/json'}, method='POST')
resp = json.loads(urllib.request.urlopen(req, timeout=10).read())
token = resp.get('tenant_access_token', '')

# 2. 获取机器人收到的消息列表
headers = {'Authorization': f'Bearer {token}'}
req2 = urllib.request.Request('https://open.feishu.cn/open-apis/im/v1/messages?sort_type=ByCreateTimeDesc&page_size=10',
    headers=headers)
try:
    resp2 = json.loads(urllib.request.urlopen(req2, timeout=10).read())
    if resp2.get('code') == 0:
        items = resp2.get('data', {}).get('items', [])
        print(f'共{len(items)}条消息:')
        for m in items:
            msg_type = m.get('msg_type', '')
            content = m.get('body', {}).get('content', '')[:500]
            create_time = m.get('create_time', '')
            chat_id = m.get('chat_id', '')
            print(f'\n--- [{create_time}] type={msg_type} chat={chat_id} ---')
            print(content)
    else:
        print(f'错误: {resp2}')
except Exception as e:
    print(f'异常: {e}')
