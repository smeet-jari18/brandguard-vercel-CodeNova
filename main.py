"""ASGI entrypoint for Vercel. Flutter assets are published separately on its CDN."""
import os
import sys
from pathlib import Path

backend = Path(__file__).resolve().parent / 'backend'
sys.path.insert(0, str(backend))
os.chdir(backend)  # libpq resolves the bundled CA path relative to cwd.
os.environ.setdefault('BRANDGUARD_DATA_DIR', '/tmp/brandguard')
os.environ.setdefault('SEED_DEMO_USERS', 'false')
from app import config

if config.AUTH_PROVIDER != 'supabase' or config.SEED_DEMO_USERS:
    raise RuntimeError('Set AUTH_PROVIDER=supabase and SEED_DEMO_USERS=false on Vercel.')
if not config.DATABASE_URL.startswith(('postgresql://', 'postgres://', 'postgresql+psycopg://')):
    raise RuntimeError('A PostgreSQL DATABASE_URL is required on Vercel.')
from app.main import app  # noqa: E402,F401
