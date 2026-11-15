"""Scheduled generation job.

    python -m app.worker            # one pass: daily (today + tomorrow), weekly set, pool top-up
    python -m app.worker --migrate  # create tables only

Run it from cron or a systemd timer, e.g. every 30 minutes.
"""
import sys

from . import db, generator, services
from .config import load_settings


def main() -> int:
    settings = load_settings()
    db.configure(settings.database_url)
    db.init_db()
    if "--migrate" in sys.argv:
        print("tables ready")
        return 0
    generator.set_generator(generator.GodotGenerator(settings.godot_bin, settings.game_project_dir))
    session = db.new_session()
    try:
        summary = services.run_once(session)
    finally:
        session.close()
    print("generation pass:", summary)
    return 0


if __name__ == "__main__":
    sys.exit(main())
