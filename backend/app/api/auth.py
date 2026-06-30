"""
用户认证体系 — JWT + 微信 OpenID 登录
- 老人端 APP：手机号 + 验证码 或 微信授权
- 子女端小程序：微信授权登录
"""
from datetime import datetime, timedelta
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from pydantic import BaseModel
from jose import jwt, JWTError
from passlib.context import CryptContext

from app.models.base import get_db
from app.models.user import User, UserRole, FamilyBinding
from app.core.config import get_settings

router = APIRouter(prefix="/api/v1/auth", tags=["用户认证"])
settings = get_settings()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ========== Schemas ==========

class WechatLoginRequest(BaseModel):
    code: str  # 微信 wx.login() 返回的 code
    role: str = "child"  # elder | child


class PhoneLoginRequest(BaseModel):
    phone: str
    code: str  # 短信验证码（一期可mock）
    role: str = "elder"


class BindFamilyRequest(BaseModel):
    elder_phone: str  # 老人手机号


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    role: str
    nickname: str


class UserInfoResponse(BaseModel):
    id: int
    nickname: str
    avatar_url: str
    role: str
    phone: Optional[str] = None
    voice_preference: Optional[str] = None
    font_scale: Optional[int] = None
    total_points: Optional[int] = None
    current_streak: Optional[int] = None
    family_members: list = []


# ========== 工具函数 ==========

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=settings.access_token_expire_minutes))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.secret_key, algorithm=settings.algorithm)


def verify_token(token: str) -> dict:
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
        return payload
    except JWTError:
        raise HTTPException(401, "无效的认证令牌")


def get_current_user(token: str = Depends(lambda: ""), db: Session = Depends(get_db)) -> User:
    """从请求头解析 JWT → 返回当前用户"""
    # 一期简化：直接通过 query param 传 token
    # 生产环境应从 Authorization header 解析
    if not token:
        raise HTTPException(401, "未提供认证令牌")
    payload = verify_token(token)
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(401, "无效的认证令牌")
    user = db.query(User).filter(User.id == int(user_id)).first()
    if not user:
        raise HTTPException(401, "用户不存在")
    return user


# ========== API ==========

@router.post("/login/wechat", response_model=TokenResponse)
def login_by_wechat(body: WechatLoginRequest, db: Session = Depends(get_db)):
    """
    微信登录（子女小程序 + 老人APP微信授权）
    一期：code 直接当 openid 用（mock）
    生产：调微信 code2session 接口换 openid
    """
    # TODO: 调用微信 code2session API
    mock_openid = f"wx_{body.code}"

    user = db.query(User).filter(User.openid == mock_openid).first()
    if not user:
        # 新用户自动注册
        user = User(
            openid=mock_openid,
            role=UserRole(body.role),
            nickname=f"用户{mock_openid[-4:]}",
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    token = create_access_token({"sub": str(user.id), "role": user.role.value})
    return TokenResponse(
        access_token=token,
        user_id=user.id,
        role=user.role.value,
        nickname=user.nickname,
    )


@router.post("/login/phone", response_model=TokenResponse)
def login_by_phone(body: PhoneLoginRequest, db: Session = Depends(get_db)):
    """
    手机号 + 验证码登录（老人端 APP）
    一期：验证码固定 123456
    """
    if body.code != "123456":
        raise HTTPException(400, "验证码错误")

    user = db.query(User).filter(User.phone == body.phone).first()
    if not user:
        user = User(
            phone=body.phone,
            role=UserRole(body.role),
            nickname=f"用户{body.phone[-4:]}",
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    token = create_access_token({"sub": str(user.id), "role": user.role.value})
    return TokenResponse(
        access_token=token,
        user_id=user.id,
        role=user.role.value,
        nickname=user.nickname,
    )


@router.post("/send-sms")
def send_sms_code(phone: str = Query(...)):
    """发送短信验证码（一期 mock）"""
    # TODO: 接入阿里云/腾讯云短信
    return {"message": "验证码已发送", "code": "123456"}  # 一期直接返回


@router.post("/bind-family")
def bind_family(
    body: BindFamilyRequest,
    child_id: int = Query(...),
    db: Session = Depends(get_db),
):
    """子女绑定老人（通过老人手机号）"""
    elder = db.query(User).filter(
        User.phone == body.elder_phone,
        User.role == UserRole.ELDER,
    ).first()
    if not elder:
        raise HTTPException(404, "未找到该手机号对应的老人用户")

    # 检查是否已绑定
    existing = db.query(FamilyBinding).filter(
        FamilyBinding.elder_id == elder.id,
        FamilyBinding.child_id == child_id,
        FamilyBinding.is_active == True,
    ).first()
    if existing:
        raise HTTPException(400, "已绑定该老人")

    binding = FamilyBinding(elder_id=elder.id, child_id=child_id, relation_label="")
    db.add(binding)
    db.commit()
    return {"message": "绑定成功", "elder_id": elder.id, "elder_nickname": elder.nickname}


@router.get("/me", response_model=UserInfoResponse)
def get_my_info(
    token: str = Query(...),
    db: Session = Depends(get_db),
):
    """获取当前用户信息"""
    user = get_current_user(token, db)

    # 获取家庭成员
    family = []
    if user.role == UserRole.ELDER:
        bindings = db.query(FamilyBinding).filter(
            FamilyBinding.elder_id == user.id,
            FamilyBinding.is_active == True,
        ).all()
        for b in bindings:
            child = db.query(User).filter(User.id == b.child_id).first()
            if child:
                family.append({
                    "id": child.id,
                    "nickname": child.nickname,
                    "relation": b.relation_label,
                    "role": "child",
                })
    else:
        bindings = db.query(FamilyBinding).filter(
            FamilyBinding.child_id == user.id,
            FamilyBinding.is_active == True,
        ).all()
        for b in bindings:
            elder = db.query(User).filter(User.id == b.elder_id).first()
            if elder:
                family.append({
                    "id": elder.id,
                    "nickname": elder.nickname,
                    "relation": b.relation_label,
                    "role": "elder",
                    "total_points": elder.total_points,
                    "current_streak": elder.current_streak,
                })

    return UserInfoResponse(
        id=user.id,
        nickname=user.nickname,
        avatar_url=user.avatar_url or "",
        role=user.role.value,
        phone=user.phone,
        voice_preference=user.voice_preference if user.role == UserRole.ELDER else None,
        font_scale=user.font_scale if user.role == UserRole.ELDER else None,
        total_points=user.total_points if user.role == UserRole.ELDER else None,
        current_streak=user.current_streak if user.role == UserRole.ELDER else None,
        family_members=family,
    )


@router.put("/profile")
def update_profile(
    nickname: Optional[str] = Query(None),
    avatar_url: Optional[str] = Query(None),
    voice_preference: Optional[str] = Query(None),
    font_scale: Optional[int] = Query(None),
    token: str = Query(...),
    db: Session = Depends(get_db),
):
    """更新用户资料"""
    user = get_current_user(token, db)
    if nickname is not None:
        user.nickname = nickname
    if avatar_url is not None:
        user.avatar_url = avatar_url
    if voice_preference is not None and user.role == UserRole.ELDER:
        user.voice_preference = voice_preference
    if font_scale is not None and user.role == UserRole.ELDER:
        user.font_scale = font_scale
    db.commit()
    return {"message": "更新成功"}
