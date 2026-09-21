#!/usr/bin/env python3
"""Ruki local dev backend (M2 stand-in for Supabase, see MEMORY D43).

Stdlib only: `python3 server/ruki_server.py` -> http://0.0.0.0:8080.
Data lives in server/data/ (SQLite + photo files); delete that folder to reset.

Values rules enforced HERE, not just in the app:
  - RDP-2/3: the schema has no missed-prayer, pause or location column, so
    none of them can leak. Absence produces no network event at all.
  - D6.6: prayed_at and is_late come from the SERVER clock, never the device.
  - D23: posts and their photos disappear at expires_at (purged on each request).
  - D9: a friend's post is locked (no caption, no photo keys, photo fetch refused)
    until the viewer has checked in for the same prayer.
  - D18: a circle is at most FRIEND_CAP people.
Passwords are stored only as salted scrypt hashes.
This is a dev server: no TLS, no rate limiting, token = credential.
"""
import base64
import contextlib
import hashlib
import hmac
import json
import os
import re
import secrets
import sqlite3
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

FRIEND_CAP = 5
MAX_PHOTO_BYTES = 6 * 1024 * 1024
MAX_BODY_BYTES = 16 * 1024 * 1024
PRAYERS = {"fajr", "dhuhr", "asr", "maghrib", "isha"}
USERNAME_RE = re.compile(r"^[a-z0-9_]{3,20}$")
MIN_PASSWORD_LENGTH = 8
MAX_PASSWORD_LENGTH = 128

DATA_DIR = Path(os.environ.get("RUKI_DATA", Path(__file__).parent / "data"))
PHOTO_DIR = DATA_DIR / "photos"
DB_PATH = DATA_DIR / "ruki.sqlite"

SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY, username TEXT UNIQUE NOT NULL, token TEXT UNIQUE NOT NULL, created_at REAL NOT NULL,
  password_salt BLOB, password_hash BLOB);
CREATE TABLE IF NOT EXISTS friendships (
  requester TEXT NOT NULL, addressee TEXT NOT NULL, status TEXT NOT NULL, created_at REAL NOT NULL,
  PRIMARY KEY (requester, addressee));
CREATE TABLE IF NOT EXISTS checkins (
  id TEXT PRIMARY KEY, user_id TEXT NOT NULL, prayer TEXT NOT NULL, slot_id TEXT NOT NULL,
  prayed_at REAL NOT NULL, is_late INTEGER NOT NULL, retake_count INTEGER NOT NULL, caption TEXT,
  front_key TEXT, rear_key TEXT NOT NULL, expires_at REAL NOT NULL,
  UNIQUE (user_id, slot_id));
