"""App 版本管理与升级 API"""
import logging
from datetime import datetime
from fastapi import APIRouter

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/app", tags=["app"])

# ─── 版本配置 ───
# 每次发版时更新这里
APP_VERSION = "3.9"
APP_BUILD = 39
APP_DOWNLOAD_URL = "https://bambaodownload.loca.lt"

# ─── 推广联盟配置 ───
# 注册京东联盟(union.jd.com)后替换APP_ID
JD_UNION_APP_ID = ""  # 京东联盟APP ID
JD_SEARCH_URL = "https://search.jd.com/Search?keyword={keyword}"
JD_UNION_URL = "https://union-click.jd.com/jd?e={}&p=JF8BANQJFGwUXA4CGVAfAEoQB18IHVMcWgYzUFtdVH{unionId}&keyword={keyword}"

# 注册美团联盟(union.meituan.com)后替换APP_ID
MT_UNION_APP_ID = ""  # 美团联盟APP ID  
MT_SEARCH_URL = "https://waimai.meituan.com/search?keyword={keyword}"
MT_UNION_URL = "https://click.meituan.com/t/?t={}&c=2&keyword={keyword}"
APP_UPDATE_LOG = """新版本 v3.9 更新内容：

📖 新增146种药品说明书数据库，点卡片看适应症/注意事项/禁忌
💊 买药三渠道：京东搜索 / 附近药店 / 提醒子女 / 美团外卖
🤖 AI用药助手：问用法、禁忌、注意事项
📦 库存预警：剩余天数自动显示（红<7天/橙<14天）
🔄 服药频次：每日 / 每周 / 隔日 / 按需四档
📷 OCR识别优化：总量自动提取、适应症独立展示、过滤厂商名
🎨 UI优化：粉色甜甜圈按钮增大50%、服药时间弹窗
🐛 修复：首页数据不更新、多时段打卡、API端口被占用
"""

# ─── 免责声明 ───
DISCLAIMER = """【重要提醒】
爸妈宝提供的所有用药提醒、药品说明书、AI问答等内容仅供参考，不能替代专业医疗建议。
在使用本App的任何功能前，请务必：
1. 咨询专业医生或药师
2. 以医生的处方和指导为准
3. 定期到医院复查
4. 如有不适，立即就医
本App不承担因使用提醒信息而产生的任何医疗责任。"""


# ─── 医生版版本配置 ───
DOCTOR_APP_VERSION = "1.0"
DOCTOR_APP_BUILD = 1
DOCTOR_APP_DOWNLOAD_URL = "http://192.168.10.3:8888/爸妈宝医生版.apk"
DOCTOR_APP_UPDATE_LOG = """医生版 v1.0 首发

👨‍⚕️ 患者管理：绑定患者、查看用药记录
💬 医患聊天：AI建议回复一键发送
🚨 紧急消息：呼吸困难等立即标红
👩‍⚕️ 助理团队：授权助理协助回复
💳 套餐订阅：免费/个人/工作室/医院
📊 运营看板：实时收入与用户数据
"""


@router.get("/doctor-version")
def get_doctor_version():
    """获取医生版最新版本信息"""
    return {
        "version": DOCTOR_APP_VERSION,
        "build": DOCTOR_APP_BUILD,
        "download_url": DOCTOR_APP_DOWNLOAD_URL,
        "update_log": DOCTOR_APP_UPDATE_LOG.strip(),
        "force_update": False,
    }


@router.get("/version")
def get_version():
    """获取最新版本信息"""
    return {
        "version": APP_VERSION,
        "build": APP_BUILD,
        "download_url": APP_DOWNLOAD_URL,
        "update_log": APP_UPDATE_LOG.strip(),
        "release_date": datetime.now().strftime("%Y-%m-%d"),
        "force_update": False,
        "promotion": {
            "jd_search_url": JD_SEARCH_URL,
            "mt_search_url": MT_SEARCH_URL,
            "jd_union_id": JD_UNION_APP_ID or None,
            "mt_union_id": MT_UNION_APP_ID or None,
        },
        "disclaimer": DISCLAIMER.strip(),
    }
