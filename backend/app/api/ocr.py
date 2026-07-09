"""
药品药盒OCR识别 API v3.2 — 三层优化版

优化要点：
  1. 后端：Rapid+Paddle并行推理 → 无结果走EasyOCR兜底
     - 图片长边压缩至1280px
     - 数字/小数点专用形态学增强
     - 扩充药品词库+加权多引擎校验
     - 启动预加载模型常驻内存
     - 图片特征缓存（相同药品直接返回）
  2. 图像预处理：亮度感知智能分流，轻/重两套策略
  3. 全链路耗时记录
"""
import os
import re
import json
import hashlib
import datetime
import tempfile
import logging
import time
import threading
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Optional
from fastapi import APIRouter, File, UploadFile, HTTPException

logger = logging.getLogger("bamabao.ocr")

router = APIRouter(prefix="/api/v1/ocr", tags=["OCR识别"])

# ─── 常量 ───
FAILED_OCR_DIR = Path(__file__).parent.parent / "logs" / "ocr_failed"
ALLOWED_TYPES = {"image/jpeg", "image/png", "image/jpg", "image/webp"}
MAX_IMAGE_BYTES = 10 * 1024 * 1024   # 10MB
MAX_LONG_EDGE = 1280                 # 长边压缩至1280px
CACHE_MAX_SIZE = 200                 # 特征缓存最大条目
CACHE_TTL_SEC = 3600                 # 缓存有效期1小时
TIMING_WARN_MS = 1000                # 超1秒记录WARN日志

# ─── 引擎线程池（并行推理用） ───
_parallel_pool = ThreadPoolExecutor(max_workers=2)

# ─── 特征缓存 ───
_result_cache: dict[str, dict] = {}
_cache_lock = threading.Lock()

# ═══════════════════════════════════════════════════════
#  药品词库（v3.2 大幅扩充）
# ═══════════════════════════════════════════════════════

