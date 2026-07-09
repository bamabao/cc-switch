import sys, json
data = json.load(sys.stdin)
print(f"Total: {data.get('total_count',0)}")
for r in data.get('workflow_runs',[]):
    print(f"  #{r['run_number']} {r['display_title'][:40]} status={r['status']} conclusion={r['conclusion']}")
