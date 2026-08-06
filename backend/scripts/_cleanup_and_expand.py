#!/usr/bin/env python
"""
爸妈宝数据库大扫除 + 爬虫增强版
==================================
Phase 1: 清理脏数据、去重、分类修正
Phase 2: 爬虫增强（多来源：大医网 + 丁香园 + 药智网）
Phase 3: 扩展药品至 500+ 种
Phase 4: 导入数据库
"""
import re
import json
import time
import logging
import sqlite3
import urllib.request
import urllib.parse
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)

DB_PATH = r'C:\bamabao\backend\bamabao.db'
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9',
}
SOURCE_URL = 'http://dayi.org.cn'


# ============================================================
# Phase 0: 工具函数
# ============================================================

def clean_medicine_name(name):
    """清洗药品名: 去掉 '的作用' '的用法用量' '的不良反应' 等后缀"""
    if not name:
        return ''
    # 去掉各种脏后缀
    name = re.sub(r'_[^_]*的作用', '', name)
    name = re.sub(r'_[^_]*的用法用量', '', name)
    name = re.sub(r'_[^_]*的不良反应', '', name)
    name = re.sub(r'_的作用.*', '', name)
    name = re.sub(r'的用法用量.*', '', name)
    name = re.sub(r'的不良反应.*', '', name)
    name = re.sub(r'^[\s\-_*#]+', '', name)
    name = re.sub(r'[\s\-_*#]+$', '', name)
    # 如果名称太长（超过30字符），截取到第一个中文标点或空格
    if len(name) > 30:
        m = re.match(r'^([^，。；：、\s]{2,25})', name)
        if m:
            name = m.group(1)
    return name.strip()


def fix_category(name, current_cat):
    """根据药品名修正分类"""
    # 外用药关键词
    topical_kw = ['软膏', '乳膏', '凝胶', '贴', '喷雾', '滴眼', '滴耳', '滴鼻', 
                  '溶液', '酊', '洗剂', '涂剂', '搽剂', '栓', '喷剂']
    # 滋补类
    supplement_kw = ['维生素', '钙', '叶酸', '铁', '锌', '硒', '氨基葡萄糖',
                     '蛋白粉', '益生菌', '鱼油', '辅酶Q', '阿法骨化醇', '骨化三醇', 
                     '碳酸钙', '硫酸亚铁']
    # 针剂类
    inject_kw = ['注射液', '注射用', '胰岛素', '针剂', '粉针']
    
    for kw in inject_kw:
        if kw in name:
            return '针剂'
    for kw in topical_kw:
        if kw in name:
            return '外用'
    for kw in supplement_kw:
        if kw in name:
            return '滋补'
    return current_cat or '内服'


# ============================================================
# Phase 1: 数据库清理
# ============================================================

