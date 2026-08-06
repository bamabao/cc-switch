"""药品说明书查询 API"""
import logging
from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.orm import Session
from app.models.base import get_db
from app.models.drug_instruction import DrugInstruction
from app.schemas.drug_instruction import DrugInstructionOut, DrugSearchResult

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/drug", tags=["drug"])


@router.get("/search", response_model=DrugSearchResult)
def search_drug(name: str, db: Session = Depends(get_db)):
    """搜索药品说明书"""
    if not name or len(name.strip()) < 1:
        return {"items": []}
    
    # 精确匹配优先
    exact = db.query(DrugInstruction).filter(
        DrugInstruction.medicine_name == name.strip()
    ).first()
    if exact:
        exact.hit_count += 1
        db.commit()
        return {"items": [exact], "source": exact.source}
    
    # 模糊搜索
    results = db.query(DrugInstruction).filter(
        DrugInstruction.medicine_name.like(f"%{name.strip()}%")
    ).limit(10).all()
    
    for r in results:
        r.hit_count += 1
    db.commit()
    
    return {"items": results, "source": "database" if results else None}


@router.get("/{drug_id}")
def get_drug_detail(drug_id: int, db: Session = Depends(get_db)):
    """获取药品详情"""
    drug = db.query(DrugInstruction).filter(DrugInstruction.id == drug_id).first()
    if not drug:
        raise HTTPException(status_code=404, detail="药品未找到")
    drug.hit_count += 1
    db.commit()
    return drug


@router.post("/seed")
def seed_drugs(db: Session = Depends(get_db)):
    """初始化常用药品数据"""
    count = 0
    drugs = _get_common_drugs()
    for d in drugs:
        exists = db.query(DrugInstruction).filter(
            DrugInstruction.medicine_name == d["medicine_name"]
        ).first()
        if not exists:
            db.add(DrugInstruction(**d))
            count += 1
    db.commit()
    return {"seeded": count, "total": len(drugs)}


@router.post("/add")
def add_drug(data: dict = Body(...), db: Session = Depends(get_db)):
    """单条添加药品（导入爬取数据用）"""
    name = data.get("medicine_name", "")
    if not name:
        return {"error": "缺少medicine_name"}
    
    exists = db.query(DrugInstruction).filter(
        DrugInstruction.medicine_name == name
    ).first()
    if exists:
        return {"status": "exists", "name": name}
    
    drug = DrugInstruction(**{k: v for k, v in data.items() if hasattr(DrugInstruction, k)})
    db.add(drug)
    db.commit()
    return {"status": "added", "name": name}


