"""
爸妈宝药品说明书爬虫 v2 — 用 Crawl4AI 重爬
Crawl4AI 自动处理反爬、转 Markdown，数据质量远高于纯正则
"""
import asyncio, re, json, os, sys, time, logging
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(message)s')
logger = logging.getLogger(__name__)

DAYI_BASE = 'http://dayi.org.cn'

# ====== 药品列表（208种常用药）====== 
DRUGS = {
    # 降压药
    '硝苯地平':None,'氨氯地平':None,'非洛地平':None,'左旋氨氯地平':None,
    '拉西地平':None,'尼群地平':None,'尼莫地平':None,
    '卡托普利':None,'依那普利':None,'贝那普利':None,'赖诺普利':None,
    '雷米普利':None,'福辛普利':None,'培哚普利':None,
    '氯沙坦':None,'缬沙坦':None,'厄贝沙坦':None,'替米沙坦':None,
    '坎地沙坦':None,'奥美沙坦':None,
    '美托洛尔':None,'比索洛尔':None,'阿替洛尔':None,'普萘洛尔':None,
    '卡维地洛':None,'氢氯噻嗪':None,'呋塞米':None,'螺内酯':None,
    '吲达帕胺':None,'特拉唑嗪':None,'多沙唑嗪':None,
    # 降糖药
    '二甲双胍':'盐酸二甲双胍片','格列本脲':None,'格列美脲':None,
    '格列齐特':None,'格列吡嗪':None,'格列喹酮':None,
    '阿卡波糖':None,'伏格列波糖':None,
    '西格列汀':None,'沙格列汀':None,'维格列汀':None,
    '达格列净':None,'恩格列净':None,'卡格列净':None,
    '罗格列酮':None,'吡格列酮':None,
    '胰岛素':None,'甘精胰岛素':None,'地特胰岛素':None,
    # 降脂药
    '阿托伐他汀':None,'瑞舒伐他汀':None,'辛伐他汀':None,
    '普伐他汀':None,'氟伐他汀':None,'匹伐他汀':None,
    '非诺贝特':None,'苯扎贝特':None,'吉非罗齐':None,'依折麦布':None,
    # 心脑血管
    '阿司匹林':None,'氯吡格雷':None,'替格瑞洛':None,
    '华法林':None,'利伐沙班':None,'达比加群':None,
    '硝酸甘油':None,'单硝酸异山梨酯':None,'硝酸异山梨酯':None,
    '地高辛':None,'胺碘酮':None,'普罗帕酮':None,'美西律':None,
    # 止痛退热
    '布洛芬':None,'对乙酰氨基酚':'对乙酰氨基酚片',
    '双氯芬酸钠':None,'吲哚美辛':None,'塞来昔布':None,'依托考昔':None,
    # 抗生素
    '阿莫西林':None,'头孢克肟':None,'头孢克洛':None,
    '头孢呋辛':None,'头孢拉定':None,'头孢氨苄':None,
    '阿奇霉素':'阿奇霉素片','克拉霉素':None,'罗红霉素':None,
    '左氧氟沙星':'左氧氟沙星片','莫西沙星':None,'环丙沙星':None,
    '甲硝唑':None,'替硝唑':None,'奥硝唑':None,
    '多西环素':None,'米诺环素':None,
    # 肠胃药
    '奥美拉唑':'奥美拉唑肠溶胶囊','兰索拉唑':None,'泮托拉唑':None,
    '雷贝拉唑':None,'埃索美拉唑':None,
    '多潘立酮':None,'莫沙必利':None,'伊托必利':None,
    '蒙脱石散':None,'铝碳酸镁':None,'枸橼酸铋钾':None,
    # 过敏哮喘
    '氯雷他定':None,'西替利嗪':None,'左西替利嗪':None,
    '依巴斯汀':None,'非索非那定':None,
    '孟鲁司特':None,'沙丁胺醇':None,'布地奈德':None,
    '氟替卡松':None,'噻托溴铵':None,'氨茶碱':None,
    # 甲状腺
    '左甲状腺素':None,'甲巯咪唑':None,'丙硫氧嘧啶':None,
    # 补益
    '维生素C':'维生素C片','维生素D':None,
    '钙片':None,'叶酸':None,'硫酸亚铁':None,'碳酸钙':None,
    '阿法骨化醇':None,'骨化三醇':None,
    # 外用药
    '扶他林软膏':None,'红霉素软膏':None,'莫匹罗星软膏':None,
    '酮康唑乳膏':None,'特比萘芬乳膏':None,
    '糠酸莫米松':None,'丁酸氢化可的松':None,'卤米松':None,
    # 中成药
    '连花清瘟':'连花清瘟胶囊','板蓝根':'板蓝根颗粒',
    '感冒灵':'感冒灵颗粒','藿香正气':'藿香正气水',
    '安宫牛黄丸':None,'六味地黄丸':None,
    '速效救心丸':None,'复方丹参滴丸':None,
    '金匮肾气丸':None,'补中益气丸':None,'逍遥丸':None,
}