"""


class ApiError(Exception):
    def __init__(self, status, code):
        self.status, self.code = status, code


def db():
    conn = sqlite3.connect(DB_PATH, timeout=10)
    conn.row_factory = sqlite3.Row
    return conn


@contextlib.contextmanager
def connection():
    """Commits on success, rolls back on error, and always closes."""
    conn = db()
    try:
        with conn:
            yield conn
    finally:
        conn.close()


def init_storage():
    PHOTO_DIR.mkdir(parents=True, exist_ok=True)
    with connection() as conn:
        conn.executescript(SCHEMA)
        # A dev database from before passwords existed: add the columns. Those
        # old accounts have no password, so they can no longer be logged into.
        columns = {row["name"] for row in conn.execute("PRAGMA table_info(users)")}
        if "password_hash" not in columns:
            conn.execute("ALTER TABLE users ADD COLUMN password_salt BLOB")
            conn.execute("ALTER TABLE users ADD COLUMN password_hash BLOB")


def purge_expired(conn, now):
    rows = conn.execute("SELECT front_key, rear_key FROM checkins WHERE expires_at <= ?", (now,)).fetchall()
    for row in rows:
        for key in (row["front_key"], row["rear_key"]):
            if key:
                (PHOTO_DIR / key).unlink(missing_ok=True)
    conn.execute("DELETE FROM checkins WHERE expires_at <= ?", (now,))


def accepted_count(conn, uid):
    return conn.execute(
        "SELECT COUNT(*) FROM friendships WHERE status='accepted' AND (requester=? OR addressee=?)", (uid, uid)
    ).fetchone()[0]


def are_friends(conn, a, b):
    return conn.execute(
        "SELECT 1 FROM friendships WHERE status='accepted' AND "
        "((requester=? AND addressee=?) OR (requester=? AND addressee=?))", (a, b, b, a)
    ).fetchone() is not None


def viewer_has_checked_in(conn, viewer, slot_id):
    return conn.execute(
        "SELECT 1 FROM checkins WHERE user_id=? AND slot_id=?", (viewer, slot_id)
    ).fetchone() is not None


def hash_password(password, salt):
    return hashlib.scrypt(password.encode(), salt=salt, n=2**14, r=8, p=1, dklen=32)


def user_json(row):
    return {"userID": row["id"], "username": row["username"]}


# MARK: Handlers — each returns a JSON-able dict. `body` is the parsed request body.

def register(conn, _user, body, now):
    username = str(body.get("username", "")).strip().lower()
    if not USERNAME_RE.match(username):
        raise ApiError(400, "invalid_username")
    if conn.execute("SELECT 1 FROM users WHERE username=?", (username,)).fetchone():
        raise ApiError(409, "username_taken")
    password = str(body.get("password", ""))
    if not MIN_PASSWORD_LENGTH <= len(password) <= MAX_PASSWORD_LENGTH:
        raise ApiError(400, "weak_password")
    uid, token, salt = str(uuid.uuid4()), secrets.token_urlsafe(24), secrets.token_bytes(16)
    conn.execute("INSERT INTO users (id, username, token, created_at, password_salt, password_hash) VALUES (?,?,?,?,?,?)",
                 (uid, username, token, now, salt, hash_password(password, salt)))
    return {"userID": uid, "username": username, "token": token}


def login(conn, _user, body, _now):
    row = conn.execute("SELECT * FROM users WHERE username=?", (str(body.get("username", "")).strip().lower(),)).fetchone()
    password = str(body.get("password", ""))[:MAX_PASSWORD_LENGTH]
    # Same answer and same work whether the username or the password is wrong,
    # so a caller can't use login to learn which usernames exist.
    salt = row["password_salt"] if row and row["password_salt"] else b"\0" * 16
    candidate = hash_password(password, salt)
    stored = row["password_hash"] if row and row["password_hash"] else None
    if stored is None or not hmac.compare_digest(candidate, stored):
        raise ApiError(401, "invalid_credentials")
    # One token per account, so a phone and a simulator can be logged in at once.
    return {"userID": row["id"], "username": row["username"], "token": row["token"]}


def list_friends(conn, user, _body, _now):
    def users_where(sql, arg):
        return [user_json(r) for r in conn.execute(sql, (arg,)).fetchall()]

    return {
        "cap": FRIEND_CAP,
        "friends": users_where(
            "SELECT u.* FROM users u JOIN friendships f ON f.status='accepted' AND "
            "((f.requester=u.id AND f.addressee=?1) OR (f.addressee=u.id AND f.requester=?1)) ORDER BY u.username",
            user["id"]),
        "incoming": users_where(
            "SELECT u.* FROM users u JOIN friendships f ON f.requester=u.id AND f.addressee=? AND f.status='pending'",
            user["id"]),
        "outgoing": users_where(
            "SELECT u.* FROM users u JOIN friendships f ON f.addressee=u.id AND f.requester=? AND f.status='pending'",
            user["id"]),
    }


def _accept(conn, requester_id, addressee_id, now):
    if accepted_count(conn, addressee_id) >= FRIEND_CAP:
        raise ApiError(409, "circle_full")
    if accepted_count(conn, requester_id) >= FRIEND_CAP:
        raise ApiError(409, "their_circle_full")
    conn.execute("UPDATE friendships SET status='accepted', created_at=? WHERE requester=? AND addressee=?",
                 (now, requester_id, addressee_id))


def request_friend(conn, user, body, now):
    target = conn.execute("SELECT * FROM users WHERE username=?",
                          (str(body.get("username", "")).strip().lower(),)).fetchone()
    if target is None:
        raise ApiError(404, "no_such_user")
    if target["id"] == user["id"]:
        raise ApiError(400, "cannot_add_self")
    if are_friends(conn, user["id"], target["id"]):
        return {"status": "already_friends"}
    if conn.execute("SELECT 1 FROM friendships WHERE requester=? AND addressee=?",
                    (target["id"], user["id"])).fetchone():
        _accept(conn, target["id"], user["id"], now)  # they already asked: mutual, so accept
        return {"status": "accepted"}
    if accepted_count(conn, user["id"]) >= FRIEND_CAP:
        raise ApiError(409, "circle_full")
    conn.execute("INSERT OR IGNORE INTO friendships VALUES (?,?,'pending',?)", (user["id"], target["id"], now))
    return {"status": "pending"}


def accept_friend(conn, user, body, now):
    row = conn.execute("SELECT 1 FROM friendships WHERE requester=? AND addressee=? AND status='pending'",
                       (str(body.get("userID", "")), user["id"])).fetchone()
    if row is None:
        raise ApiError(404, "no_such_request")
    _accept(conn, str(body["userID"]), user["id"], now)
    return {"status": "accepted"}


def remove_friend(conn, user, body, _now):
    other = str(body.get("userID", ""))  # decline, cancel and unfriend are the same operation
    conn.execute("DELETE FROM friendships WHERE (requester=? AND addressee=?) OR (requester=? AND addressee=?)",
                 (user["id"], other, other, user["id"]))
    return {"status": "removed"}


def _store_photo(encoded):
    try:
        data = base64.b64decode(encoded, validate=True)
    except Exception:
        raise ApiError(400, "bad_photo")
    if not data or len(data) > MAX_PHOTO_BYTES:
        raise ApiError(400, "bad_photo")
    key = f"{uuid.uuid4()}.jpg"
    (PHOTO_DIR / key).write_bytes(data)
    return key


def post_checkin(conn, user, body, now):
    prayer = body.get("prayer")
    try:
        slot_id, on_time_until = str(body["slotID"]), float(body["onTimeUntil"])
        expires_at, retakes = float(body["expiresAt"]), int(body.get("retakeCount", 0))
    except (KeyError, TypeError, ValueError):
        raise ApiError(400, "bad_request")
    # slotID is "<yyyy-MM-dd>.<prayer>": one post per prayer per day, and the key friends unlock each other by.
    if prayer not in PRAYERS or not re.fullmatch(r"\d{4}-\d{2}-\d{2}\." + str(prayer), slot_id) or not body.get("rearPhoto"):
        raise ApiError(400, "bad_request")
    if expires_at <= now:
        raise ApiError(410, "expired")
    if conn.execute("SELECT 1 FROM checkins WHERE user_id=? AND slot_id=?", (user["id"], slot_id)).fetchone():
        raise ApiError(409, "already_posted")
    caption = (str(body["caption"]).strip()[:80] or None) if body.get("caption") else None
    rear = _store_photo(body["rearPhoto"])
    front = _store_photo(body["frontPhoto"]) if body.get("frontPhoto") else None
    conn.execute("INSERT INTO checkins VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                 (str(uuid.uuid4()), user["id"], prayer, slot_id, now, int(now > on_time_until),
                  max(0, min(retakes, 1)), caption, front, rear, expires_at))
    return {"status": "posted"}


def feed(conn, user, _body, now):
    rows = conn.execute(
        "SELECT c.*, u.username FROM checkins c JOIN users u ON u.id=c.user_id "
        "WHERE c.user_id != ?1 AND c.expires_at > ?2 AND EXISTS (SELECT 1 FROM friendships f WHERE f.status='accepted' "
        "AND ((f.requester=?1 AND f.addressee=c.user_id) OR (f.addressee=?1 AND f.requester=c.user_id))) "
        "ORDER BY c.prayed_at DESC", (user["id"], now)).fetchall()
    posts = []
    for r in rows:
        locked = not viewer_has_checked_in(conn, user["id"], r["slot_id"])
        post = {"id": r["id"], "username": r["username"], "prayer": r["prayer"], "prayedAt": r["prayed_at"],
                "isLate": bool(r["is_late"]), "expiresAt": r["expires_at"], "locked": locked}
        if not locked:
            post.update({"caption": r["caption"], "frontPhotoKey": r["front_key"], "rearPhotoKey": r["rear_key"]})
        posts.append(post)
    return {"posts": posts}


def delete_account(conn, user, _body, _now):
    for row in conn.execute("SELECT front_key, rear_key FROM checkins WHERE user_id=?", (user["id"],)).fetchall():
        for key in (row["front_key"], row["rear_key"]):
            if key:
                (PHOTO_DIR / key).unlink(missing_ok=True)
    conn.execute("DELETE FROM checkins WHERE user_id=?", (user["id"],))
    conn.execute("DELETE FROM friendships WHERE requester=? OR addressee=?", (user["id"], user["id"]))
    conn.execute("DELETE FROM users WHERE id=?", (user["id"],))
    return {"status": "deleted"}


ROUTES = {
    ("POST", "/register"): (register, False),
    ("POST", "/login"): (login, False),
    ("GET", "/friends"): (list_friends, True),
    ("POST", "/friends/request"): (request_friend, True),
    ("POST", "/friends/accept"): (accept_friend, True),
    ("POST", "/friends/remove"): (remove_friend, True),
    ("POST", "/checkins"): (post_checkin, True),
    ("GET", "/feed"): (feed, True),
    ("POST", "/account/delete"): (delete_account, True),
}


class Handler(BaseHTTPRequestHandler):
    def _send(self, status, payload=None, raw=None, content_type="application/json"):
        body = raw if raw is not None else json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _authenticate(self, conn, query):
        header = self.headers.get("Authorization", "")
        token = header[7:] if header.startswith("Bearer ") else (query.get("token") or [""])[0]
        user = conn.execute("SELECT * FROM users WHERE token=?", (token,)).fetchone() if token else None
        if user is None:
            raise ApiError(401, "unauthorized")
        return user

    def _dispatch(self, method):
        url = urlparse(self.path)
        query = parse_qs(url.query)
        now = time.time()  # the one authoritative clock (D6.6)
        try:
            length = int(self.headers.get("Content-Length") or 0)
            if length > MAX_BODY_BYTES:
                raise ApiError(413, "too_large")
            try:
                body = json.loads(self.rfile.read(length) or b"{}") if method == "POST" else {}
            except ValueError:
                raise ApiError(400, "bad_json")
            with connection() as conn:
                purge_expired(conn, now)
                if method == "GET" and url.path.startswith("/photos/"):
                    return self._photo(conn, self._authenticate(conn, query), url.path[len("/photos/"):], now)
                route = ROUTES.get((method, url.path))
                if route is None:
                    raise ApiError(404, "not_found")
                handler, needs_auth = route
                user = self._authenticate(conn, query) if needs_auth else None
                self._send(200, handler(conn, user, body, now))
        except ApiError as error:
            self._send(error.status, {"error": error.code})
        except Exception as error:  # never leak internals to the client
            print("server error:", repr(error))
            self._send(500, {"error": "server_error"})

    def _photo(self, conn, viewer, key, now):
        row = conn.execute("SELECT * FROM checkins WHERE front_key=?1 OR rear_key=?1", (key,)).fetchone()
        if row is None or not re.fullmatch(r"[0-9a-f-]{36}\.jpg", key):
            raise ApiError(404, "not_found")
        allowed = row["user_id"] == viewer["id"] or (
            are_friends(conn, viewer["id"], row["user_id"])
            and viewer_has_checked_in(conn, viewer["id"], row["slot_id"]))
        if not allowed:
            raise ApiError(403, "locked")
        self._send(200, raw=(PHOTO_DIR / key).read_bytes(), content_type="image/jpeg")

    def do_GET(self):
        self._dispatch("GET")

    def do_POST(self):
        self._dispatch("POST")

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} {fmt % args}")


if __name__ == "__main__":
    init_storage()
    port = int(os.environ.get("PORT", "8080"))
    print(f"Ruki dev server on http://0.0.0.0:{port}  (data: {DATA_DIR})")
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