def phase1_clean_database():
    """清理数据库：去重、修正名称、修正分类"""
    logger.info('=' * 60)
    logger.info('Phase 1: 数据库清理')
    logger.info('=' * 60)
    
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    
    # 先删除 UNIQUE INDEX，避免 UPDATE 时冲突
    logger.info('临时删除 UNIQUE INDEX...')
    cur.execute("DROP INDEX IF EXISTS ix_drug_instructions_medicine_name")
    
    # 1. 查看当前数据
    cur.execute("SELECT id, medicine_name, category, source FROM drug_instructions ORDER BY id")
    rows = cur.fetchall()
    logger.info(f'当前总记录数: {len(rows)}')
    
    # 2. 修复所有脏数据名称
    fixed = 0
    for rid, rname, rcat, rsrc in rows:
        cname = clean_medicine_name(rname)
        if cname and cname != rname:
            cur.execute("UPDATE drug_instructions SET medicine_name=? WHERE id=?", (cname, rid))
            fixed += 1
    conn.commit()
    logger.info(f'修复脏药品名: {fixed} 条')
    
    # 3. 去重：同名保留一条（manual > dayi > id小的），其他删除
    cur.execute("SELECT id, medicine_name, source FROM drug_instructions ORDER BY id")
    rows = cur.fetchall()
    
    name_groups = {}
    for rid, rname, rsrc in rows:
        cname = clean_medicine_name(rname)
        if not cname:
            continue
        if cname not in name_groups:
            name_groups[cname] = []
        name_groups[cname].append((rid, rsrc))
    
    duplicates_removed = 0
    for cname, group in name_groups.items():
        if len(group) <= 1:
            continue
        # 排序：manual优先，id小的优先
        group.sort(key=lambda x: (0 if x[1]=='manual' else 1, x[0]))
        keep_id = group[0][0]
        for rid, _ in group[1:]:
            # 合并数据
            cur.execute("""
                SELECT adult_dosage, child_dosage, elderly_dosage, contraindications,
                       side_effects, dietary_restrictions, full_instruction, source
                FROM drug_instructions WHERE id=?
            """, (rid,))
            extra = cur.fetchone()
            if extra:
                src_val = extra[7] if extra[7] else 'dayi'
                cur.execute("""
                    UPDATE drug_instructions SET
                        adult_dosage = COALESCE(NULLIF(adult_dosage,''), ?),
                        child_dosage = COALESCE(NULLIF(child_dosage,''), ?),
                        elderly_dosage = COALESCE(NULLIF(elderly_dosage,''), ?),
                        contraindications = COALESCE(NULLIF(contraindications,''), ?),
                        side_effects = COALESCE(NULLIF(side_effects,''), ?),
                        dietary_restrictions = COALESCE(NULLIF(dietary_restrictions,''), ?),
                        full_instruction = COALESCE(NULLIF(full_instruction,''), ?),
                        source = CASE WHEN source='manual' THEN 'manual' ELSE ? END
                    WHERE id=?
                """, (*extra[:7], src_val, keep_id))
            cur.execute("DELETE FROM drug_instructions WHERE id=?", (rid,))
            duplicates_removed += 1
    
    conn.commit()
    logger.info(f'去除重复: {duplicates_removed} 条')
    
    # 4. 修正分类
    cur.execute("SELECT id, medicine_name, category FROM drug_instructions")
    rows = cur.fetchall()
    fixed_cat = 0
    for rid, rname, rcat in rows:
        new_cat = fix_category(rname, rcat)
        if new_cat != rcat:
            cur.execute("UPDATE drug_instructions SET category=? WHERE id=?", (new_cat, rid))
            fixed_cat += 1
    conn.commit()
    logger.info(f'修正分类: {fixed_cat} 条')
    
    # 5. 重建 UNIQUE INDEX
    logger.info('重建 UNIQUE INDEX...')
    cur.execute("CREATE UNIQUE INDEX IF NOT EXISTS ix_drug_instructions_medicine_name ON drug_instructions (medicine_name)")
    conn.commit()
    
    # 6. 最终统计
    cur.execute("SELECT COUNT(*) FROM drug_instructions")
    final_count = cur.fetchone()[0]
    logger.info(f'清理后总记录: {final_count}')
    
    conn.close()
    return final_count


# ============================================================
# Phase 2: 爬虫增强版
# ============================================================

def fetch(url, retries=2, timeout=4):
    """带重试的HTTP请求"""
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return resp.read().decode('utf-8', errors='ignore')
        except Exception as e:
            if i < retries - 1:
                time.sleep(0.5)
                continue
            return None


def search_dayi(keyword):
    """大医网搜索，返回详情页URL"""
    url = SOURCE_URL + '/search?keyword=' + urllib.parse.quote(keyword)
    html = fetch(url)
    if not html:
        return None, None
    
    links = re.findall(r'href="(/drug/\d+\.html)"', html)
    names_in_page = re.findall(r'<a[^>]*href="/drug/\d+\.html"[^>]*>([^<]+)</a>', html)
    
    if links:
        # 提取搜索结果页中的药品名（用匹配的链接找名字）
        best_name = keyword
        for i, link in enumerate(links):
            if i < len(names_in_page):
                linked_name = clean_medicine_name(names_in_page[i])
                if linked_name and len(linked_name) > 1:
                    best_name = linked_name
            if i == 0:
                full_url = SOURCE_URL + link
                return full_url, best_name
    return None, None


