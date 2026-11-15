import json
import os
import sys

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app import generator  # noqa: E402
from app.config import Settings  # noqa: E402
from app.main import create_app  # noqa: E402

FIXTURES = json.load(open(os.path.join(os.path.dirname(__file__), "fixtures", "missions.json"), encoding="utf-8"))


class FixtureGenerator:
    """Stands in for Godot: serves REAL missions that the game's generator produced
    (tests/fixtures/missions.json was exported from the engine), re-labelled with the requested seeds."""

    def __init__(self):
        self.calls = 0
        self.fail = False
        self.cursor = {}

    def generate(self, seeds, difficulty):
        self.calls += 1
        if self.fail:
            raise generator.GeneratorError("simulated failure")
        pool = [m for m in FIXTURES if m["difficulty"] == difficulty]
        out = []
        for seed in seeds:
            i = self.cursor.get(difficulty, 0)
            self.cursor[difficulty] = i + 1
            mission = json.loads(json.dumps(pool[i % len(pool)]))
            mission["seed"] = seed
            mission["id"] = "mb-%d-%d-%d" % (mission["generator_version"], difficulty, seed)
            if i >= len(pool):
                mission["signature"] = "%s-%d" % (mission["signature"], i)
            out.append(mission)
        return out


@pytest.fixture()
def gen():
    g = FixtureGenerator()
    generator.set_generator(g)
    yield g
    generator.set_generator(None)


@pytest.fixture()
def client(gen):
    # Set TEST_DATABASE_URL to run the same tests against PostgreSQL (tables are dropped first).
    url = os.getenv("TEST_DATABASE_URL", "sqlite:///:memory:")
    if not url.startswith("sqlite"):
        from app import db as app_db, models  # noqa: F401
        app_db.configure(url)
        app_db.Base.metadata.drop_all(app_db.engine())
    settings = Settings(database_url=url, secret_key="test-secret-key-that-is-long-enough-123",
                        admin_user="owner", admin_password="owner-pass")
    with TestClient(create_app(settings)) as c:
        yield c


def guest(client):
    r = client.post("/v1/auth/guest")
    assert r.status_code == 200
    return {"Authorization": "Bearer " + r.json()["token"]}
