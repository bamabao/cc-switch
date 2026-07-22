"""
火山方舟视觉模型 — 药品图像识别服务
调用 Doubao-Seed-2.0-pro（OpenAI 兼容协议）
识别药盒图片，返回结构化药品信息，结果自动写入 medicine_cache 表。

接口文档：https://www.volcengine.com/docs/82379/1263482
"""
import os
import base64
import json
import logging
from typing import Optional

import httpx

from app.models.base import SessionLocal
from app.models.medicine_cache import MedicineCache

logger = logging.getLogger("bamabao.volcengine_vision")

# ━━━ 火山方舟配置 ━━━
VOLC_API_URL = "https://ark.cn-beijing.volcengine.com/api/v3/chat/completions"
VOLC_API_KEY = os.getenv("VOLCANO_VISION_API_KEY", "")
VOLC_MODEL = "doubao-vision-v1"
TIMEOUT_SEC = 10

# ━━━ 视觉模型 prompt ━━━
SYSTEM_PROMPT = """
你是一个药品识别专家。请仔细查看药盒图片，提取以下药品信息：
1. 药品名称（完整通用名或商品名，如"布洛芬缓释胶囊""阿莫西林胶囊"）
2. 剂型规格（如"0.5g""500mg""10mg""100mg/粒"等）
3. 服用频次（如"一天3次""bid""一天2次""一次1粒"等）
4. 药品分类（从以下类别中选择一项：抗生素、解热镇痛、心血管、糖尿病、消化、呼吸感冒、神经精神、中成药、妇科儿科、维生素保健品、外用、其他）

请以 JSON 格式返回，严格遵循以下 schema：
{
  "name": "药品完整名称",
  "dosage": "剂型规格",
  "frequency": "服用频次",
  "category": "药品分类"
}

注意事项：
- name 字段不能为空，如果完全无法识别药品名称，返回 {"name": ""}
- dosage/frequency/category 未知时返回空字符串
- 只返回 JSON，不要包含其他说明文字
"""


def _encode_image(image_bytes: bytes) -> str:
    """将图片字节编码为 base64 data URI"""
    return base64.b64encode(image_bytes).decode("utf-8")


def _build_messages(image_base64: str) -> list[dict]:
    """构建多模态消息体"""
    return [
        {"role": "system", "content": SYSTEM_PROMPT},
        {
            "role": "user",
            "content": [
                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"}},
                {"type": "text", "text": "请识别这张药盒图片中的药品信息。"},
            ],
        },
    ]


def _parse_response(raw: str) -> Optional[dict]:
    """从模型回复中提取 JSON 结果"""
    text = raw.strip()
    # 尝试直接解析
    try:
        data = json.loads(text)
        if isinstance(data, dict):
            return data
    except json.JSONDecodeError:
        pass
    # 尝试从 markdown 代码块中提取
    import re

    m = re.search(r"```(?:json)?\s*\n?(.*?)\n?```", text, re.DOTALL)
    if m:
        try:
            return json.loads(m.group(1).strip())
        except json.JSONDecodeError:
            pass
    # 尝试抽取花括号内容
    m = re.search(r"\{[^{}]*\}", text, re.DOTALL)
    if m:
        try:
            return json.loads(m.group(0))
        except json.JSONDecodeError:
            pass
    return None


def _save_to_cache(db, name: str, dosage: str, frequency: str, category: str, source: str):
    """将识别结果写入 medicine_cache 表（upsert）"""
    entry = db.query(MedicineCache).filter(
        MedicineCache.medicine_name == name
    ).first()
    if entry:
        entry.dosage = dosage or entry.dosage
        entry.frequency = frequency or entry.frequency
        entry.category = category or entry.category
        entry.source = source
        entry.hit_count += 1
    else:
        entry = MedicineCache(
            medicine_name=name,
            dosage=dosage or "",
            frequency=frequency or "",
            category=category or "",
            source=source,
        )
        db.add(entry)
    db.commit()
    logger.info(f"火山视觉结果已写入缓存: {name}")


async def volcengine_vision_recognize(
    image_bytes: bytes,
    db=None,
) -> Optional[dict]:
    """
    调用火山方舟视觉模型识别药盒图片

    参数
    ----
    image_bytes : bytes
        原始图片字节数据
    db : Session, optional
        数据库会话（有则自动写入缓存，无则只返回结果）

    返回
    ----
    dict or None
        {"name": "...", "dosage": "...", "frequency": "...", "category": "..."}
        调用失败或无法识别时返回 None
    """
    try:
        image_b64 = _encode_image(image_bytes)
        messages = _build_messages(image_b64)
        payload = {
            "model": VOLC_MODEL,
            "messages": messages,
            "temperature": 0.1,
            "max_tokens": 1024,
        }
        async with httpx.AsyncClient(timeout=TIMEOUT_SEC) as client:
            resp = await client.post(
                VOLC_API_URL,
                headers={
                    "Authorization": f"Bearer {VOLC_API_KEY}",
                    "Content-Type": "application/json",
                },
                json=payload,
            )
            resp.raise_for_status()
            body = resp.json()

        # 提取回复文本
        choices = body.get("choices", [])
        if not choices:
            logger.warning("火山视觉返回空 choices")
            return None
        content = choices[0].get("message", {}).get("content", "")
        if not content:
            logger.warning("火山视觉返回空 content")
            return None
        parsed = _parse_response(content)
        if not parsed:
            logger.warning(f"火山视觉返回无法解析: {content[:200]}")
            return None
        name = (parsed.get("name") or "").strip()
        if not name:
            logger.info("火山视觉未能识别药品名称")
            return None
        result = {
            "name": name,
            "dosage": (parsed.get("dosage") or "").strip(),
            "frequency": (parsed.get("frequency") or "").strip(),
            "category": (parsed.get("category") or "").strip(),
        }
        logger.info(f"火山视觉识别成功: {name}")

        # 自动写入缓存
        if db is not None:
            _save_to_cache(
                db,
                name=result["name"],
                dosage=result["dosage"],
                frequency=result["frequency"],
                category=result["category"],
                source="volcano_vision",
            )
        return result
    except httpx.TimeoutException:
        logger.warning("火山视觉调用超时 (>10s)")
    except httpx.HTTPStatusError as e:
        logger.warning(f"火山视觉 HTTP 错误: {e.response.status_code} {e.response.text[:200]}")
    except Exception as e:
        logger.warning(f"火山视觉调用异常: {e}", exc_info=True)
    return None