MEDICINE_VOCABULARY = [
    # === 抗生素/抗感染 ===
    "阿莫西林", "阿莫西林胶囊", "阿莫西林克拉维酸钾", "头孢克肟", "头孢地尼",
    "头孢克洛", "头孢呋辛酯", "头孢丙烯", "头孢拉定", "头孢氨苄",
    "头孢他美酯", "头孢泊肟酯", "阿奇霉素", "克拉霉素", "罗红霉素",
    "左氧氟沙星", "莫西沙星", "环丙沙星", "诺氟沙星", "氧氟沙星",
    "甲硝唑", "替硝唑", "奥硝唑", "氟康唑", "伊曲康唑",
    "阿昔洛韦", "伐昔洛韦", "泛昔洛韦", "利巴韦林", "奥司他韦",
    "盐酸小檗碱", "复方新诺明", "磺胺嘧啶",
    # === 解热镇痛/抗炎 ===
    "布洛芬", "布洛芬缓释胶囊", "对乙酰氨基酚", "阿司匹林", "双氯芬酸钠",
    "吲哚美辛", "洛索洛芬钠", "塞来昔布", "依托考昔", "萘普生",
    "美洛昔康", "吡罗昔康", "秋水仙碱", "别嘌醇", "非布司他",
    # === 心血管 ===
    "硝苯地平", "硝苯地平控释片", "氨氯地平", "左旋氨氯地平", "非洛地平",
    "拉西地平", "贝尼地平", "氯沙坦", "氯沙坦钾", "厄贝沙坦",
    "缬沙坦", "替米沙坦", "坎地沙坦", "奥美沙坦", "阿利沙坦",
    "赖诺普利", "卡托普利", "依那普利", "雷米普利", "培哚普利",
    "比索洛尔", "美托洛尔", "美托洛尔缓释片", "阿替洛尔", "卡维地洛",
    "阿托伐他汀", "瑞舒伐他汀", "辛伐他汀", "普伐他汀", "匹伐他汀",
    "氢氯噻嗪", "螺内酯", "呋塞米", "托拉塞米", "吲达帕胺",
    "华法林", "氯吡格雷", "替格瑞洛", "达比加群", "利伐沙班",
    "硝酸甘油", "速效救心丸", "复方丹参滴丸", "复方丹参片", "麝香保心丸",
    "稳心颗粒", "参松养心胶囊", "通心络胶囊",
    # === 糖尿病 ===
    "二甲双胍", "二甲双胍缓释片", "格列齐特", "格列美脲", "格列吡嗪",
    "格列本脲", "阿卡波糖", "伏格列波糖", "米格列醇", "西格列汀",
    "沙格列汀", "维格列汀", "利格列汀", "达格列净", "恩格列净",
    "卡格列净", "艾塞那肽", "利拉鲁肽", "度拉糖肽", "司美格鲁肽",
    "罗格列酮", "吡格列酮", "瑞格列奈", "那格列奈",
    # === 消化 ===
    "奥美拉唑", "奥美拉唑肠溶胶囊", "泮托拉唑", "雷贝拉唑", "埃索美拉唑",
    "兰索拉唑", "法莫替丁", "西咪替丁", "雷尼替丁",
    "多潘立酮", "莫沙必利", "伊托必利", "曲美布汀",
    "蒙脱石散", "双歧杆菌", "布拉氏酵母菌", "乳果糖", "聚乙二醇",
    "开塞露", "复方消化酶", "复方嗜酸乳杆菌",
    "藿香正气水", "藿香正气软胶囊", "保和丸", "健胃消食片", "大山楂丸",
    "铝碳酸镁", "硫糖铝", "枸橼酸铋钾", "果胶铋",
    # === 呼吸/感冒 ===
    "连花清瘟胶囊", "连花清瘟颗粒", "板蓝根颗粒", "蒲地蓝消炎口服液",
    "肺力咳合剂", "肺力咳胶囊", "川贝枇杷膏", "蜜炼川贝枇杷膏",
    "京都念慈菴蜜炼川贝枇杷膏", "念慈菴", "甘草片", "复方甘草片",
    "氨溴索", "氨溴特罗", "乙酰半胱氨酸", "羧甲司坦",
    "孟鲁司特钠", "布地奈德", "沙丁胺醇", "异丙托溴铵",
    "氯雷他定", "西替利嗪", "地氯雷他定", "左西替利嗪", "依巴斯汀",
    "扑尔敏", "氯苯那敏", "苯海拉明", "赛庚啶",
    # === 神经/精神 ===
    "舍曲林", "氟西汀", "帕罗西汀", "艾司西酞普兰", "西酞普兰",
    "文拉法辛", "度洛西汀", "米氮平", "阿戈美拉汀",
    "阿普唑仑", "艾司唑仑", "劳拉西泮", "地西泮", "氯硝西泮",
    "佐匹克隆", "右佐匹克隆", "唑吡坦",
    "多奈哌齐", "美金刚", "卡巴拉汀",
    "甲钴胺", "维生素B12", "谷维素",
    # === 中药/中成药 ===
    "六味地黄丸", "知柏地黄丸", "杞菊地黄丸", "金匮肾气丸",
    "补中益气丸", "归脾丸", "人参归脾丸", "逍遥丸", "加味逍遥丸",
    "乌鸡白凤丸", "桂枝茯苓丸", "血府逐瘀丸", "牛黄解毒片",
    "牛黄上清丸", "龙胆泻肝丸", "丹参片", "血塞通", "血栓通",
    "安宫牛黄丸", "至宝丹", "苏合香丸",
    "小金丸", "西黄丸", "片仔癀", "云南白药",
    "养血清脑颗粒", "天麻钩藤颗粒", "脑心通胶囊",
    # === 妇儿科 ===
    "黄体酮", "地屈孕酮", "戊酸雌二醇", "炔雌醇",
    "米非司酮", "米索前列醇",
    "小儿氨酚黄那敏颗粒", "小儿化痰止咳颗粒", "小儿肺热咳喘口服液",
    "儿童维D钙咀嚼片", "小儿善存",
    # === 维生素/矿物质/保健品 ===
    "钙尔奇D", "钙尔奇", "碳酸钙D3", "维D钙咀嚼片",
    "维生素D", "维生素D3", "维生素C", "维生素B1", "维生素B2",
    "维生素B6", "维生素B12", "复合维生素B", "复合维生素",
    "叶酸", "铁剂", "硫酸亚铁", "富马酸亚铁", "葡萄糖酸亚铁",
    "葡萄糖酸锌", "甘草锌",
    "鱼油", "深海鱼油", "辅酶Q10", "褪黑素", "褪黑素片",
    "益生菌", "乳双歧杆菌", "鼠李糖乳杆菌",
    "氨糖", "硫酸氨基葡萄糖", "盐酸氨基葡萄糖", "硫酸软骨素",
    "蛋白粉", "乳清蛋白",
]