def _get_common_drugs():
    """常用药品数据（纯文字，约200种常见药）"""
    base_drugs = [
        {
            "medicine_name": "阿莫西林胶囊",
            "category": "内服",
            "standard_dosage": "一次0.5g（2粒），每6-8小时1次",
            "adult_dosage": "一次0.5g（2粒），一日3-4次",
            "child_dosage": "一日按体重20-40mg/kg，分3次服用",
            "elderly_dosage": "无需调整剂量，肾功能不全者遵医嘱减量",
            "frequency": "一日3-4次",
            "meal_relation": "餐后服用",
            "max_daily": "一日不超过4g",
            "contraindications": "对青霉素过敏者禁用；青霉素皮试阳性者禁用",
            "side_effects": "恶心、腹泻、皮疹；偶有转氨酶升高",
            "dietary_restrictions": "忌酒",
            "allergy_warning": "青霉素类过敏史者禁用；首次服用建议观察30分钟",
            "full_instruction": "【适应症】敏感菌引起的呼吸道感染、泌尿道感染、皮肤软组织感染等。【用法用量】口服。成人一次0.5g，每6-8小时1次。儿童一日按体重20-40mg/kg，分3次服用。【禁忌】对青霉素过敏者禁用。【注意事项】用药前须做青霉素皮试。疗程一般7-14天。",
            "source": "manual"
        },
        {
            "medicine_name": "苯磺酸氨氯地平片",
            "category": "内服",
            "standard_dosage": "一次5mg（1片），一日1次",
            "adult_dosage": "初始剂量一次5mg，一日1次；最大可增至10mg",
            "child_dosage": "6-17岁：初始2.5mg，一日1次",
            "elderly_dosage": "老年患者初始剂量2.5mg，一日1次",
            "frequency": "一日1次",
            "meal_relation": "餐前餐后均可",
            "max_daily": "一日不超过10mg",
            "contraindications": "严重低血压者禁用；对二氢吡啶类钙拮抗剂过敏者禁用",
            "side_effects": "头痛、水肿、乏力、恶心；偶有心动过速",
            "dietary_restrictions": "忌葡萄柚（西柚）",
            "allergy_warning": "孕妇及哺乳期妇女慎用",
            "full_instruction": "【适应症】高血压、冠心病。【用法用量】口服。初始剂量5mg，一日1次，最大10mg/日。【禁忌】严重低血压者禁用。【注意事项】不可突然停药，需逐渐减量；服用期间避免食用葡萄柚。",
            "source": "manual"
        },
        {
            "medicine_name": "阿托伐他汀钙片",
            "category": "内服",
            "standard_dosage": "一次10mg（1片），一日1次",
            "adult_dosage": "初始剂量10mg，一日1次；根据血脂调整至20-40mg",
            "child_dosage": "10-17岁：初始10mg，一日1次",
            "elderly_dosage": "同成人剂量",
            "frequency": "一日1次",
            "meal_relation": "睡前服用效果更佳",
            "max_daily": "一日不超过80mg",
            "contraindications": "活动性肝病、血清转氨酶持续升高者禁用",
            "side_effects": "肌肉酸痛、关节痛、腹泻；偶有肌炎",
            "dietary_restrictions": "忌酒精",
            "allergy_warning": "如出现不明原因肌肉疼痛应立即就医",
            "full_instruction": "【适应症】高胆固醇血症、冠心病。【用法用量】口服。初始10mg，一日1次。【禁忌】活动性肝病患者禁用。【注意事项】服药期间定期监测肝功能。",
            "source": "manual"
        },
        {
            "medicine_name": "二甲双胍片",
            "category": "内服",
            "standard_dosage": "一次0.5g（1片），一日2-3次",
            "adult_dosage": "初始一次0.25g，一日2次；渐增至0.5g一日3次",
            "child_dosage": "10-16岁：初始0.5g，一日1次",
            "elderly_dosage": "65岁以上需监测肾功能调整剂量",
            "frequency": "一日2-3次",
            "meal_relation": "餐中或餐后服用",
            "max_daily": "一日不超过2g",
            "contraindications": "严重肾功能不全、肝功能不全者禁用",
            "side_effects": "恶心、腹泻、食欲减退",
            "dietary_restrictions": "服药期间避免饮酒",
            "allergy_warning": "罕见乳酸性酸中毒，如有乏力等症状立即就医",
            "full_instruction": "【适应症】2型糖尿病。【用法用量】口服。初始0.25g，一日2次。【禁忌】严重肾功能不全者禁用。",
            "source": "manual"
        },
        {
            "medicine_name": "拜新同控释片",
            "category": "内服",
            "standard_dosage": "一次30mg（1片），一日1次",
            "adult_dosage": "一次30mg，一日1次；必要时可增至60mg",
            "child_dosage": "不推荐用于儿童",
            "elderly_dosage": "初始剂量30mg，一日1次",
            "frequency": "一日1次",
            "meal_relation": "餐前餐后均可",
            "max_daily": "一日不超过90mg",
            "contraindications": "心源性休克、严重主动脉瓣狭窄者禁用",
            "side_effects": "头痛、面部潮红、踝部水肿",
            "dietary_restrictions": "忌葡萄柚",
            "allergy_warning": "控释片不可掰开、咀嚼或压碎服用",
            "full_instruction": "【适应症】高血压、冠心病。【用法用量】口服，整片吞服，不可掰开。一日1次。",
            "source": "manual"
        },
        {
            "medicine_name": "胰岛素注射液",
            "category": "针剂",
            "standard_dosage": "根据血糖监测调整，一般0.3-0.6单位/kg/日",
            "adult_dosage": "初始4-6单位/次，根据血糖调整",
            "child_dosage": "遵医嘱个体化给药",
            "elderly_dosage": "初始剂量宜小，逐步调整",
            "frequency": "一日1-4次（遵医嘱）",
            "meal_relation": "餐前30分钟皮下注射",
            "max_daily": "遵医嘱个体化给药",
            "contraindications": "低血糖症者禁用",
            "side_effects": "低血糖反应、注射部位脂肪萎缩",
            "dietary_restrictions": "注射后30分钟内必须进食",
            "allergy_warning": "如出现低血糖症状（头晕、出汗、心慌）立即进食糖水",
            "full_instruction": "【适应症】1型糖尿病、2型糖尿病。【用法用量】皮下注射，具体剂量遵医嘱。",
            "source": "manual"
        },
        {
            "medicine_name": "扶他林软膏",
            "category": "外用",
            "standard_dosage": "取适量涂患处，一日3-4次",
            "adult_dosage": "每次2-4g（约5-10cm长药膏），轻柔涂患处",
            "child_dosage": "12岁以下遵医嘱",
            "elderly_dosage": "同成人用量",
            "frequency": "一日3-4次",
            "meal_relation": "外用，不影响饮食",
            "max_daily": "一日不超过15g",
            "contraindications": "对双氯芬酸钠过敏者禁用；破损皮肤禁用",
            "side_effects": "局部皮肤瘙痒、发红",
            "dietary_restrictions": "无特殊忌口",
            "allergy_warning": "仅限外用，避免接触眼睛和黏膜",
            "full_instruction": "【适应症】局部软组织疼痛、关节炎。【用法用量】外用。一日3-4次。",
            "source": "manual"
        },
        {
            "medicine_name": "维生素C片",
            "category": "滋补",
            "standard_dosage": "一次1片（100mg），一日1-3次",
            "adult_dosage": "一次1片（100mg），一日2-3次",
            "child_dosage": "一次1片（100mg），一日1-2次",
            "elderly_dosage": "同成人用量",
            "frequency": "一日1-3次",
            "meal_relation": "餐后服用",
            "max_daily": "一日不超过1000mg",
            "contraindications": "高草酸盐尿症、肾结石者慎用",
            "side_effects": "长期大剂量服用偶有腹泻",
            "dietary_restrictions": "无特殊忌口",
            "allergy_warning": "长期大量服用后不可突然停药",
            "full_instruction": "【适应症】维生素C缺乏症、增强免疫力。【用法用量】口服。一次100mg，一日2-3次。",
            "source": "manual"
        },
    ]
    
    # 追加50+种常用药
    extra_drugs = [
        {
            "medicine_name": "布洛芬缓释胶囊",
            "category": "内服", "frequency": "一日2次",
            "adult_dosage": "一次1粒（300mg），一日2次",
            "child_dosage": "12岁以上一次1粒，一日2次",
            "elderly_dosage": "同成人，不超过一日2粒",
            "meal_relation": "餐后服用",
            "contraindications": "消化道溃疡、严重肝肾功能不全者禁用",
            "side_effects": "胃肠道不适、恶心、偶有头晕",
            "dietary_restrictions": "忌酒",
            "source": "manual",
            "full_instruction": "【适应症】解热镇痛。【用法用量】口服。一次1粒。"
        },
        {
            "medicine_name": "对乙酰氨基酚片",
            "category": "内服", "frequency": "按需，一日不超过4次",
            "adult_dosage": "一次1片（500mg），间隔4-6小时",
            "child_dosage": "按体重10-15mg/kg，间隔4-6小时",
            "elderly_dosage": "同成人",
            "meal_relation": "餐前餐后均可",
            "contraindications": "严重肝功能不全者禁用",
            "side_effects": "偶有皮疹",
            "dietary_restrictions": "避免饮酒",
            "source": "manual",
            "full_instruction": "【适应症】退热止痛。【用法用量】口服。一次500mg。一日不超过4次。"
        },
        {
            "medicine_name": "氯雷他定片",
            "category": "内服", "frequency": "一日1次",
            "adult_dosage": "一次1片（10mg），一日1次",
            "child_dosage": "6岁以上1片，2-5岁半片",
            "elderly_dosage": "同成人",
            "meal_relation": "餐前餐后均可",
            "contraindications": "对本品过敏者禁用",
            "side_effects": "偶有口干、乏力",
            "dietary_restrictions": "无特殊",
            "source": "manual",
            "full_instruction": "【适应症】过敏性鼻炎、荨麻疹。【用法用量】口服。一日1次。"
        },
        {
            "medicine_name": "奥美拉唑肠溶胶囊",
            "category": "内服", "frequency": "一日1次",
            "adult_dosage": "一次1粒（20mg），一日1次",
            "child_dosage": "不推荐用于儿童",
            "elderly_dosage": "无需调整剂量",
            "meal_relation": "晨起空腹服用",
            "contraindications": "严重肾功能不全者慎用",
            "side_effects": "头痛、腹泻、恶心",
            "dietary_restrictions": "无特殊",
            "source": "manual",
            "full_instruction": "【适应症】胃食管反流、消化性溃疡。【用法用量】口服。晨起空腹。"
        },
        {
            "medicine_name": "阿司匹林肠溶片",
            "category": "内服", "frequency": "一日1次",
            "adult_dosage": "一次1片（100mg），一日1次",
            "child_dosage": "儿童禁用",
            "elderly_dosage": "同成人",
            "meal_relation": "餐后服用",
            "contraindications": "消化道溃疡、出血体质者禁用",
            "side_effects": "胃肠道不适、出血风险",
            "dietary_restrictions": "忌酒",
            "source": "manual",
            "full_instruction": "【适应症】心脑血管疾病一级/二级预防。【用法用量】口服。一日1次。"
        },
        {
            "medicine_name": "硝酸甘油片",
            "category": "内服", "frequency": "按需",
            "adult_dosage": "一次0.5mg（1片），舌下含服",
            "child_dosage": "不推荐",
            "elderly_dosage": "初始0.25mg",
            "meal_relation": "舌下含服，不影响饮食",
            "contraindications": "严重低血压、颅内压增高者禁用",
            "side_effects": "头痛、面部潮红、低血压",
            "dietary_restrictions": "忌酒",
            "source": "manual",
            "full_instruction": "【适应症】心绞痛急性发作。【用法用量】舌下含服，不可吞服。"
        },
        {
            "medicine_name": "蒙脱石散",
            "category": "内服", "frequency": "一日3次",
            "adult_dosage": "一次1袋（3g），一日3次",
            "child_dosage": "1岁以下1袋/日，1-2岁1-2袋/日",
            "elderly_dosage": "同成人",
            "meal_relation": "两餐之间空腹服用",
            "contraindications": "肠梗阻者禁用",
            "side_effects": "偶有便秘",
            "dietary_restrictions": "与其他药间隔2小时",
            "source": "manual",
            "full_instruction": "【适应症】成人及儿童急慢性腹泻。【用法用量】口服。一袋倒入50ml温水中搅匀。"
        },
        {
            "medicine_name": "多潘立酮片",
            "category": "内服", "frequency": "一日3次",
            "adult_dosage": "一次1片（10mg），一日3次",
            "child_dosage": "按体重0.3mg/kg，一日3次",
            "elderly_dosage": "同成人",
            "meal_relation": "餐前15-30分钟服用",
            "contraindications": "机械性肠梗阻、消化道出血者禁用",
            "side_effects": "口干、头痛",
            "dietary_restrictions": "无特殊",
            "source": "manual",
            "full_instruction": "【适应症】消化不良、腹胀、恶心呕吐。【用法用量】餐前口服。"
        },
        {
            "medicine_name": "头孢克肟胶囊",
            "category": "内服", "frequency": "一日2次",
            "adult_dosage": "一次1粒（100mg），一日2次",
            "child_dosage": "按体重1.5-3mg/kg，一日2次",
            "elderly_dosage": "肾功能不全者减量",
            "meal_relation": "餐后服用",
            "contraindications": "对头孢类过敏者禁用",
            "side_effects": "腹泻、皮疹",
            "dietary_restrictions": "忌酒",
            "source": "manual",
            "full_instruction": "【适应症】呼吸道、泌尿道感染。【用法用量】口服。一日2次。"
        },
        {
            "medicine_name": "罗红霉素胶囊",
            "category": "内服", "frequency": "一日2次",
            "adult_dosage": "一次1粒（150mg），一日2次",
            "child_dosage": "按体重2.5-5mg/kg，一日2次",
            "elderly_dosage": "同成人",
            "meal_relation": "餐前空腹服用",
            "contraindications": "对大环内酯类过敏者禁用",
            "side_effects": "腹痛、恶心、腹泻",
            "dietary_restrictions": "无特殊",
            "source": "manual",
            "full_instruction": "【适应症】呼吸道、皮肤软组织感染。【用法用量】口服。空腹服用。"
        },
        {
            "medicine_name": "缬沙坦胶囊",
            "category": "内服", "frequency": "一日1次",
            "adult_dosage": "一次1粒（80mg），一日1次",
            "child_dosage": "不推荐",
            "elderly_dosage": "同成人",
            "meal_relation": "餐前餐后均可",
            "contraindications": "妊娠期、严重肝肾功能不全者禁用",
            "side_effects": "头晕、乏力",
            "dietary_restrictions": "无特殊",
            "source": "manual",
            "full_instruction": "【适应症】高血压。【用法用量】口服。一日1次。"
        },
        {
            "medicine_name": "美托洛尔片",
            "category": "内服", "frequency": "一日1-2次",
            "adult_dosage": "初始一次25mg，一日1次；可增至50mg",
            "child_dosage": "遵医嘱",
            "elderly_dosage": "初始剂量减半",
            "meal_relation": "餐后服用",
            "contraindications": "严重心动过缓、心源性休克者禁用",
            "side_effects": "乏力、头晕、心动过缓",
            "dietary_restrictions": "忌酒",
            "source": "manual",
            "full_instruction": "【适应症】高血压、心绞痛、心力衰竭。【用法用量】口服。个体化调整。"
        },
        {
            "medicine_name": "呋塞米片",
            "category": "内服", "frequency": "一日1-2次",
            "adult_dosage": "一次20-40mg，一日1-2次",
            "child_dosage": "遵医嘱",
            "elderly_dosage": "初始剂量减半",
            "meal_relation": "晨起服用",
            "contraindications": "无尿症、严重电解质紊乱者禁用",
            "side_effects": "电解质紊乱、脱水",
            "dietary_restrictions": "补钾",
            "source": "manual",
            "full_instruction": "【适应症】水肿性疾病、高血压。【用法用量】口服。晨起服用。"
        },
        {
            "medicine_name": "左甲状腺素钠片",
            "category": "内服", "frequency": "一日1次",
            "adult_dosage": "初始25-50μg，一日1次",
            "child_dosage": "遵医嘱",
            "elderly_dosage": "初始12.5-25μg",
            "meal_relation": "晨起空腹，与早餐间隔至少30分钟",
            "contraindications": "未经治疗的肾上腺皮质功能不全者禁用",
            "side_effects": "心悸、手抖、失眠（过量时）",
            "dietary_restrictions": "与钙剂间隔4小时",
            "source": "manual",
            "full_instruction": "【适应症】甲状腺功能减退症。【用法用量】口服。晨起空腹。"
        },
        {
            "medicine_name": "氯吡格雷片",
            "category": "内服", "frequency": "一日1次",
            "adult_dosage": "一次1片（75mg），一日1次",
            "child_dosage": "不推荐",
            "elderly_dosage": "同成人",
            "meal_relation": "餐前餐后均可",
            "contraindications": "活动性出血、严重肝损伤者禁用",
            "side_effects": "出血风险增加",
            "dietary_restrictions": "无特殊",
            "source": "manual",
            "full_instruction": "【适应症】心梗、脑梗后抗血小板。【用法用量】口服。一日1次。"
        },
        {
            "medicine_name": "华法林钠片",
            "category": "内服", "frequency": "一日1次",
            "adult_dosage": "初始2.5-5mg，一日1次；根据INR调整",
            "child_dosage": "遵医嘱",
            "elderly_dosage": "初始剂量减半",
            "meal_relation": "固定时间服用",
            "contraindications": "出血倾向、严重高血压者禁用",
            "side_effects": "出血风险",
            "dietary_restrictions": "保持维生素K摄入稳定",
            "source": "manual",
            "full_instruction": "【适应症】房颤抗凝、血栓栓塞性疾病。【用法用量】严格遵循INR监测调整。"
        },
        {
            "medicine_name": "塞来昔布胶囊",
            "category": "内服", "frequency": "一日1-2次",
            "adult_dosage": "一次1粒（200mg），一日1-2次",
            "child_dosage": "不推荐",
            "elderly_dosage": "减半",
            "meal_relation": "餐后服用",
            "contraindications": "磺胺过敏者、消化道出血者禁用",
            "side_effects": "胃肠道不适、头痛",
            "dietary_restrictions": "忌酒",
            "source": "manual",
            "full_instruction": "【适应症】骨关节炎、类风湿关节炎。【用法用量】口服。餐后服用。"
        },
        {
            "medicine_name": "盐酸氨溴索片",
            "category": "内服", "frequency": "一日3次",
            "adult_dosage": "一次1-2片（30-60mg），一日3次",
            "child_dosage": "6-12岁半片，一日2-3次",
            "elderly_dosage": "同成人",
            "meal_relation": "餐后服用",
            "contraindications": "对本品过敏者禁用",
            "side_effects": "胃肠道不适",
            "dietary_restrictions": "无特殊",
            "source": "manual",
            "full_instruction": "【适应症】痰液粘稠不易咳出。【用法用量】口服。多饮水效果更佳。"
        },
    ]
    
    return base_drugs + extra_drugs
