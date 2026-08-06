"""
爬虫：大医网 (dayi.org.cn) 药品说明书
"""
import re
import json
import time
import logging
import urllib.request
import urllib.parse

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(message)s')
logger = logging.getLogger(__name__)

BASE = 'http://dayi.org.cn'
HEADERS = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}


def fetch(url, retries=3):
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=8) as resp:
                return resp.read().decode('utf-8', errors='ignore')
        except Exception as e:
            if i < retries - 1:
                time.sleep(1)
                continue
            return None


def clean(text):
    """去HTML标签，去多余空白"""
    text = re.sub(r'<script[^>]*>.*?</script>', '', text, flags=re.DOTALL)
    text = re.sub(r'<style[^>]*>.*?</style>', '', text, flags=re.DOTALL)
    text = re.sub(r'<[^>]+>', ' ', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def search_drug(keyword, alt_keyword=None):
    """搜索药品，返回药品详情页URL和名称"""
    # 用精确关键词搜索，失败时用备选词
    targets = [keyword] + ([alt_keyword] if alt_keyword else [])
    
    for kw in targets:
        url = BASE + '/search?keyword=' + urllib.parse.quote(kw)
        html = fetch(url)
        if not html:
            continue
        
        # 提取药品链接
        links = re.findall(r'href=\"(/drug/\d+\.html)\"', html)
        # 提取附近的药品名
        names_in_page = re.findall(r'<a[^>]*href=\"/drug/\d+\.html\"[^>]*>([^<]+)</a>', html)
        
        if links:
            # 优先返回完整URL
            full_url = BASE + links[0]
            return full_url, keyword
        
        # 备选：如果没找到药品卡片，可能有其他结构
        # 有些药品在新版页面
        logger.info(f'  → 尝试其他搜索词: {kw}')
    
    return None, None


def _clean_full_text(text):
    """清洗说明书全文：去掉页脚、导航、无关内容"""
    # 去掉版权信息
    text = re.sub(r'Copyright.*?dayi\.org\.cn.*', '', text)
    text = re.sub(r'京ICP备\d+.*', '', text)
    text = re.sub(r'互联网药品信息服务资格证书.*', '', text)
    text = re.sub(r'关于我们.*?常见问题.*', '', text, flags=re.DOTALL)
    # 去掉导航文本
    text = re.sub(r'首页\s*(视频|疾病|症状|资讯|医院|医生|药品|中药材).*', '', text)
    text = re.sub(r'您好，欢迎来到中国医药信息查询平台', '', text)
    text = re.sub(r'本词条由.*?审核认证', '', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text[:2000]


def parse_drug_detail(url, drug_name):
    """解析药品详情页"""
    html = fetch(url)
    if not html:
        return None
    
    # 提取标题
    title_m = re.search(r'<title>([^<]+)</title>', html)
    name = title_m.group(1).strip() if title_m else drug_name
    # 清理标题（去掉网站名等）
    name = re.sub(r'[\s\-_–—|].*', '', name).strip()
    
    text = clean(html)
    
    # 提取各段落
    def extract(kw, fallback_kw=None):
        kw2 = fallback_kw
        for k in [kw, kw2]:
            if not k: continue
            idx = text.find(k)
            if idx >= 0:
                # 从关键词后开始取~200字符
                start = idx + len(k)
                end = start + 300
                content = text[start:end].strip()
                # 截断到句号或换行
                for sep in ['。', '；', '建议', '注意', '如', '【']:
                    pos = content.find(sep)
                    if pos > 30:
                        content = content[:pos+1]
                        break
                return content.strip()
        return ''
    
    data = {
        'medicine_name': name,
        'category': '',
        'standard_dosage': extract('用法用量') or extract('成人剂量'),
        'adult_dosage': extract('成人剂量', '每次'),
        'child_dosage': extract('儿童剂量', '小儿'),
        'elderly_dosage': extract('老年'),
        'frequency': '',
        'meal_relation': extract('餐前', '饭后'),
        'max_daily': extract('最大剂量', '极量'),
        'contraindications': extract('禁忌症', '禁用'),
        'side_effects': extract('不良反应'),
        'dietary_restrictions': extract('饮食', '忌'),
        'allergy_warning': extract('过敏'),
        'full_instruction': _clean_full_text(text[:3000]),  # 说明书摘要，清洗
        'source': 'dayi',
    }
    
    # 过滤无内容
    if not any([data['standard_dosage'], data['adult_dosage'], data['full_instruction']]):
        return None
    
    return data


# 常用药品列表（第一部分：最常用药）
COMMON_DRUGS = [
    ('阿莫西林', '内服'), ('氨氯地平', '内服'), ('阿托伐他汀', '内服'),
    ('二甲双胍', '内服'), ('硝苯地平', '内服'), ('卡托普利', '内服'),
    ('氯沙坦', '内服'), ('美托洛尔', '内服'), ('奥美拉唑', '内服'),
    ('多潘立酮', '内服'), ('蒙脱石散', '内服'), ('布洛芬', '内服'),
    ('对乙酰氨基酚', '内服'), ('阿司匹林', '内服'), ('氯吡格雷', '内服'),
 ('华法林', '内服'), ('左甲状腺素', '内服'),
 ('格列美脲', '内服'), ('胰岛素', '针剂'),
 ('维生素C', '滋补', '维生素C片'), ('钙片', '滋补'),
 ('阿奇霉素', '内服', '阿奇霉素片'), ('头孢克肟', '内服'),
 ('左氧氟沙星', '内服', '左氧氟沙星片'), ('甲硝唑', '内服'),
 ('氯雷他定', '内服'), ('西替利嗪', '内服'),
 ('孟鲁司特', '内服'), ('沙丁胺醇', '内服'),
 ('扶他林软膏', '外用'), ('红霉素软膏', '外用'),
 ('莫匹罗星软膏', '外用'), ('酮康唑乳膏', '外用'),
 ('布地奈德', '内服'), ('氨茶碱', '内服'),
 ('叶酸', '滋补'), ('硫酸亚铁', '内服'),
 ('碳酸钙', '滋补'), ('阿法骨化醇', '滋补'),
 ('非洛地平', '内服'), ('比索洛尔', '内服'),
 ('厄贝沙坦', '内服'), ('缬沙坦', '内服'),
 ('呋塞米', '内服'), ('螺内酯', '内服'),
 ('苯磺酸氨氯地平', '内服'), ('拜新同', '内服', '硝苯地平控释片'),
 ('胰岛素注射液', '针剂'), ('甘精胰岛素', '针剂'),
 ('拜糖平', '内服', '阿卡波糖'), ('捷诺维', '内服', '西格列汀'),
 # 补爬失败7种
 ('二甲双胍', '内服', '盐酸二甲双胍片'),
 ('奥美拉唑', '内服', '奥美拉唑肠溶胶囊'),
 ('对乙酰氨基酚', '内服', '对乙酰氨基酚片'),
 ('阿奇霉素', '内服', '阿奇霉素分散片'),
 ('左氧氟沙星', '内服', '盐酸左氧氟沙星'),
 ('拜新同', '内服', '硝苯地平控释片'),  # 重复但保持写法
 ]


def crawl_all():
    """主流程"""
    results = []
    failed = []
    total = len(COMMON_DRUGS)

    for i, drug in enumerate(COMMON_DRUGS):
        if len(drug) == 3:
            name, cat, alt = drug
        else:
            name, cat = drug[0], drug[1]
            alt = None
            
        logger.info(f'[{i+1}/{total}] {name}...')
        
        url, _ = search_drug(name, alt)
        if url:
            data = parse_drug_detail(url, name)
            if data:
                data['category'] = cat
                results.append(data)
                logger.info(f'  ✅ {data["medicine_name"]}')
            else:
                logger.warning(f'  ⚠️ {name}: 解析失败')
                failed.append(name)
        else:
            logger.warning(f'  ❌ {name}: 未搜索到')
            failed.append(name)
        
        time.sleep(1)  # 礼貌延迟
    
    # 输出JSON
    output = {
        'success': results,
        'failed': failed,
        'total': total,
        'succeed_count': len(results),
    }
    out_path = r'C:\bamabao\backend\scripts\drug_data.json'
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    
    logger.info(f'=== 完成! 成功: {len(results)}/{total}, 失败: {len(failed)} ===')
    logger.info(f'输出: {out_path}')
    return results


if __name__ == '__main__':
    crawl_all()