MEDICINE_SUFFIXES = [
    "片", "胶囊", "口服液", "颗粒", "冲剂", "软膏", "膏",
    "滴眼液", "注射液", "喷剂", "贴", "丸", "散",
    "咀嚼片", "缓释片", "控释片", "肠溶片", "泡腾片",
    "分散片", "含片", "糖浆", "合剂", "乳膏", "凝胶",
    "滴剂", "气雾剂", "吸入剂", "膜剂", "栓剂",
    "滴丸", "缓释胶囊", "肠溶胶囊", "软胶囊", "口服溶液",
    "混悬液", "乳膏剂", "贴膏", "贴剂", "喷雾剂",
]

# ─── 单位归一化映射 ───
UNIT_NORMALIZE = {
    "mg": "mg", "毫克": "mg", "m g": "mg",
    "g": "g", "克": "g",
    "ml": "ml", "mL": "ml", "毫升": "ml", "m l": "ml",
    "粒": "粒", "片": "片", "袋": "袋", "支": "支",
    "μg": "μg", "ug": "μg", "微克": "μg",
    "IU": "IU", "单位": "IU", "iu": "IU",
    "L": "L",
}

# ═══════════════════════════════════════════════════════
#  OCR 引擎：启动时预加载（模块级，同步初始化）
# ═══════════════════════════════════════════════════════

_ocr_engines: dict[str, object] = {}
_engines_ready = threading.Event()


def _preload_engines():
    """服务启动时预加载所有OCR引擎，常驻内存"""
    for name in ("rapid", "paddleocr"):
        try:
            start = time.time()
            if name == "rapid":
                from rapidocr_onnxruntime import RapidOCR
                _ocr_engines["rapid"] = RapidOCR()
            elif name == "paddleocr":
                try:
                    from paddleocr import PaddleOCR
                    _ocr_engines["paddleocr"] = PaddleOCR(use_angle_cls=True, lang="ch")
                except Exception as e:
                    logger.warning(f"paddleocr 预加载失败（不影响流程）: {e}")
            logger.info(f"{name} 引擎预加载完成 ({(time.time()-start)*1000:.0f}ms)")
        except ImportError:
            logger.warning(f"{name} 引擎未安装，跳过预加载")
        except Exception as e:
            logger.warning(f"{name} 引擎预加载失败: {e}")

    # EasyOCR 体积最大，按需而非预加载（首次使用时加载）
    _engines_ready.set()


# 模块导入时即开始预加载
_preload_thread = threading.Thread(target=_preload_engines, daemon=True)
_preload_thread.start()


def _get_engine(engine_name: str):
    """获取OCR引擎（已预加载的返回缓存实例，未预加载的按需加载）"""
    # 等待预加载完成
    _engines_ready.wait(timeout=30)

    if engine_name in _ocr_engines:
        return _ocr_engines[engine_name]

    # 按需加载
    if engine_name == "easyocr":
        try:
            import easyocr
            reader = easyocr.Reader(["ch_sim", "en"], gpu=False)
            _ocr_engines["easyocr"] = reader
            logger.info("EasyOCR 引擎按需加载完成")
            return reader
        except Exception as e:
            logger.error(f"EasyOCR 加载失败: {e}")
            raise

    if engine_name == "paddleocr":
        try:
            from paddleocr import PaddleOCR
            engine = PaddleOCR(use_angle_cls=True, lang="ch")
            _ocr_engines["paddleocr"] = engine
            logger.info("PaddleOCR 引擎按需加载完成")
            return engine
        except Exception as e:
            logger.warning(f"PaddleOCR 按需加载失败（不影响流程）: {e}")
            return None

    raise ValueError(f"未知引擎: {engine_name}")


# ═══════════════════════════════════════════════════════
#  图像特征缓存
# ═══════════════════════════════════════════════════════

def _image_fingerprint(image_data: bytes) -> str:
    """计算图片指纹（SHA256前32字符）"""
    return hashlib.sha256(image_data).hexdigest()[:32]


