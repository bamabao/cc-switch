"""
药品说明书爬虫 — 丁香园 (drugs.dxy.cn) + 大医网 (dayi.org.cn)
"""
import re
import json
import time
import logging
import urllib.request
import urllib.parse
import sqlite3
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(message)s')
logger = logging.getLogger(__name__)

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9',
}


def fetch(url, retries=3):
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=5) as resp:
                return resp.read().decode('utf-8', errors='ignore')
        except Exception as e:
            if i < retries - 1:
                time.sleep(2)
                continue
            short = url[:50]
            logger.warning(f'请求失败: {short}... {e}')
            return None


def search_dxy(keyword):
    """丁香园搜索"""
    url = 'https://drugs.dxy.cn/search?keyword=' + urllib.parse.quote(keyword)
    html = fetch(url)
    if not html:
        return []
    links = re.findall(r'href="(/drug/[^"]+)"', html)
    seen = set()
    results = []
    for link in links:
        if link not in seen and '/drug/' in link:
            seen.add(link)
            if link.startswith('/'):
                results.append('https://drugs.dxy.cn' + link)
            else:
                results.append(link)
    return results[:3]


def parse_dxy_detail(url):
    """解析丁香园详情"""
    html = fetch(url)
    if not html:
        return None
    data = {}
    name_m = re.search(r'<h1[^>]*>([^<]+)</h1>', html)
    if name_m:
        data['medicine_name'] = name_m.group(1).strip()

    usage = re.search(r'用法用量[：:](.*?)(?:<|$)', html)
    if usage:
        data['adult_dosage'] = usage.group(1).strip()
    contra = re.search(r'禁忌[：:](.*?)(?:<|$)', html)
    if contra:
        data['contraindications'] = contra.group(1).strip()
    side = re.search(r'(?:不良反应|副作用)[：:](.*?)(?:<|$)', html)
    if side:
        data['side_effects'] = side.group(1).strip()
    notes = re.search(r'注意事项[：:](.*?)(?:<|$)', html)
    if notes:
        data['dietary_restrictions'] = notes.group(1).strip()
    return data


def search_dayi(keyword):
    """大医网搜索"""
    url = 'https://dayi.org.cn/search?keyword=' + urllib.parse.quote(keyword)
    html = fetch(url)
    if not html:
        return []
    links = re.findall(r'href="(/drug/\d+)"', html)
    results = []
    for link in links:
        if link.startswith('/'):
            results.append('https://dayi.org.cn' + link)
        else:
            results.append(link)
    return results[:3]


def parse_dayi_detail(url):
    """解析大医网详情"""
    html = fetch(url)
    if not html:
        return None
    data = {}
    title_m = re.search(r'<title>([^<]+)</title>', html)
    if title_m:
        name = re.sub(r'[\s\-_].*', '', title_m.group(1)).strip()
        data['medicine_name'] = name

    content = re.search(r'<div class="content">(.*?)</div>', html, re.DOTALL)
    if content:
        text = re.sub(r'<[^>]+>', '', content.group(1))
        text = re.sub(r'\s+', ' ', text).strip()
        data['full_instruction'] = text

    usage = re.search(r'(用法用量|成人剂量)[：:](.*?)(?:<|$)', html)
    if usage:
        data['adult_dosage'] = usage.group(2).strip()
    contra = re.search(r'禁忌[：:](.*?)(?:<|$)', html)
    if contra:
        data['contraindications'] = contra.group(1).strip()
    return data


COMMON_DRUGS = [
    '阿莫西林', '氨氯地平', '阿托伐他汀', '二甲双胍',
    '硝苯地平', '卡托普利', '氯沙坦', '美托洛尔',
    '奥美拉唑', '多潘立酮', '蒙脱石散', '布洛芬',
    '对乙酰氨基酚', '阿司匹林', '氯吡格雷', '华法林',
    '左甲状腺素', '格列美脲', '胰岛素', '维生素C',
    '钙片', '叶酸', '阿奇霉素', '头孢克肟',
    '左氧氟沙星', '甲硝唑', '氟康唑', '氯雷他定',
    '西替利嗪', '孟鲁司特', '沙丁胺醇', '氨茶碱',
]


def crawl_all():
    """主爬取流程 - 输出JSON格式"""
    results = []
    total = len(COMMON_DRUGS)

    for i, drug in enumerate(COMMON_DRUGS):
        logger.info(f'[{i+1}/{total}] 搜索: {drug}')

        # 丁香园
        data = None
        urls = search_dxy(drug)
        for url in urls:
            data = parse_dxy_detail(url)
            if data and data.get('medicine_name'):
                logger.info(f'  ✅ 丁香园: {data["medicine_name"]}')
                results.append(data)
                break
            time.sleep(1)

        # 大医网（丁香园没找到时）
        if not data:
            urls = search_dayi(drug)
            for url in urls:
                data = parse_dayi_detail(url)
                if data and data.get('medicine_name'):
                    logger.info(f'  ✅ 大医网: {data["medicine_name"]}')
                    results.append(data)
                    break
                time.sleep(1)

        if not data:
            logger.warning(f'  ❌ {drug}: 未找到')
        
        time.sleep(0.5)

    # 输出JSON
    output_path = r'C:\bamabao\backend\scripts\drug_data.json'
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    logger.info(f'完成! 成功: {len(results)}/{total}')
    logger.info(f'输出: {output_path}')
    return results


if __name__ == '__main__':
    crawl_all()