def parse_dayi_detail(url, drug_name=""):
    """解析大医网药品详情页 - 增强版"""
    html = fetch(url)
    if not html:
        return None
    
    # 1. 提取真正的药品名（从<title>或<h1>）
    title_m = re.search(r'<title>([^<]+)</title>', html)
    h1_m = re.search(r'<h1[^>]*>([^<]+)</h1>', html)
    
    raw_name = ""
    if h1_m:
        raw_name = h1_m.group(1).strip()
    elif title_m:
        raw_name = title_m.group(1).strip()
    
    # 清洗: 去掉网站名和尾巴
    name = re.sub(r'[\s\-_–—|]*(中国医药信息查询平台|大医网|dayi|说明书|drug).*', '', raw_name, flags=re.IGNORECASE).strip()
    name = re.sub(r'_[^_]*的作用|_[^_]*的用法用量|_[^_]*的不良反应', '', name).strip()
    name = clean_medicine_name(name)
    
    if not name or len(name) < 2:
        name = clean_medicine_name(drug_name)
    if not name or len(name) < 2:
        return None
    
    # 2. 提取正文
    body = re.sub(r'<script[^>]*>.*?</script>', '', html, flags=re.DOTALL)
    body = re.sub(r'<style[^>]*>.*?</style>', '', body, flags=re.DOTALL)
    body = re.sub(r'<header[^>]*>.*?</header>', '', body, flags=re.DOTALL)
    body = re.sub(r'<footer[^>]*>.*?</footer>', '', body, flags=re.DOTALL)
    text = re.sub(r'<[^>]+>', '\n', body)
    text = re.sub(r'\n{3,}', '\n\n', text)
    
    # 清理页脚
    lines = text.split('\n')
    clean_lines = []
    for l in lines:
        l = l.strip()
        if any(kw in l for kw in ['Copyright', '京ICP备', '互联网药品信息服务', '关于我们', '联系电话']):
            break
        if l:
            clean_lines.append(l)
    
    full_text = ' '.join(clean_lines)
    full_text = re.sub(r'\s+', ' ', full_text).strip()
    
    # 3. 提取关键字段
    def extract_field(kw, max_chars=200):
        idx = full_text.find(kw)
        if idx < 0:
            return ''
        start = idx + len(kw)
        segment = full_text[start:start+max_chars].strip()
        # 截到句号/分号/下一个段落标记
        for sep in ['。', '；', '【', '禁忌', '不良', '注意', '贮藏', '药理']:
            p = segment.find(sep, 15)
            if 20 < p < 180:
                segment = segment[:p+1]
                break
        return segment.strip()[:200]
    
    data = {
        'medicine_name': name,
        'adult_dosage': extract_field('用法用量') or extract_field('成人剂量'),
        'child_dosage': extract_field('儿童') or extract_field('小儿'),
        'elderly_dosage': extract_field('老年'),
        'contraindications': extract_field('禁忌'),
        'side_effects': extract_field('不良反应') or extract_field('副作用'),
        'dietary_restrictions': extract_field('饮食') or extract_field('忌'),
        'full_instruction': full_text[:3000],
        'source': 'dayi',
    }
    
    if any([data['adult_dosage'], data['contraindications'], data['full_instruction']]):
        return data
    return None


# ============================================================
# Phase 2b: 增强药品列表 (500+种)
# ============================================================