def _get_cached(fp: str) -> Optional[dict]:
    """获取缓存结果"""
    with _cache_lock:
        entry = _result_cache.get(fp)
        if entry:
            age = time.time() - entry["ts"]
            if age < CACHE_TTL_SEC:
                logger.info(f"特征缓存命中 (age={age:.0f}s)")
                return entry["result"]
            else:
                del _result_cache[fp]
    return None


def _set_cache(fp: str, result: dict):
    """设置缓存（LRU淘汰）"""
    with _cache_lock:
        if len(_result_cache) >= CACHE_MAX_SIZE:
            # 淘汰最老的
            oldest_key = min(_result_cache, key=lambda k: _result_cache[k]["ts"])
            del _result_cache[oldest_key]
        _result_cache[fp] = {"ts": time.time(), "result": result}


# ═══════════════════════════════════════════════════════
#  第1层：智能图像预处理（亮度感知分流）
# ═══════════════════════════════════════════════════════

def _estimate_brightness(img) -> float:
    """估算图像平均亮度 (0~255)"""
    import cv2
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    return float(cv2.mean(gray)[0])


def _resize_long_edge(img, max_edge: int = MAX_LONG_EDGE):
    """等比例缩放，使长边不超过 max_edge"""
    import cv2
    h, w = img.shape[:2]
    if max(h, w) > max_edge:
        scale = max_edge / max(h, w)
        interpolation = cv2.INTER_AREA if scale < 1 else cv2.INTER_LINEAR
        return cv2.resize(img, None, fx=scale, fy=scale, interpolation=interpolation)
    return img


def _resize_long_edge_path(image_path: str, max_edge: int = MAX_LONG_EDGE):
    """读取图片并缩放到长边≤max_edge"""
    import cv2
    import numpy as np
    img = cv2.imdecode(np.fromfile(image_path, dtype=np.uint8), cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError(f"无法解码图片: {image_path}")
    return _resize_long_edge(img, max_edge)


def _morphology_enhance_digits(binary_img, kernel_size: int = 2):
    """
    数字/小数点专用形态学增强
    - 开运算：断开细小连接，分离粘连数字
    - 闭运算：填补数字笔画断裂
    """
    import cv2
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (kernel_size, kernel_size))
    opened = cv2.morphologyEx(binary_img, cv2.MORPH_OPEN, kernel)
    closed = cv2.morphologyEx(opened, cv2.MORPH_CLOSE, kernel)
    return closed


def _preprocess_image(img, strategy: str = "auto"):
    """
    智能图像预处理

    strategy:
      - "auto":   自动根据亮度分流
      - "light":  轻度增强（普通光线→快速通道）
      - "heavy":  全管线重度处理（反光/暗光）
      - "binary": 仅二值化（黑白说明书）
    """
    import cv2
    import numpy as np

    # 先缩放到长边≤1280px
    img = _resize_long_edge(img, MAX_LONG_EDGE)

    # 自动亮度判断
    if strategy == "auto":
        brightness = _estimate_brightness(img)
        if brightness > 100:    # 正常/明亮光线
            strategy = "light"
        else:                   # 暗光/反光
            strategy = "heavy"

    # ─── 轻量策略（25-50ms） ───
    if strategy == "light":
        lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
        lightness_chan, a, b = cv2.split(lab)
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        lightness_chan = clahe.apply(lightness_chan)
        enhanced = cv2.merge([lightness_chan, a, b])
        enhanced = cv2.cvtColor(enhanced, cv2.COLOR_LAB2BGR)

        # 轻微锐化
        kernel = np.array([[-0.5, -0.5, -0.5],
                           [-0.5,  5.0, -0.5],
                           [-0.5, -0.5, -0.5]])
        enhanced = cv2.filter2D(enhanced, -1, kernel)
        gray = cv2.cvtColor(enhanced, cv2.COLOR_BGR2GRAY)
        return gray, "light"

    # ─── 重度策略（80-150ms） ───
    if strategy == "heavy":
        # 1. CLAHE
        lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
        lightness_chan, a, b = cv2.split(lab)
        clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
        lightness_chan = clahe.apply(lightness_chan)
        enhanced = cv2.merge([lightness_chan, a, b])
        enhanced = cv2.cvtColor(enhanced, cv2.COLOR_LAB2BGR)

        # 2. 灰度
        gray = cv2.cvtColor(enhanced, cv2.COLOR_BGR2GRAY)

        # 3. 去反光：光照补偿
        blur = cv2.GaussianBlur(gray, (45, 45), 0)
        illumination = cv2.divide(gray, blur + 1, scale=255)
        gray = cv2.convertScaleAbs(illumination)

        # 4. 双策略二值化融合
        _, otsu = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        adaptive = cv2.adaptiveThreshold(
            gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY, 31, 2
        )
        if cv2.countNonZero(cv2.bitwise_not(otsu)) > cv2.countNonZero(cv2.bitwise_not(adaptive)):
            binary = otsu
        else:
            binary = adaptive

        # 5. 去噪
        denoised = cv2.fastNlMeansDenoising(binary, None, 10, 7, 21)

        # 6. 形态学增强
        denoised = _morphology_enhance_digits(denoised, kernel_size=2)

        # 7. 闭合运算填补文字断裂
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
        denoised = cv2.morphologyEx(denoised, cv2.MORPH_CLOSE, kernel)

        return denoised, "heavy"

    # ─── 纯二值化（黑白文档） ───
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    return binary, "binary"


