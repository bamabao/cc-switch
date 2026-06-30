import urllib.request, json

# 药品列表
data = json.loads(urllib.request.urlopen('http://localhost:8000/api/v1/medications?elder_id=1').read())
approved = [m for m in data.get('items', []) if m.get('status') == 'approved']
print('已审核药品: %d 种' % len(approved))
for m in approved:
    print('  - %s: %s次/天' % (m['name'], m.get('frequency_per_day', '?')))
# 预警
data2 = json.loads(urllib.request.urlopen('http://localhost:8000/api/v1/medications/alerts?elder_id=1').read())
print('预警: %d 条' % data2.get('total', 0))
for item in data2.get('items', []):
    for a in item.get('alerts', []):
        print('  - %s [%s]' % (a['message'], a['severity']))
