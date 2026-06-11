"""BFF entrypoint — uvicorn target (main:app)."""
from app import create_app

app = create_app()