# ═══════════════════════════════════════════════════════
#  第2层：并行推理（Rapid + Paddle）
# ═══════════════════════════════════════════════════════

def _run_engine(engine_name: str, image_input, min_confidence: float = 0.0) -> tuple[list[str], list[float]]:
    """单引擎推理"""
    texts = []
    scores = []
    try:
        engine = _get_engine(engine_name)
        if engine is None:
            return texts, scores
        if engine_name == "rapid":
            result, elapse = engine(image_input)
            if result:
                for line in result:
                    _, text, score = line
                    if text and text.strip():
                        texts.append(text.strip())
                        scores.append(float(score) if score else 0.0)

        elif engine_name == "paddleocr":
            result = engine.ocr(image_input, cls=True)
            if result and result[0]:
                for line in result[0]:
                    _, (text, score) = line
                    if text and text.strip() and score >= min_confidence:
                        texts.append(text.strip())
                        scores.append(float(score))

        elif engine_name == "easyocr":
            result = engine.readtext(image_input)
            for _, text, conf in result:
                if text and text.strip() and conf >= min_confidence:
                    texts.append(text.strip())
                    scores.append(float(conf))

    except Exception as e:
        logger.warning(f"{engine_name} 推理异常: {e}")

    return texts, scores


def _parallel_ocr(image_input) -> tuple[list[str], list[float], str]:
    """
    Rapid + Paddle 并行推理 → 多引擎加权投票融合结果
    如果两者都有结果，加权合并；都没有再走EasyOCR兜底
    """
    rapid_future = _parallel_pool.submit(_run_engine, "rapid", image_input)
    paddle_future = _parallel_pool.submit(_run_engine, "paddleocr", image_input, 0.5)

    rapid_texts, rapid_scores = rapid_future.result()
    paddle_texts, paddle_scores = paddle_future.result()

    # ─── 加权融合策略 ───
    all_texts = []
    seen = set()

    # RapidOCR的文本置信度权重=1.0
    for t, s in zip(rapid_texts, rapid_scores):
        if t not in seen:
            all_texts.append((t, s, "rapid", 1.0))
            seen.add(t)

    # PaddleOCR的文本置信度权重=1.2（Paddle通常更准）
    for t, s in zip(paddle_texts, paddle_scores):
        if t not in seen:
            all_texts.append((t, s, "paddleocr", 1.2))
            seen.add(t)

    # 按加权置信度排序，去重保留高权重的
    all_texts.sort(key=lambda x: x[1] * x[3], reverse=True)

    # 仅当两个引擎都无结果时才走EasyOCR兜底
    if not all_texts:
        try:
            easy_texts, easy_scores = _run_engine("easyocr", image_input, 0.3)
            if easy_texts:
                logger.info(f"EasyOCR兜底识别成功: {len(easy_texts)} 条文本")
                return easy_texts, easy_scores, "EasyOCR"
        except Exception as e:
            logger.warning(f"EasyOCR兜底失败: {e}")
        return [], [], "none"

    final_texts = [t for t, _, _, _ in all_texts]
    final_scores = [s for _, s, _, _ in all_texts]
    engines_used = {e for _, _, e, _ in all_texts}
    engine_label = "+".join(sorted(engines_used))

    return final_texts, final_scores, engine_label


