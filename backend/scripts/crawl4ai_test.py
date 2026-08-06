"""用 Crawl4AI 爬取药品说明书（测试版）"""
import asyncio, json, os, sys

sys.path.insert(0, r'C:\bamabao\backend')
from app.models.base import SessionLocal
from app.models.drug_instruction import DrugInstruction

CRAWL_PY = r"C:\Users\74897\AppData\Local\Programs\Python\Python311\python.exe"

async def crawl_drug(name):
    """爬取大医网药品说明书"""
    import urllib.parse
    from crawl4ai import AsyncWebCrawler
    
    search_url = f'http://dayi.org.cn/search?keyword={urllib.parse.quote(name)}'
    
    async with AsyncWebCrawler() as crawler:
        # 先搜索找链接
        result = await crawler.arun(search_url)
        md = result.markdown
        
        # 从Markdown中提取药品链接 http://dayi.org.cn/drug/\d+.html
        import re
        links = re.findall(r'http://dayi\.org\.cn/drug/\d+\.html', md)
        if not links:
            links = re.findall(r'/drug/\d+\.html', md)
            links = ['http://dayi.org.cn' + l if l.startswith('/') else l for l in links]
        
        if not links:
            print(f'  ❌ {name}: 未找到')
            return None
        
        # 爬详情页
        detail_url = links[0]
        detail = await crawler.arun(detail_url)
        detail_md = detail.markdown
        
        if not detail_md or len(detail_md) < 50:
            print(f'  ❌ {name}: 内容为空')
            return None
        
        # 提取字段
        data = {
            'medicine_name': name,
            'full_instruction': detail_md[:3000],
            'source': 'crawl4ai_dayi',
        }
        
        # 从Markdown中提取各段落
        sections = detail_md.split('## ')
        for sec in sections:
            header = sec.split('\n')[0].strip()
            content = '\n'.join(sec.split('\n')[1:]).strip()[:200]
            if '用法用量' in header or '成人' in header:
                data['adult_dosage'] = content
            elif '禁忌' in header and '不良反应' not in header and '注意事项' not in header:
                data['contraindications'] = content
            elif '不良反应' in header:
                data['side_effects'] = content
        
        print(f'  ✅ {name}: {len(detail_md)}b Markdown')
        return data


async def main():
    # 测试几种药
    test_drugs = ['阿莫西林', '硝苯地平', '二甲双胍', '奥美拉唑']
    
    results = []
    for name in test_drugs:
        print(f'爬取: {name}...')
        data = await crawl_drug(name)
        if data:
            results.append(data)
        await asyncio.sleep(1)
    
    print(f'\n=== 完成! 成功: {len(results)}/{len(test_drugs)} ===')
    for r in results:
        print(f'\n📦 {r["medicine_name"]}')
        for k in ['adult_dosage', 'contraindications']:
            val = r.get(k, '')[:100]
            if val:
                print(f'  {k}: {val}...')


if __name__ == '__main__':
    asyncio.run(main())