def extract_fields_from_md(drug_name, md):
    """从Crawl4AI的Markdown输出中提取结构化字段"""
    # 提取药品名（从标题）
    name = drug_name
    
    # 去掉页脚导航
    lines = md.split('\n')
    clean_lines = []
    for l in lines:
        if any(kw in l for kw in ['Copyright', '京ICP备', '互联网药品信息服务', '联系电话', '关于我们']):
            break
        clean_lines.append(l)
    md_clean = '\n'.join(clean_lines)
    
    # 按标题分段
    sections = re.split(r'\n(?=#{1,3}\s)', md_clean)
    
    def find_section(kw_list):
        """在Markdown中找章节"""
        for sec in sections:
            first_line = sec.split('\n')[0]
            for kw in kw_list:
                if kw in first_line:
                    # 去掉标题行和空行
                    body = '\n'.join(sec.split('\n')[1:]).strip()
                    # 取前300字
                    return body[:300]
        return ''
    
    # 通用匹配（从全文找关键词开头的段落）
    def find_paragraph(kw):
        """在全文找关键词段落"""
        for line in clean_lines:
            if line.startswith(kw) or f'**{kw}**' in line:
                # 收集后续内容直到下一个标题
                idx = clean_lines.index(line)
                parts = []
                for l in clean_lines[idx:idx+10]:
                    if l.startswith('#') and l != line:
                        break
                    parts.append(l)
                return ' '.join(parts).replace(kw, '').strip()[:200]
        return ''
    
    data = {
        'medicine_name': name,
        'adult_dosage': find_section(['用法用量', '成人剂量']) or find_paragraph('用法用量'),
        'child_dosage': find_section(['儿童剂量']) or find_paragraph('儿童'),
        'elderly_dosage': find_section(['老年']) or find_paragraph('老年'),
        'contraindications': find_section(['禁忌']) or find_paragraph('禁忌'),
        'side_effects': find_section(['不良反应', '副作用']) or find_paragraph('不良反应'),
        'precautions': find_section(['注意事项']) or '',
        'indications': find_section(['适应症']) or find_paragraph('适应症'),
        'full_instruction': md_clean[:8000],
        'source': 'crawl4ai',
    }
    
    return data