# ═══════════════════════════════════════════════════════
#  第3层：文本后处理与纠错（增强版）
# ═══════════════════════════════════════════════════════

def _clean_ocr_text(text: str) -> str:
    """清理OCR乱码字符"""
    text = re.sub(r'[^\u4e00-\u9fff\w\s\.\:\,\-\(\)\/\%\#\~\·\+\*>]', '', text)
    text = re.sub(r'\s+', '', text)
    return text.strip()


def _correct_medicine_name(text: str) -> str:
    """基于药品词库的最佳匹配修正（加强版加权匹配）"""
    text_clean = _clean_ocr_text(text)
    if not text_clean:
        return ""

    has_suffix = any(text_clean.endswith(s) or s in text_clean for s in MEDICINE_SUFFIXES)

    best_match = None
    best_score = 0
    for word in MEDICINE_VOCABULARY:
        # 完全匹配 → 最高分
        if word == text_clean:
            return word

        # 词库词是识别文本的一部分 → 高置信度
        contained = word in text_clean
        # 识别文本是词库词的一部分（词库更长）
        part_of = text_clean in word

        if contained:
            score = len(word) * 3 + (10 if has_suffix else 0)
        elif part_of:
            score = len(text_clean) * 2.5 + (5 if has_suffix else 0)
        else:
            # 模糊匹配：公共子序列
            common = sum(1 for c in word if c in text_clean)
            if common >= len(word) * 0.6:
                score = common * 2 + (5 if has_suffix else 0)
            else:
                continue

        if score > best_score:
            best_score = score
            best_match = word

    if best_match and best_score >= 3:
        return best_match
    return text_clean


def _normalize_unit(text: str) -> str:
    """归一化药品单位"""
    if not text:
        return text
    for raw, norm in UNIT_NORMALIZE.items():
        if raw in text:
            text = text.replace(raw, norm)
    return text


