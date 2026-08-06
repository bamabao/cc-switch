"""爸妈宝 AI 智能助手 - 用药问答弹窗"""
import json
import logging
import os
import urllib.request

logger = logging.getLogger(__name__)

# ─── API 配置 ───
_HERMES_ENV = r"C:\Users\74897\AppData\Local\hermes\.env"
_DEEPSEEK_KEY = ""

if os.path.exists(_HERMES_ENV):
    with open(_HERMES_ENV) as f:
        for line in f:
            if line.startswith("DEEPSEEK_API_KEY="):
                _DEEPSEEK_KEY = line.strip().split("=", 1)[1]
                break

DEEPSEEK_API_KEY = _DEEPSEEK_KEY or os.environ.get("DEEPSEEK_API_KEY", "")
DEEPSEEK_BASE_URL = "https://api.deepseek.com/v1"
AI_MODEL = "deepseek-chat"
def _call_deepseek(messages: list, temperature: float = 0.3, max_tokens: int = 1000) -> str:
    """调用 DeepSeek API"""
    if not DEEPSEEK_API_KEY:
        return "AI服务未配置。"
    try:
        body = json.dumps({
            "model": AI_MODEL,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens,
        }).encode()
        req = urllib.request.Request(
            f"{DEEPSEEK_BASE_URL}/chat/completions",
            data=body,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
            },
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read())
            return data["choices"][0]["message"]["content"]
    except urllib.error.HTTPError as e:
        logger.error(f"DeepSeek API HTTP {e.code}")
        return f"AI服务暂时不可用（{e.code}）"
    except Exception as e:
        logger.error(f"DeepSeek API 失败: {e}")
        return "AI服务暂时不可用"


# ─── 紧急关键词 ───
EMERGENCY_KEYWORDS = [
    "呼吸困难", "喘不上气", "休克", "昏迷", "大出血", "吐血",
    "心跳", "120", "救命", "不行了", "快死了", "晕倒",
    "过敏", "红肿", "呼吸困难", "抽搐",
]


def check_emergency(text: str) -> bool:
    """检测用户消息是否包含紧急关键词"""
    for kw in EMERGENCY_KEYWORDS:
        if kw in text:
            return True
    return False


def generate_drug_report(drug_name: str, indications: str = "", 
                          adult_dosage: str = "", child_dosage: str = "",
                          elderly_dosage: str = "", contraindications: str = "",
                          side_effects: str = "", precautions: str = "") -> str:
    """生成通俗易懂的药品说明书摘要"""
    prompt = f"""请为患者生成一份通俗易懂的药品说明摘要，药品：{drug_name}

参考信息：
- 适应症：{indications or '未知'}
- 成人用量：{adult_dosage or '未知'}
- 儿童用量：{child_dosage or '未知'}
- 老年用量：{elderly_dosage or '未知'}
- 禁忌：{contraindications or '未知'}
- 不良反应：{side_effects or '未知'}
- 注意事项：{precautions or '未知'}

要求：
1. 用通俗语言，少用专业术语
2. 突出最重要的3-5个要点
3. 控制在200字以内
4. 语气亲切""" 

    return _call_deepseek([
        {"role": "system", "content": "你是一位贴心的药师，擅长用通俗语言解释药品信息。"},
        {"role": "user", "content": prompt},
    ], temperature=0.5)


def check_interaction(drugs: list) -> str:
    """检查药物相互作用"""
    if len(drugs) < 2:
        return "只需检查一种药即可。"
    
    drug_list = "、".join(drugs)
    prompt = f"""用户同时服用以下药物：{drug_list}
请分析是否存在相互作用风险。
格式：
- 有风险→列出具体风险，用⚠️标注
- 无风险→说明"无明显相互作用"
- 控制在150字以内"""
    
    return _call_deepseek([
        {"role": "system", "content": "你是药物相互作用专家。"},
        {"role": "user", "content": prompt},
    ])


def ask_drug_question(question: str, drug_name: str = "", context: str = "") -> str:
    """用药问答"""
    system_prompt = """你是一位专业的药师助手。回答要准确简洁，用通俗语言。
涉及剂量等问题时提醒以医生为准。控制在200字以内。不知道就说不知道。"""
    user_msg = f"用户问题：{question}"
    if drug_name:
        user_msg += f"\n相关药品：{drug_name}"
    if context:
        user_msg += f"\n参考信息：{context}"
    return _call_deepseek([
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_msg},
    ])


def check_drug_interaction(drugs: list) -> str:
    """检查多种药物相互作用（兼容旧接口）"""
    return check_interaction(drugs)


def generate_weekly_report(checkin_data: list) -> str:
    """生成每周用药报告"""
    if not checkin_data:
        return "本周暂无数据。"
    prompt = f"""以下是本周用药打卡数据：{json.dumps(checkin_data, ensure_ascii=False)[:2000]}
请生成周报，包含打卡率、用药规律、建议。200字以内。"""
    return _call_deepseek([
        {"role": "system", "content": "你是一位贴心的健康助手。"},
        {"role": "user", "content": prompt},
    ], temperature=0.7)
