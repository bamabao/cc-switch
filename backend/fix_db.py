from sqlalchemy import create_engine, text
from app.core.config import get_settings
import sys
sys.path.insert(0, '.')

settings = get_settings()
engine = create_engine(settings.database_url)

with engine.connect() as conn:
    result = conn.execute(text('PRAGMA table_info(users)')).fetchall()
    cols = [r[1] for r in result]
    print('Current columns:', cols)

    if 'self_audit' not in cols:
        conn.execute(text('ALTER TABLE users ADD COLUMN self_audit BOOLEAN DEFAULT 0'))
        conn.commit()
        print('Added self_audit column - OK')
    else:
        print('self_audit column already exists - OK')