def _parse_medicine_text(ocr_texts: list[str], ocr_scores: list[float]) -> dict:
    """从OCR文本列表提取结构化药品信息（增强版）"""
    result = {"name": "", "dosage": "", "frequency": "", "raw_texts": ocr_texts}
    if not ocr_texts:
        return result

    all_text = " ".join(ocr_texts)

    # ─── 1. 药品名称 ───
    name_candidates = []
    for idx, text in enumerate(ocr_texts):
        text_clean = _clean_ocr_text(text)
        if not text_clean:
            continue
        cn_chars = len(re.findall(r'[\u4e00-\u9fff]', text_clean))
        if cn_chars < 2 or len(text_clean) > 30:
            continue

        # 词库加权匹配
        direct_match = ""
        vocab_score = 0
        for word in MEDICINE_VOCABULARY:
            if word in text_clean:
                ds = len(word) * 3
                if ds > vocab_score:
                    vocab_score = ds
                    direct_match = word

        has_suffix = any(
            text_clean.endswith(s) or s in text_clean[-4:]
            for s in MEDICINE_SUFFIXES
        )
        ocr_score = ocr_scores[idx] if idx < len(ocr_scores) else 0.0

        name_candidates.append({
            "text": text_clean,
            "has_suffix": has_suffix,
            "cn_chars": cn_chars,
            "vocab_score": vocab_score,
            "direct_match": direct_match,
            "ocr_score": ocr_score,
        })

    if name_candidates:
        name_candidates.sort(
            key=lambda x: (x["vocab_score"], x["has_suffix"], x["ocr_score"], x["cn_chars"]),
            reverse=True,
        )
        best = name_candidates[0]
        if best["direct_match"]:
            result["name"] = best["direct_match"]
        else:
            corrected = _correct_medicine_name(best["text"])
            result["name"] = corrected if corrected else best["text"]

    # ─── 2. 剂量规格（加强正则） ───
    dosage_patterns = [
        # 带小数点的规格，如 "0.5g" "1.25mg"... 优先匹配
        r'(\d+\.\d+\s*(?:mg|毫克|g|克|ml|毫升|μg|微克|ug))',
        # 整数规格
        r'(\d+\s*(?:mg|毫克|ml|毫升|g|克|μg|微克|ug|IU|单位))',
        # 每片/粒含XXX
        r'每(?:片|粒|袋|支|丸)\s*含\s*(\d+\.?\d*\s*(?:mg|毫克|ml|g|克|μg))',
        # 规格：XXX
        r'规格[：:]\s*(\d+\.?\d*\s*(?:mg|毫克|ml|g|克|μg|IU))',
        # 0.1g*12片 或 0.1g×12片
        r'(\d+\.?\d*\s*(?:mg|g))\s*[*×xX]\s*\d+',
        # 100mg/片
        r'(\d+\.?\d*\s*(?:mg|g|ml))\s*[/每](?:片|粒|袋|ml)',
    ]
    for pat in dosage_patterns:
        m = re.search(pat, all_text, re.IGNORECASE)
        if m:
            dosage = _normalize_unit(m.group(1).strip())
            result["dosage"] = dosage
            break

    if not result["dosage"]:
        # 兜底：数字+规格单位
        m = re.search(r'(\d+\.?\d*)\s*(mg|克|g|ml|毫升|μg|微克|IU|单位)', all_text, re.IGNORECASE)
        if m:
            result["dosage"] = _normalize_unit(f"{m.group(1)}{m.group(2)}")

    if not result["dosage"]:
        # 兜底：数字+服用单位
        m = re.search(r'每[次回]\s*(\d+\.?\d*)\s*(粒|片|袋|支|丸)', all_text, re.IGNORECASE)
        if m:
            result["dosage"] = f"{m.group(1)}{m.group(2)}"
        else:
            m = re.search(r'(\d+\.?\d*)\s*(粒|片|袋|支|丸)', all_text, re.IGNORECASE)
            if m:
                result["dosage"] = f"{m.group(1)}{m.group(2)}"

    # ─── 3. 用药频率 ───
    freq_patterns = [
        r'((?:一|每|1)\s*[天日]\s*(?:\d+|[一二三四两])\s*[次回])',
        r'((?:一|每|1)\s*[天日]\s*[一二三四两])',
        r'(每[天日]\s*(?:\d+|[一二三四两])\s*[次回])',
        r'(\d+\s*[次回]\s*[/每][天日])',
        r'\b(bid|tid|qd|qid|BID|TID|QD|QID)\b',
    ]
    for pat in freq_patterns:
        m = re.search(pat, all_text, re.IGNORECASE)
        if m:
            freq_text = m.group(1).strip()
            cn_map = {"一": "1", "二": "2", "两": "2", "三": "3", "四": "4"}
            for cn, num in cn_map.items():
                freq_text = freq_text.replace(cn, num)
            lower = freq_text.lower()
            mapping = {"bid": "一天2次", "tid": "一天3次", "qd": "一天1次", "qid": "一天4次"}
            if lower in mapping:
                freq_text = mapping[lower]
            result["frequency"] = freq_text
            break

    if not result["frequency"]:
        m = re.search(r'[一每][天日日]\s*(\d+)\s*[次回]', all_text)
        if m:
            result["frequency"] = f"一天{m.group(1)}次"

    return result


# ═══════════════════════════════════════════════════════
#  日志：失败图片 + 耗时记录
# ═══════════════════════════════════════════════════════

def _save_failed_ocr(image_data: bytes, raw_texts: list[str], engine_used: str):
    try:
        FAILED_OCR_DIR.mkdir(parents=True, exist_ok=True)
        ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S_%f")
        img_path = FAILED_OCR_DIR / f"{ts}.jpg"
        log_path = FAILED_OCR_DIR / f"{ts}.json"
        with open(img_path, "wb") as f:
            f.write(image_data)
        with open(log_path, "w", encoding="utf-8") as f:
            json.dump({
                "timestamp": ts, "engine_used": engine_used,
                "text_count": len(raw_texts), "raw_texts": raw_texts,
                "image_path": str(img_path),
            }, f, ensure_ascii=False, indent=2)
    except Exception as e:
        logger.warning(f"保存OCR失败日志异常: {e}")


# ═══════════════════════════════════════════════════════
#  API 端点
# ═══════════════════════════════════════════════════════

