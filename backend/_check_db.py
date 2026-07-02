from app.database import SessionLocal
from sqlalchemy import text
db = SessionLocal()
tables = db.execute(text("SELECT name FROM sqlite_master WHERE type='table' AND name!='alembic_version'")).fetchall()
print("Tables:", [t[0] for t in tables])
for t in tables:
    name = t[0]
    cnt = db.execute(text(f"SELECT COUNT(*) FROM [{name}]")).scalar()
    print(f"  {name}: {cnt} rows")
db.close()
