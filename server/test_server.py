"""Backend rules test: `python3 server/test_server.py`. Spins the real server on a free port with a temp DB."""
import base64
import json
import os
import tempfile
import threading
import time
import unittest
import urllib.error
import urllib.request

os.environ["RUKI_DATA"] = tempfile.mkdtemp()
import ruki_server as server  # noqa: E402  (must follow the env var)

PHOTO = base64.b64encode(b"\xff\xd8fakejpeg").decode()


class ServerRules(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        server.init_storage()
        cls.httpd = server.ThreadingHTTPServer(("127.0.0.1", 0), server.Handler)
        cls.base = f"http://127.0.0.1:{cls.httpd.server_address[1]}"
        threading.Thread(target=cls.httpd.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.httpd.shutdown()

    def call(self, method, path, body=None, token=None):
        req = urllib.request.Request(self.base + path, method=method,
                                     data=json.dumps(body).encode() if body is not None else None)
        if token:
            req.add_header("Authorization", f"Bearer {token}")
        try:
            with urllib.request.urlopen(req) as resp:
                raw = resp.read()
                return resp.status, (json.loads(raw) if resp.headers["Content-Type"] == "application/json" else raw)
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read())

    def user(self, name):
        status, body = self.call("POST", "/register", {"username": name, "password": "correct horse"})
        self.assertEqual(status, 200)
        return body

    def befriend(self, a, b):
        self.call("POST", "/friends/request", {"username": b["username"]}, a["token"])
        self.assertEqual(self.call("POST", "/friends/accept", {"userID": a["userID"]}, b["token"])[0], 200)

    def checkin(self, user, late_after=None, front=True):
        now = time.time()
        return self.call("POST", "/checkins", {
            "prayer": "dhuhr", "slotID": "2026-09-19.dhuhr", "onTimeUntil": late_after or now + 1800,
            "expiresAt": now + 3600, "caption": "x" * 200, "retakeCount": 0,
            "rearPhoto": PHOTO, "frontPhoto": PHOTO if front else None}, user["token"])

    def test_circle_is_capped_at_five_on_both_sides(self):
        hub = self.user("hub_user")
        for i in range(5):
            self.befriend(hub, self.user(f"friend_{i}"))
        extra = self.user("extra_user")
        self.assertEqual(self.call("POST", "/friends/request", {"username": "hub_user"}, extra["token"])[0], 200)
        # hub is full, so the request from `extra` cannot be accepted...
        self.assertEqual(self.call("POST", "/friends/accept", {"userID": extra["userID"]}, hub["token"])[1]["error"],
                         "circle_full")
        # ...and hub cannot send a sixth either.
        self.assertEqual(self.call("POST", "/friends/request", {"username": "extra_user"}, hub["token"])[1]["error"],
                         "circle_full")
        self.assertEqual(len(self.call("GET", "/friends", token=hub["token"])[1]["friends"]), 5)

    def test_feed_is_locked_until_viewer_checks_in_and_only_for_friends(self):
        a, b, stranger = self.user("alice_t"), self.user("bilal_t"), self.user("stranger_t")
        self.befriend(a, b)
        self.assertEqual(self.checkin(a)[0], 200)
        self.assertEqual(self.checkin(a)[1]["error"], "already_posted")

        post = self.call("GET", "/feed", token=b["token"])[1]["posts"][0]
        self.assertTrue(post["locked"])
        self.assertNotIn("rearPhotoKey", post)
        self.assertNotIn("caption", post)

        self.assertEqual(self.checkin(b)[0], 200)  # same prayer + promptedAt unlocks
        post = self.call("GET", "/feed", token=b["token"])[1]["posts"][0]
        self.assertFalse(post["locked"])
        self.assertEqual(len(post["caption"]), 80)
        self.assertEqual(self.call("GET", f"/photos/{post['rearPhotoKey']}", token=b["token"])[0], 200)

        self.assertEqual(self.call("GET", "/feed", token=stranger["token"])[1]["posts"], [])
        self.assertEqual(self.call("GET", f"/photos/{post['rearPhotoKey']}", token=stranger["token"])[0], 403)
        self.assertEqual(self.call("GET", "/feed")[0], 401)

    def test_lateness_comes_from_the_server_clock(self):
        u = self.user("late_user")
        self.checkin(u, late_after=time.time() - 60)  # device claims the on-time window ended a minute ago
        c = server.db().execute("SELECT is_late FROM checkins WHERE user_id=?", (u["userID"],)).fetchone()
        self.assertEqual(c["is_late"], 1)

    def test_expired_posts_and_photos_are_purged(self):
        u = self.user("expiry_user")
        self.checkin(u)
        conn = server.db()
        keys = conn.execute("SELECT rear_key FROM checkins WHERE user_id=?", (u["userID"],)).fetchone()["rear_key"]
        conn.execute("UPDATE checkins SET expires_at=? WHERE user_id=?", (time.time() - 1, u["userID"]))
        conn.commit()
        self.call("GET", "/feed", token=u["token"])  # any request purges
        self.assertFalse((server.PHOTO_DIR / keys).exists())

    def test_login_needs_the_right_password_and_never_says_which_part_was_wrong(self):
        u = self.user("login_user")
        ok = self.call("POST", "/login", {"username": "LOGIN_user", "password": "correct horse"})
        self.assertEqual((ok[0], ok[1]["token"]), (200, u["token"]))
        wrong_pw = self.call("POST", "/login", {"username": "login_user", "password": "wrong horse"})
        no_user = self.call("POST", "/login", {"username": "nobody_here", "password": "correct horse"})
        self.assertEqual((wrong_pw[0], wrong_pw[1]), (401, {"error": "invalid_credentials"}))
        self.assertEqual((no_user[0], no_user[1]), (401, {"error": "invalid_credentials"}))

    def test_a_typed_name_becomes_a_username_everywhere(self):
        status, body = self.call("POST", "/register", {"username": "  Sumeya   Farah ", "password": "correct horse"})
        self.assertEqual((status, body["username"]), (200, "sumeya_farah"))
        self.assertEqual(self.call("POST", "/login", {"username": "SUMEYA farah", "password": "correct horse"})[0], 200)
        other = self.user("finder_user")
        self.assertEqual(self.call("POST", "/friends/request", {"username": "Sumeya Farah"}, other["token"])[1]["status"],
                         "pending")

    def test_short_passwords_are_refused_and_never_stored_in_the_clear(self):
        self.assertEqual(self.call("POST", "/register", {"username": "weak_user", "password": "short"})[1]["error"],
                         "weak_password")
        self.user("hashed_user")
        row = server.db().execute("SELECT * FROM users WHERE username='hashed_user'").fetchone()
        self.assertNotIn(b"correct horse", bytes(row["password_hash"]) + bytes(row["password_salt"]))

    def test_delete_account_removes_everything(self):
        u, v = self.user("gone_user"), self.user("stays_user")
        self.befriend(u, v)
        self.checkin(u)
        self.assertEqual(self.call("POST", "/account/delete", {}, u["token"])[0], 200)
        self.assertEqual(self.call("GET", "/friends", token=u["token"])[0], 401)
        self.assertEqual(self.call("GET", "/friends", token=v["token"])[1]["friends"], [])


if __name__ == "__main__":
    unittest.main()