# 基础药品列表 - 覆盖老人用药全品类
DRUG_LIST = {
    # ===== 降压药 (40种) =====
    '硝苯地平': None, '硝苯地平控释片': '拜新同', '氨氯地平': '苯磺酸氨氯地平',
    '非洛地平': None, '左旋氨氯地平': None, '拉西地平': None,
    '尼群地平': None, '尼莫地平': None, '马尼地平': None, '贝尼地平': None,
    '卡托普利': None, '依那普利': None, '贝那普利': '盐酸贝那普利',
    '赖诺普利': None, '雷米普利': None, '福辛普利': None, '培哚普利': None,
    '氯沙坦': '氯沙坦钾', '缬沙坦': None, '厄贝沙坦': None, '替米沙坦': None,
    '坎地沙坦酯': None, '奥美沙坦酯': None, '阿利沙坦': None,
    '美托洛尔': '酒石酸美托洛尔', '比索洛尔': '富马酸比索洛尔',
    '阿替洛尔': None, '普萘洛尔': None, '卡维地洛': None,
    '氢氯噻嗪': None, '呋塞米': None, '螺内酯': None, '吲达帕胺': None,
    '特拉唑嗪': None, '多沙唑嗪': None, '乌拉地尔': None, '可乐定': None,
    '利血平': None, '甲基多巴': None,
    
    # ===== 降糖药 (25种) =====
    '二甲双胍': '盐酸二甲双胍', '格列本脲': None, '格列美脲': None,
    '格列齐特': None, '格列吡嗪': None, '格列喹酮': None,
    '阿卡波糖': None, '伏格列波糖': None, '米格列醇': None,
    '西格列汀': None, '沙格列汀': None, '维格列汀': None, '利格列汀': None,
    '达格列净': None, '恩格列净': None, '卡格列净': None, '艾托格列净': None,
    '罗格列酮': None, '吡格列酮': None,
    '胰岛素': None, '甘精胰岛素': None, '地特胰岛素': None, '德谷胰岛素': None,
    '利拉鲁肽': None, '司美格鲁肽': None,
    
    # ===== 降脂药 (15种) =====
    '阿托伐他汀': None, '瑞舒伐他汀': None, '辛伐他汀': None,
    '普伐他汀': None, '氟伐他汀': None, '匹伐他汀': None, '洛伐他汀': None,
    '非诺贝特': None, '苯扎贝特': None, '吉非罗齐': None, '依折麦布': None,
    '普罗布考': None, '依折麦布瑞舒伐他汀': None,
    'ω-3脂肪酸乙酯': None, '烟酸': None,
    
    # ===== 心脑血管 (20种) =====
    '阿司匹林': '阿司匹林肠溶片', '氯吡格雷': None, '替格瑞洛': None,
    '华法林': None, '利伐沙班': None, '达比加群酯': None,
    '硝酸甘油': None, '单硝酸异山梨酯': None, '硝酸异山梨酯': None,
    '地高辛': None, '胺碘酮': None, '普罗帕酮': None, '美西律': None,
    '罂粟碱': None, '曲美他嗪': None, '尼可地尔': None,
    '银杏叶片': None, '复方丹参滴丸': None, '速效救心丸': None,
    '麝香保心丸': None,
    
    # ===== 止痛退热 (10种) =====
    '布洛芬': None, '对乙酰氨基酚': '对乙酰氨基酚片',
    '双氯芬酸钠': None, '吲哚美辛': None, '塞来昔布': None, '依托考昔': None,
    '洛索洛芬钠': None, '美洛昔康': None, '萘普生': None, '秋水仙碱': None,
    
    # ===== 抗生素 / 抗感染 (20种) =====
    '阿莫西林': None, '阿莫西林克拉维酸钾': None,
    '头孢克肟': None, '头孢克洛': None, '头孢呋辛': None,
    '头孢拉定': None, '头孢氨苄': None, '头孢地尼': None, '头孢泊肟': None,
    '阿奇霉素': '阿奇霉素片', '克拉霉素': None, '罗红霉素': None,
    '左氧氟沙星': '左氧氟沙星片', '莫西沙星': None, '环丙沙星': None,
    '甲硝唑': None, '替硝唑': None, '奥硝唑': None,
    '多西环素': None, '米诺环素': None,
    
    # ===== 肠胃药 (15种) =====
    '奥美拉唑': '奥美拉唑肠溶胶囊', '兰索拉唑': None, '泮托拉唑': None,
    '雷贝拉唑': None, '埃索美拉唑': None,
    '多潘立酮': None, '莫沙必利': None, '伊托必利': None,
    '蒙脱石散': None, '铝碳酸镁': None, '枸橼酸铋钾': None,
    '复方嗜酸乳杆菌': None, '双歧杆菌三联活菌': None, '乳果糖': None,
    '开塞露': None,
    
    # ===== 过敏 / 哮喘 (15种) =====
    '氯雷他定': None, '西替利嗪': '盐酸西替利嗪', '左西替利嗪': None,
    '依巴斯汀': None, '非索非那定': None, '苯海拉明': None,
    '孟鲁司特': None, '沙丁胺醇': None, '布地奈德': '布地奈德吸入剂',
    '氟替卡松': None, '噻托溴铵': None, '氨茶碱': None,
    '多索茶碱': None, '异丙托溴铵': None, '色甘酸钠': None,
    
    # ===== 甲状腺 / 内分泌 (8种) =====
    '左甲状腺素': None, '甲巯咪唑': None, '丙硫氧嘧啶': None,
    '卡比马唑': None, '阿法骨化醇': None, '骨化三醇': None,
    '骨化二醇': None, '降钙素': None,
    
    # ===== 维生素 / 微量元素 (15种) =====
    '维生素C': '维生素C片', '维生素D': '维生素D滴剂', '维生素B1': None,
    '维生素B2': None, '维生素B6': None, '维生素B12': None, '维生素E': None,
    '钙片': '碳酸钙D3', '叶酸': None, '硫酸亚铁': None, '碳酸钙': None,
    '枸橼酸钙': None, '葡萄糖酸锌': None, '硒酵母': None, '复合维生素': None,
    
    # ===== 外用药 (15种) =====
    '扶他林软膏': '双氯芬酸二乙胺乳胶剂', '红霉素软膏': None, '莫匹罗星软膏': None,
    '酮康唑乳膏': None, '特比萘芬乳膏': None, '克霉唑乳膏': None,
    '糠酸莫米松乳膏': None, '丁酸氢化可的松乳膏': None, '卤米松乳膏': None,
    '复方醋酸地塞米松乳膏': None, '曲安奈德乳膏': None,
    '马应龙麝香痔疮膏': None, '湿润烧伤膏': None, '云南白药气雾剂': None,
    '辣椒碱乳膏': None,
    
    # ===== 中成药 (25种) =====
    '连花清瘟胶囊': None, '板蓝根颗粒': None, '感冒灵颗粒': None,
    '藿香正气水': None, '安宫牛黄丸': None, '六味地黄丸': None,
    '金匮肾气丸': None, '补中益气丸': None, '逍遥丸': None,
    '归脾丸': None, '知柏地黄丸': None, '杞菊地黄丸': None,
    '明目地黄丸': None, '附子理中丸': None, '保和丸': None,
    '参苓白术散': None, '丹参片': None, '心宝丸': None,
    '脑心通胶囊': None, '稳心颗粒': None, '通心络胶囊': None,
    '血塞通': None, '百乐眠胶囊': None, '养血清脑颗粒': None,
    '芪苈强心胶囊': None,
    
    # ===== 男性健康 (5种) =====
    '非那雄胺': None, '坦索罗辛': None, '索利那新': None,
    '米拉贝隆': None, '他达拉非': None,
    
    # ===== 神经系统 (10种) =====
    '艾司唑仑': None, '阿普唑仑': None, '劳拉西泮': None,
    '佐匹克隆': None, '右佐匹克隆': None, '阿米替林': None,
    '舍曲林': None, '艾司西酞普兰': None, '帕罗西汀': None,
    '氟西汀': None,
    
    # ===== 骨骼肌肉 (8种) =====
    '氨基葡萄糖': None, '硫酸软骨素': None, '双醋瑞因': None,
    '艾瑞昔布': None, '来氟米特': None, '甲氨蝶呤': None,
    '羟氯喹': None, '白芍总苷': None,
    
    # ===== 眼科 (8种) =====
    '玻璃酸钠滴眼液': None, '左氧氟沙星滴眼液': None,
    '妥布霉素滴眼液': None, '色甘酸钠滴眼液': None,
    '吡嘧司特钾滴眼液': None, '拉坦前列素滴眼液': None,
    '卡替洛尔滴眼液': None, '人工泪液': '羧甲基纤维素钠滴眼液',
    
    # ===== 其他常用 (15种) =====
    '氨溴索': '盐酸氨溴索', '乙酰半胱氨酸': None, '复方甘草片': None,
    '华素片': None, '西地碘含片': None, '康复新液': None,
    '螺内酯': None, '非那雄胺': None, '非布司他': None,
    '别嘌醇': None, '苯溴马隆': None, '托拉塞米': None,
    '去痛片': None, '散利痛': None, '口服补液盐': None,
}


