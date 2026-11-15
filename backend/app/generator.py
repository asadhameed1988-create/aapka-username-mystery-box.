"""Mission generation backend.

The server never re-implements puzzle logic. It runs the game's own GDScript generator
through Godot in headless mode, so phone and server always agree:

    godot --headless --path <project> -s res://tools/server_generate.gd -- <out> <difficulty> <seeds...>
"""
import json
import os
import subprocess
import tempfile


class GeneratorError(Exception):
    pass


class GodotGenerator:
    def __init__(self, godot_bin: str, project_dir: str, timeout: int = 120):
        self.godot_bin = godot_bin
        self.project_dir = project_dir
        self.timeout = timeout

    def generate(self, seeds: list, difficulty: int) -> list:
        fd, out_path = tempfile.mkstemp(suffix=".json", prefix="mb_gen_")
        os.close(fd)
        cmd = [self.godot_bin, "--headless", "--path", self.project_dir, "-s", "res://tools/server_generate.gd",
               "--", out_path, str(int(difficulty))] + [str(int(s)) for s in seeds]
        try:
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=self.timeout)
            if proc.returncode != 0:
                raise GeneratorError("godot exit %d: %s" % (proc.returncode, (proc.stderr or proc.stdout)[-400:]))
            with open(out_path, "r", encoding="utf-8") as f:
                missions = json.load(f)
            if not isinstance(missions, list):
                raise GeneratorError("generator output is not a list")
            return missions
        except FileNotFoundError as e:
            raise GeneratorError("godot binary not found: %s" % e)
        except subprocess.TimeoutExpired:
            raise GeneratorError("godot timed out after %ds" % self.timeout)
        except json.JSONDecodeError as e:
            raise GeneratorError("bad generator output: %s" % e)
        finally:
            try:
                os.remove(out_path)
            except OSError:
                pass


_generator = None


def set_generator(gen) -> None:
    global _generator
    _generator = gen


def get_generator():
    return _generator