async def crawl_drug(name, alt_name=None):
    """用Crawl4AI爬单个药品"""
    from crawl4ai import AsyncWebCrawler
    
    urllib = __import__('urllib.parse')
    from urllib.parse import quote
    
    search_kws = [name] if not alt_name else [name, alt_name]
    found_url = None
    
    async with AsyncWebCrawler() as crawler:
        for kw in search_kws:
            search_url = f'{DAYI_BASE}/search?keyword={quote(kw)}'
            try:
                result = await crawler.arun(search_url)
                md = result.markdown
                links = re.findall(r'http://dayi\.org\.cn/drug/\d+\.html', md)
                if links:
                    found_url = links[0]
                    break
                # 也找相对链接
                rel = re.findall(r'/drug/\d+\.html', md)
                if rel:
                    found_url = DAYI_BASE + rel[0]
                    break
            except Exception as e:
                logger.warning(f'  ⚠️ 搜索失败 {kw}: {str(e)[:40]}')
        
        if not found_url:
            return None
        
        # 爬详情页
        try:
            detail = await crawler.arun(found_url)
            detail_md = detail.markdown
            if not detail_md or len(detail_md) < 100:
                return None
            return extract_fields_from_md(name, detail_md)
        except Exception as e:
            logger.warning(f'  ⚠️ 详情页失败: {str(e)[:40]}')
            return None


async def main():
    results = []
    failed = []
    names = list(DRUGS.keys())
    total = len(names)
    
    for i, name in enumerate(names):
        alt = DRUGS[name]
        logger.info(f'[{i+1}/{total}] {name}...')
        
        data = await crawl_drug(name, alt)
        if data and (data['full_instruction'] or data['adult_dosage']):
            results.append(data)
            logger.info(f'  ✅ {name}')
        else:
            failed.append(name)
            logger.warning(f'  ❌ {name}')
        
        await asyncio.sleep(0.5)
    
    # 输出
    out = {'success': results, 'failed': failed, 'total': total, 'ok': len(results)}
    path = r'C:\bamabao\backend\scripts\drug_data_crawl4ai.json'
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    
    logger.info(f'=== 完成! 成功: {len(results)}/{total}, 失败: {len(failed)} ===')
    logger.info(f'输出: {path}')
    
    # 导入数据库
    _import_to_db(results)


def _import_to_db(results):
    """导入数据库"""
    sys.path.insert(0, r'C:\bamabao\backend')
    from app.models.base import SessionLocal
    from app.models.drug_instruction import DrugInstruction
    
    db = SessionLocal()
    existing = set(n for (n,) in db.query(DrugInstruction.medicine_name).all())
    added = 0
    updated = 0
    
    for r in results:
        name = r.get('medicine_name', '').strip()
        if not name:
            continue
        
        exists = db.query(DrugInstruction).filter(DrugInstruction.medicine_name == name).first()
        if exists:
            # 更新 - Crawl4AI数据质量更好
            exists.adult_dosage = (r.get('adult_dosage') or '')[:200]
            exists.child_dosage = (r.get('child_dosage') or '')[:200]
            exists.elderly_dosage = (r.get('elderly_dosage') or '')[:200]
            exists.contraindications = (r.get('contraindications') or '')[:500]
            exists.side_effects = (r.get('side_effects') or '')[:500]
            exists.precautions = (r.get('precautions') or '')[:500]
            exists.indications = (r.get('indications') or '')[:500]
            exists.full_instruction = (r.get('full_instruction') or '')[:8000]
            exists.source = 'crawl4ai'
            updated += 1
        else:
            drug = DrugInstruction(
                medicine_name=name,
                adult_dosage=(r.get('adult_dosage') or '')[:200],
                child_dosage=(r.get('child_dosage') or '')[:200],
                elderly_dosage=(r.get('elderly_dosage') or '')[:200],
                contraindications=(r.get('contraindications') or '')[:500],
                side_effects=(r.get('side_effects') or '')[:500],
                precautions=(r.get('precautions') or '')[:500],
                indications=(r.get('indications') or '')[:500],
                full_instruction=(r.get('full_instruction') or '')[:8000],
                source='crawl4ai',
            )
            db.add(drug)
            added += 1
    
    db.commit()
    total = db.query(DrugInstruction).count()
    db.close()
    logger.info(f'数据库: 新增 {added}, 更新 {updated}, 总计 {total}')


if __name__ == '__main__':
    asyncio.run(main())