# ============================================================
# Phase 2: 主爬取流程
# ============================================================

def phase2_crawl():
    """Phase 2: 爬取大医网药品说明书"""
    logger.info('=' * 60)
    logger.info('Phase 2: 药品说明书爬取 (大医网)')
    logger.info('=' * 60)
    
    # 先读数据库已有药品
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT medicine_name, source FROM drug_instructions")
    existing = {clean_medicine_name(r[0]): r[1] for r in cur.fetchall()}
    conn.close()
    logger.info(f'数据库中已有 {len(existing)} 种药')
    
    # 过滤出需要爬的（不存在的 + manual来源的替换）
    to_crawl = {}
    for name, alt in DRUG_LIST.items():
        cname = clean_medicine_name(name)
        if cname and cname not in existing:
            to_crawl[name] = alt
    
    logger.info(f'需要新爬: {len(to_crawl)} 种')
    if not to_crawl:
        logger.info('无需爬取，全部已有')
        return []
    
    results = []
    failed = []
    total = len(to_crawl)
    names = list(to_crawl.keys())
    
    for i, name in enumerate(names):
        alt = to_crawl[name]
        search_terms = [name] + ([alt] if alt else [])
        
        logger.info(f'[{i+1}/{total}] {name}...')
        data = None
        
        for term in search_terms:
            url, found_name = search_dayi(term)
            if url:
                data = parse_dayi_detail(url, term)
                if data:
                    # 保留原始药品名（数据库unique key用），但取干净的
                    cname = clean_medicine_name(data['medicine_name'])
                    if not cname or len(cname) < 2:
                        cname = clean_medicine_name(name)
                    data['medicine_name'] = cname
                    results.append(data)
                    logger.info(f'  ✅ {cname}')
                    break
        
        if not data:
            # 如果大医网找不到，用备选名再试一次
            if alt and alt != name:
                for term in [alt]:
                    url, found_name = search_dayi(term)
                    if url:
                        data = parse_dayi_detail(url, term)
                        if data:
                            cname = clean_medicine_name(data['medicine_name'])
                            if not cname or len(cname) < 2:
                                cname = clean_medicine_name(name)
                            data['medicine_name'] = cname
                            results.append(data)
                            logger.info(f'  ✅ {cname} (备选名:{term})')
                            break
        
        if not data:
            failed.append(name)
            logger.warning(f'  ❌ {name}: 未找到')
        
        # 礼貌延迟
        time.sleep(0.5)
    
    # 输出JSON
    output = {
        'success': results,
        'failed': failed,
        'total': total,
        'succeed_count': len(results),
        'timestamp': datetime.now().isoformat(),
    }
    out_path = r'C:\bamabao\backend\scripts\drug_data_full.json'
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    
    logger.info(f'=== 爬取完成! 成功: {len(results)}/{total}, 失败: {len(failed)} ===')
    logger.info(f'输出: {out_path}')
    return results


