"""Local server for end-to-end tests of the GAME against the real API.
Uses real missions exported from the engine instead of a Godot binary.
    python3 tests/e2e_server.py [port] [allowed_origin]
"""
import os
import sys

import uvicorn

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from conftest import FixtureGenerator  # noqa: E402
from app import generator  # noqa: E402
from app.config import Settings  # noqa: E402
from app.main import create_app  # noqa: E402

port = int(sys.argv[1]) if len(sys.argv) > 1 else 8792
origin = sys.argv[2] if len(sys.argv) > 2 else "http://127.0.0.1:8377"
generator.set_generator(FixtureGenerator())
app = create_app(Settings(database_url="sqlite:///:memory:", secret_key="e2e-secret-key-long-enough-0123456789",
                          admin_user="owner", admin_password="owner-pass", cors_origins=[origin]))
uvicorn.run(app, host="127.0.0.1", port=port, log_level="warning")
