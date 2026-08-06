import json, os, urllib.request

APP_ID = os.environ.get('FEISHU_APP_ID', 'cli_aae24b7babb8dbda')
APP_SECRET = os.environ.get('FEISHU_APP_SECRET', '')

body = json.dumps({'app_id': APP_ID, 'app_secret': APP_SECRET}).encode()
req = urllib.request.Request('https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal',
    data=body, headers={'Content-Type': 'application/json'}, method='POST')
resp = json.loads(urllib.request.urlopen(req, timeout=10).read())
token = resp.get('tenant_access_token', '')
headers = {'Authorization': f'Bearer {token}'}

# 方式1：用p2p chat列表
try:
    req2 = urllib.request.Request('https://open.feishu.cn/open-apis/im/v1/chats?chat_type=p2p&page_size=20', headers=headers)
    resp2 = json.loads(urllib.request.urlopen(req2, timeout=10).read())
    chats = resp2.get('data', {}).get('items', [])
    print(f'p2p会话: {len(chats)}')
    for c in chats:
        print(f'  chat_id={c.get(\"chat_id\")} name={c.get(\"name\",\"?\")} type={c.get(\"chat_mode\")}')
except Exception as e:
    print(f'p2p列表失败: {e}')

# 方式2：通过user_id查消息（需要特定权限）
# 方式3：直接遍历所有会话找最近消息
try:
    req3 = urllib.request.Request('https://open.feishu.cn/open-apis/im/v1/chats?page_size=50', headers=headers)
    resp3 = json.loads(urllib.request.urlopen(req3, timeout=10).read())
    chats3 = resp3.get('data', {}).get('items', [])
    print(f'\n全部会话: {len(chats3)}')
    for c in chats3:
        cid = c.get('chat_id')
        # 拉每个会话的消息
        try:
            reqm = urllib.request.Request(f'https://open.feishu.cn/open-apis/im/v1/messages?container_id_type=chat&container_id={cid}&page_size=10', headers=headers)
            respm = json.loads(urllib.request.urlopen(reqm, timeout=10).read())
            if respm.get('code') == 0:
                msgs = respm.get('data', {}).get('items', [])
                print(f'会话{cid}: {len(msgs)}条消息')
                for m in msgs[:3]:
                    print(f'  [{m.get(\"create_time\")}] {m.get(\"msg_type\")}: {m.get(\"body\",{}).get(\"content\",\"\")[:200]}')
            else:
                print(f'会话{cid}消息失败: {respm.get(\"code\")} {respm.get(\"msg\")}')
        except Exception as e:
            print(f'会话{cid}异常: {e}')
except Exception as e:
    print(f'全部会话失败: {e}')
