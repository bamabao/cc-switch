import requests, json

r = requests.get('http://localhost:8000/api/v1/medications?elder_id=1')
data = r.json()
for item in data.get('items', []):
    print(f"ID:{item.get('id')}  {item.get('name')}  状态:{item.get('status')}")