@router.post("/recognize")
async def recognize_medicine(file: UploadFile = File(...)):
    """
    上传药盒照片，返回OCR识别的药品信息（v3.2 优化版）

    优化流程：
      上传图片 → 特征缓存校验（相同图片命中直接返回）
      → 图片缩放(长边≤1280px) → 亮度判断 → 轻度/重预处理分流
      → Rapid+Paddle并行推理 → 加权融合 → 无结果→EasyOCR兜底
      → 药品词库加权匹配 → 字段提取 → 缓存结果

    返回字段：
      success: bool        是否提取到药品名
      name: str            药品名称
      dosage: str          剂量规格
      frequency: str       用药频率
      raw_texts: [str]     OCR原始文本
      engine_used: str     引擎标签
      timing_ms: int       总耗时ms
      cached: bool         是否缓存命中
    """
    timing_total = time.time()
    timing_steps = {}

    # ─── 文件校验 ───
    if file.content_type and file.content_type not in ALLOWED_TYPES:
        raise HTTPException(400, f"不支持的文件格式: {file.content_type}")

    content = await file.read()
    if len(content) > MAX_IMAGE_BYTES:
        raise HTTPException(400, "图片过大，请上传10MB以内的图片")

    t0 = time.time()
    fp = _image_fingerprint(content)
    cached = _get_cached(fp)
    timing_steps["cache_check"] = round((time.time() - t0) * 1000)
    if cached is not None:
        cached["cached"] = True
        cached["timing_ms"] = round((time.time() - timing_total) * 1000)
        return cached

    suffix = ".jpg"
    if file.filename:
        ext = os.path.splitext(file.filename)[1].lower()
        if ext in {".png", ".jpg", ".jpeg", ".webp"}:
            suffix = ext

    texts = []
    scores = []
    engine_used = "none"
    preprocess_used = "none"
    tmp_path = None

    try:
        # ─── 保存临时文件（用于后续预处理） ───
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp.write(content)
            tmp_path = tmp.name

        # ─── 方案1：快速通道 — 原图缩放→亮度判断→分流 ───
        t_pre = time.time()
        img = _resize_long_edge_path(tmp_path, MAX_LONG_EDGE)
        brightness = _estimate_brightness(img)

        # 根据亮度决定预处理策略
        if brightness > 100:
            processed_img, preprocess_used = _preprocess_image(img, "light")
        else:
            processed_img, preprocess_used = _preprocess_image(img, "heavy")
        timing_steps["preprocess"] = round((time.time() - t_pre) * 1000)

        # ─── 并行推理（Rapid + Paddle） ───
        t_ocr = time.time()
        texts, scores, engine_used = _parallel_ocr(processed_img)
        timing_steps["ocr"] = round((time.time() - t_ocr) * 1000)

        # ─── EasyOCR兜底（仅当完全无结果时） ───
        if not texts:
            t_easy = time.time()
            try:
                easy_texts, easy_scores = _run_engine("easyocr", img, 0.3)
                if easy_texts:
                    texts = easy_texts
                    scores = easy_scores
                    engine_used = "EasyOCR"
                    preprocess_used = "none"
            except Exception as e:
                logger.warning(f"EasyOCR兜底失败: {e}")
            timing_steps["easyocr_fallback"] = round((time.time() - t_easy) * 1000)

        # ─── 提取药品信息 ───
        t_parse = time.time()
        medicine_info = _parse_medicine_text(texts, scores)
        timing_steps["parse"] = round((time.time() - t_parse) * 1000)

        # ─── 保存失败日志 ───
        if not texts:
            _save_failed_ocr(content, [], engine_used)

        result = {
            "success": bool(medicine_info["name"]),
            "name": medicine_info["name"],
            "dosage": medicine_info["dosage"],
            "frequency": medicine_info["frequency"],
            "raw_texts": texts,
            "engine_used": engine_used,
            "preprocess": preprocess_used,
            "brightness": round(brightness, 1),
            "cached": False,
            "timing_ms": round((time.time() - timing_total) * 1000),
            "timing_steps": timing_steps,
        }

        # ─── 缓存结果 ───
        if texts:
            _set_cache(fp, result)

        total_ms = result["timing_ms"]
        if total_ms > TIMING_WARN_MS:
            logger.warning(f"OCR耗时过长: {total_ms}ms steps={timing_steps}")
        else:
            logger.info(f"OCR完成: {total_ms}ms engine={engine_used} steps={timing_steps}")

        return result

    except ImportError as e:
        raise HTTPException(503, f"OCR服务暂不可用: {e}")
    except Exception as e:
        logger.error(f"OCR识别失败: {e}", exc_info=True)
        _save_failed_ocr(content, [], engine_used)
        raise HTTPException(500, f"OCR识别失败: {str(e)}")
    finally:
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except Exception:
                pass
