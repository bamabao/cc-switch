"""药品说明书爬虫 — 大医网 dayi.org.cn (完整版 170+种)"""
import re, json, time, logging, urllib.request, urllib.parse

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(message)s')
logger = logging.getLogger(__name__)

BASE = 'http://dayi.org.cn'
HEADERS = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

def fetch(url, retries=3):
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=6) as resp:
                return resp.read().decode('utf-8', errors='ignore')
        except Exception as e:
            if i < retries - 1:
                time.sleep(1)
                continue
            return None

def clean_tags(text):
    return re.sub(r'<[^>]+>', ' ', text)

def clean_full(text):
    text = re.sub(r'Copyright.*?dayi\.org\.cn.*', '', text)
    text = re.sub(r'京ICP备\d+.*', '', text)
    text = re.sub(r'互联网药品信息服务资格证书.*', '', text)
    text = re.sub(r'关于我们.*?(?:常见问题|服务协议).*', '', text, flags=re.DOTALL)
    text = re.sub(r'本词条由.*?审核认证', '', text)
    text = re.sub(r'您好，欢迎来到中国医药信息查询平台', '', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text[:2000]

def search_drug(keyword, alt=None):
    targets = [keyword] + ([alt] if alt else [])
    for kw in targets:
        url = BASE + '/search?keyword=' + urllib.parse.quote(kw)
        html = fetch(url)
        if not html: continue
        links = re.findall(r'href="(/drug/\d+\.html)"', html)
        if links:
            return BASE + links[0]
    return None

def parse_drug(url, name):
    html = fetch(url)
    if not html: return None
    
    # 提取标题
    title_m = re.search(r'<title>([^<]+)</title>', html)
    raw_title = title_m.group(1) if title_m else name
    # 清理标题：去掉网站名
    title = re.split(r'[\s\-_–—|]+(?=中国医药信息查询平台)', raw_title)[0].strip()
    title = re.sub(r'[\s\-_–—|]*中国医药信息查询平台.*', '', title).strip()
    title = re.sub(r'_\d+$', '', title).strip()
    
    # 提取纯文本全文
    body = re.sub(r'<script[^>]*>.*?</script>', '', html, flags=re.DOTALL)
    body = re.sub(r'<style[^>]*>.*?</style>', '', body, flags=re.DOTALL)
    body = re.sub(r'<header[^>]*>.*?</header>', '', body, flags=re.DOTALL)
    body = re.sub(r'<footer[^>]*>.*?</footer>', '', body, flags=re.DOTALL)
    text = re.sub(r'<[^>]+>', '\n', body)
    text = re.sub(r'\n{3,}', '\n\n', text)
    
    # 去掉页脚
    lines = text.split('\n')
    clean_lines = []
    for l in lines:
        l = l.strip()
        if any(kw in l for kw in ['Copyright', '京ICP备', '互联网药品信息服务', '关于我们', '联系电话', '联系邮箱']):
            break
        if l and '中国医药信息查询平台' in l and len(l) < 30:
            continue
        if l:
            clean_lines.append(l)
    
    full_text = ' '.join(clean_lines)
    full_text = re.sub(r'\s+', ' ', full_text).strip()
    full_text = re.sub(r'首页\s*(视频|疾病|症状|资讯|医院|医生|药品|中药材)\s*更多', '', full_text)
    full_text = re.sub(r'您好，欢迎来到中国医药信息查询平台', '', full_text)
    full_text = re.sub(r'本词条由.*?审核认证', '', full_text)
    
    # 提取字段（尽力而为）
    def find_after(kw, stop_at=None, max_chars=150):
        idx = full_text.find(kw)
        if idx < 0: return ''
        start = idx + len(kw)
        end = start + max_chars
        if stop_at:
            for s in stop_at:
                p = full_text.find(s, start, end)
                if p > start + 5:
                    end = p
                    break
        segment = full_text[start:end].strip()
        # 截断到标点
        for sep in ['。', '；', '【', '禁忌', '不良']:
            p = segment.find(sep, 10)
            if 20 < p < 140:
                segment = segment[:p+1]
                break
        return segment
    
    data = {
        'medicine_name': title if title else name,
        'adult_dosage': find_after('用法用量', ['禁忌', '不良', '注意']),
        'child_dosage': find_after('儿童', ['禁忌', '不良', '注意', '成人']),
        'elderly_dosage': find_after('老年', ['禁忌', '不良', '注意']),
        'contraindications': find_after('禁忌', ['不良', '注意', '药理', '相互作用']),
        'side_effects': find_after('不良反应', ['注意', '药理', '相互作用', '禁忌', '贮藏']),
        'full_instruction': full_text[:3000],
        'source': 'dayi',
    }
    
    if any([data['full_instruction'], data['adult_dosage']]):
        return data
    return None

# ====== 完整药品列表 208种 ======
DRUGS = {
    # 降压药
    '硝苯地平': None, '氨氯地平': None, '非洛地平': None, '左旋氨氯地平': None,
    '拉西地平': None, '尼群地平': None, '尼莫地平': None,
    '卡托普利': None, '依那普利': None, '贝那普利': None, '赖诺普利': None,
    '雷米普利': None, '福辛普利': None, '培哚普利': None,
    '氯沙坦': None, '缬沙坦': None, '厄贝沙坦': None, '替米沙坦': None,
    '坎地沙坦': None, '奥美沙坦': None,
    '美托洛尔': None, '比索洛尔': None, '阿替洛尔': None, '普萘洛尔': None,
    '卡维地洛': None, '氢氯噻嗪': None, '呋塞米': None, '螺内酯': None,
    '吲达帕胺': None, '特拉唑嗪': None, '多沙唑嗪': None,
    # 降糖药
    '二甲双胍': '盐酸二甲双胍片', '格列本脲': None, '格列美脲': None,
    '格列齐特': None, '格列吡嗪': None, '格列喹酮': None,
    '阿卡波糖': None, '伏格列波糖': None,
    '西格列汀': None, '沙格列汀': None, '维格列汀': None,
    '达格列净': None, '恩格列净': None, '卡格列净': None,
    '罗格列酮': None, '吡格列酮': None,
    '胰岛素': None, '甘精胰岛素': None, '地特胰岛素': None,
    # 降脂
    '阿托伐他汀': None, '瑞舒伐他汀': None, '辛伐他汀': None,
    '普伐他汀': None, '氟伐他汀': None, '匹伐他汀': None,
    '非诺贝特': None, '苯扎贝特': None, '吉非罗齐': None, '依折麦布': None,
    # 心脑血管
    '阿司匹林': None, '氯吡格雷': None, '替格瑞洛': None,
    '华法林': None, '利伐沙班': None, '达比加群': None,
    '硝酸甘油': None, '单硝酸异山梨酯': None, '硝酸异山梨酯': None,
    '地高辛': None, '胺碘酮': None, '普罗帕酮': None, '美西律': None,
    # 止痛退热
    '布洛芬': None, '对乙酰氨基酚': '对乙酰氨基酚片',
    '双氯芬酸钠': None, '吲哚美辛': None, '塞来昔布': None, '依托考昔': None,
    # 抗生素
    '阿莫西林': None, '头孢克肟': None, '头孢克洛': None,
    '头孢呋辛': None, '头孢拉定': None, '头孢氨苄': None,
    '阿奇霉素': '阿奇霉素片', '克拉霉素': None, '罗红霉素': None,
    '左氧氟沙星': '左氧氟沙星片', '莫西沙星': None, '环丙沙星': None,
    '甲硝唑': None, '替硝唑': None, '奥硝唑': None,
    '多西环素': None, '米诺环素': None,
    # 肠胃
    '奥美拉唑': '奥美拉唑肠溶胶囊', '兰索拉唑': None, '泮托拉唑': None,
    '雷贝拉唑': None, '埃索美拉唑': None,
    '多潘立酮': None, '莫沙必利': None, '伊托必利': None,
    '蒙脱石散': None, '铝碳酸镁': None, '枸橼酸铋钾': None,
    # 过敏哮喘
    '氯雷他定': None, '西替利嗪': None, '左西替利嗪': None,
    '依巴斯汀': None, '非索非那定': None,
    '孟鲁司特': None, '沙丁胺醇': None, '布地奈德': None,
    '氟替卡松': None, '噻托溴铵': None, '氨茶碱': None,
    # 甲状腺
    '左甲状腺素': None, '甲巯咪唑': None, '丙硫氧嘧啶': None,
    # 补益
    '维生素C': '维生素C片', '维生素D': None,
    '钙片': None, '叶酸': None, '硫酸亚铁': None, '碳酸钙': None,
    '阿法骨化醇': None, '骨化三醇': None,
    # 外用药
    '扶他林软膏': None, '红霉素软膏': None, '莫匹罗星软膏': None,
    '酮康唑乳膏': None, '特比萘芬乳膏': None,
    '糠酸莫米松': None, '丁酸氢化可的松': None, '卤米松': None,
    # 中成药 (关键词搜索)
    '连花清瘟': '连花清瘟胶囊', '板蓝根': '板蓝根颗粒',
    '感冒灵': '感冒灵颗粒', '藿香正气': '藿香正气水',
    '安宫牛黄丸': None, '六味地黄丸': None,
    '速效救心丸': None, '复方丹参滴丸': None,
    '金匮肾气丸': None, '补中益气丸': None, '逍遥丸': None,
}

def crawl_all():
    results = []
    failed = []
    names = list(DRUGS.keys())
    total = len(names)
    
    for i, name in enumerate(names):
        alt = DRUGS[name]
        logger.info(f'[{i+1}/{total}] {name}...')
        url = search_drug(name, alt)
        if url:
            data = parse_drug(url, name)
            if data:
                results.append(data)
            else:
                failed.append(name)
                logger.warning(f'  ⚠️ {name}: 解析失败')
        else:
            failed.append(name)
            logger.warning(f'  ❌ {name}: 未搜索到')
        time.sleep(0.8)
    
    out = {'success': results, 'failed': failed, 'total': total, 'ok': len(results)}
    path = r'C:\bamabao\backend\scripts\drug_data.json'
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    
    logger.info(f'=== 完成! 成功: {len(results)}/{total}, 失败: {len(failed)} ===')
    return results

if __name__ == '__main__':
    crawl_all()
