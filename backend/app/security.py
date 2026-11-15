"""Password hashing and login tokens."""
import base64
import hashlib
import hmac
import os
import time

import jwt

TOKEN_DAYS = 180
PBKDF2_ROUNDS = 240_000


def hash_password(password: str) -> str:
    salt = os.urandom(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, PBKDF2_ROUNDS)
    return "pbkdf2$%d$%s$%s" % (PBKDF2_ROUNDS, base64.b64encode(salt).decode(), base64.b64encode(digest).decode())


def verify_password(password: str, stored: str) -> bool:
    try:
        _, rounds, salt_b64, digest_b64 = stored.split("$")
        digest = hashlib.pbkdf2_hmac("sha256", password.encode(), base64.b64decode(salt_b64), int(rounds))
        return hmac.compare_digest(digest, base64.b64decode(digest_b64))
    except Exception:
        return False


def make_token(secret: str, player_id: str, token_version: int) -> str:
    now = int(time.time())
    return jwt.encode({"sub": player_id, "ver": token_version, "iat": now, "exp": now + TOKEN_DAYS * 86400},
                      secret, algorithm="HS256")


def read_token(secret: str, token: str) -> dict:
    """Returns the payload or raises jwt.PyJWTError."""
    return jwt.decode(token, secret, algorithms=["HS256"])


def csrf_token(secret: str, user: str) -> str:
    return hmac.new(secret.encode(), ("csrf:" + user).encode(), hashlib.sha256).hexdigest()