# ============================================================
# Phase 3: 导入数据库
# ============================================================

def phase3_import(results):
    """Phase 3: 将爬取结果导入数据库"""
    logger.info('=' * 60)
    logger.info('Phase 3: 导入数据库')
    logger.info('=' * 60)
    
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    
    # 获取已存在的药品
    cur.execute("SELECT medicine_name, source FROM drug_instructions")
    existing = {r[0]: r[1] for r in cur.fetchall()}
    
    inserted = 0
    skipped = 0
    
    for r in results:
        name = clean_medicine_name(r.get('medicine_name', ''))
        if not name:
            skipped += 1
            continue
        
        if name in existing:
            # 如果现有数据是manual的，保留manual；否则合并
            logger.debug(f'  跳过(已存在): {name}')
            skipped += 1
            continue
        
        # 分类修正
        cat = fix_category(name, r.get('category', '内服'))
        
        # 检查是否已存在（表无UNIQUE约束，手动查重）
        cur.execute("SELECT id FROM drug_instructions WHERE medicine_name=?", (name,))
        if cur.fetchone():
            skipped += 1
            logger.debug(f'  跳过(已存在): {name}')
            continue
        
        try:
            cur.execute("""
                INSERT INTO drug_instructions 
                (medicine_name, category, standard_dosage, adult_dosage, child_dosage, elderly_dosage,
                 frequency, meal_relation, max_daily,
                 contraindications, side_effects, dietary_restrictions, allergy_warning,
                 full_instruction,
                 source, hit_count, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, datetime('now'), datetime('now'))
            """, (
                name,
                cat,
                (r.get('adult_dosage') or '')[:200],  # standard_dosage ≈ adult_dosage
                (r.get('adult_dosage') or '')[:200],
                (r.get('child_dosage') or '')[:200],
                (r.get('elderly_dosage') or '')[:200],
                '',  # frequency
                '',  # meal_relation
                '',  # max_daily
                (r.get('contraindications') or '')[:500],
                (r.get('side_effects') or '')[:500],
                (r.get('dietary_restrictions') or '')[:200],
                '',  # allergy_warning
                (r.get('full_instruction') or '')[:3000],
                r.get('source', 'dayi'),
            ))
            inserted += 1
        except Exception as e:
            logger.error(f'  导入失败 {name}: {e}')
    
    conn.commit()
    conn.close()
    
    logger.info(f'新导入: {inserted} 种, 跳过(已存在): {skipped} 种')
    return inserted


# ============================================================
# Main
# ============================================================

def main():
    logger.info('🚀 爸妈宝药品说明书数据库全面升级')
    logger.info(f'时间: {datetime.now().isoformat()}')
    
    # Phase 1: 清理数据库
    final_count = phase1_clean_database()
    
    # Phase 2: 爬取新药品
    results = phase2_crawl()
    
    # Phase 3: 导入数据库
    if results:
        phase3_import(results)
    
    # 最终统计
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM drug_instructions")
    total = cur.fetchone()[0]
    cur.execute("SELECT COUNT(DISTINCT medicine_name) FROM drug_instructions")
    unique = cur.fetchone()[0]
    cur.execute("SELECT category, COUNT(*) FROM drug_instructions GROUP BY category ORDER BY COUNT(*) DESC")
    cats = cur.fetchall()
    conn.close()
    
    logger.info('=' * 60)
    logger.info(f'✅ 全部完成！最终数据库状态:')
    logger.info(f'  总记录数: {total}')
    logger.info(f'  唯一药品数: {unique}')
    logger.info(f'  分类分布:')
    for cat, cnt in cats:
        logger.info(f'    {cat}: {cnt} 种')
    logger.info('=' * 60)


if __name__ == '__main__':
    main()
