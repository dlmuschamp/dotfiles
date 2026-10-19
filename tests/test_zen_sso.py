"""Subprocess contracts for the non-destructive Zen SSO repair.

No real HOME, profile, process lookup, or browser is used. Failures against the
pre-repair scripts are intentional regression signals, not expected failures.
Run with: python3 -m unittest discover -s tests -v
"""
from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
ALLOW_ORIGINS = {
    "https://" + host for host in (
        "login.microsoftonline.com", "login.live.com", "login.windows.net",
        "outlook.office.com", "outlook.office365.com", "outlook.cloud.microsoft",
        "cloud.microsoft", "office.com", "www.office.com", "login.stanford.edu",
        "idp.stanford.edu",
    )
}
SCHEMA = """CREATE TABLE moz_perms (
    id INTEGER PRIMARY KEY, origin TEXT, type TEXT, permission INTEGER,
    expireType INTEGER, expireTime INTEGER, modificationTime INTEGER)"""


class ZenSSOTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="zen-sso-test-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.config = self.home / "config"
        self.cache = self.home / "cache"
        self.profile = self.config / "zen" / "test.default"
        self.profile.mkdir(parents=True)
        (self.config / "zen" / "profiles.ini").write_text(
            "[Profile0]\nName=test\nIsRelative=1\nPath=test.default\nDefault=1\n"
        )
        self.log = self.home / "calls.jsonl"
        self.env = {
            "HOME": str(self.home), "XDG_CONFIG_HOME": str(self.config),
            "XDG_CACHE_HOME": str(self.cache), "PATH": str(self.bin),
            "CALL_LOG": str(self.log), "PGREP_STATUS": "1",
            "ZEN_BIN": str(self.bin / "zen-bin"), "LC_ALL": "C",
            "TMPDIR": str(self.home),
        }
        # Expose only required utilities, never the user's PATH or real browser.
        for name in ("bash", "python3", "sqlite3", "date", "mkdir", "cp", "rm", "find", "seq", "sleep", "cat"):
            target = shutil.which(name)
            if target:
                (self.bin / name).symlink_to(target)
        self.stub("pgrep", 'raise SystemExit(int(os.environ["PGREP_STATUS"]))')
        self.stub("pkill", 'raise SystemExit("Unexpected attempt to kill a browser")')
        for name in ("zen-bin", "zen", "zen-sso-fix", "zen-sso-guard", "zen-sso-harden"):
            self.stub(name, 'raise SystemExit(int(os.environ.get("STUB_STATUS", "0")))')
        # The old Outlook script ignores ZEN_BIN. Intercept its exec rather than
        # risk executing /opt's real browser, even on a developer workstation.
        bash_env = self.home / "bash-env"
        bash_env.write_text(
            'exec() { case "$1" in /opt/*) printf "Blocked real browser: %s\\n" "$1" >&2; return 97;; esac; builtin exec "$@"; }\n'
        )
        self.env["BASH_ENV"] = str(bash_env)
        self.db = self.profile / "permissions.sqlite"
        with self.connect(self.db) as con:
            con.execute(SCHEMA)
            for origin in sorted(ALLOW_ORIGINS):
                self.insert(con, origin, "trackingprotection", 1)
        with self.connect(self.profile / "cookies.sqlite") as con:
            con.execute("CREATE TABLE moz_cookies (host TEXT, name TEXT, value TEXT, originAttributes TEXT)")
            con.executemany("INSERT INTO moz_cookies VALUES (?, ?, ?, '')", [
                ("outlook.cloud.microsoft", "session", "keep"),
                ("login.microsoftonline.com", "ESTSSSOTILES", "keep"),
            ])
        with self.connect(self.profile / "storage.sqlite") as con:
            con.execute("CREATE TABLE origin (origin TEXT)")
            con.execute("INSERT INTO origin VALUES ('https://outlook.cloud.microsoft')")
        for directory in ("sessionstore-backups", "zen-sessions-backup"):
            target = self.profile / directory
            target.mkdir()
            (target / "recovery.jsonlz4").write_bytes(b"keep archived session")
        (self.profile / "prefs.js").write_text("")
        for name in ("sessionstore.jsonlz4", "zen-sessions.jsonlz4", "sessionCheckpoints.json", "serviceworker.txt"):
            (self.profile / name).write_bytes(b"keep session state")
        self.local_storage({"msal.version": "4", "olk-login_hint": "user@example.test", "olk-authTimings": "{}"})
        cache = self.cache / "zen" / "test.default" / "cache2"
        cache.mkdir(parents=True)
        (cache / "sentinel").write_bytes(b"keep cache")

    def stub(self, name, body):
        path = self.bin / name
        path.write_text(
            "#!" + shutil.which("python3") + "\nimport json, os, sys\n"
            'with open(os.environ["CALL_LOG"], "a") as log:\n'
            '    log.write(json.dumps([os.path.basename(sys.argv[0]), *sys.argv[1:]]) + "\\n")\n'
            + body + "\n"
        )
        path.chmod(0o755)

    @contextmanager
    def connect(self, path):
        con = sqlite3.connect(path)
        try:
            with con:
                yield con
        finally:
            con.close()

    @staticmethod
    def insert(con, origin, kind, permission):
        con.execute("INSERT INTO moz_perms VALUES (NULL, ?, ?, ?, 0, 0, 123)",
                    (origin, kind, permission))

    def local_storage(self, values):
        directory = self.profile / "storage/default/https+++outlook.cloud.microsoft/ls"
        directory.mkdir(parents=True, exist_ok=True)
        with self.connect(directory / "data.sqlite") as con:
            con.execute("CREATE TABLE data (key TEXT, value TEXT)")
            con.executemany("INSERT INTO data VALUES (?, ?)", values.items())

    def run_script(self, name, *args):
        return subprocess.run(
            [str(self.bin / "bash"), str(ROOT / "bin" / name), *args],
            env=self.env, cwd=self.home, text=True, capture_output=True, timeout=15,
        )

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def snapshot(self):
        # Include names, contents, mode and mtime, including backup creation.
        return {str(p.relative_to(self.home)): (
            p.is_dir(), p.stat().st_mode, p.stat().st_mtime_ns,
            None if p.is_dir() else p.read_bytes(),
        ) for root in (self.config, self.cache) if root.exists() for p in [root, *root.rglob("*")]}

    def rows(self, path=None):
        with self.connect(path or self.db) as con:
            return con.execute("SELECT * FROM moz_perms ORDER BY id").fetchall()

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_repair_refuses_running_browser_without_changes(self):
        self.env["PGREP_STATUS"] = "0"
        before = self.snapshot()
        result = self.run_script("zen-sso-fix", "--repair-etp")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(before, self.snapshot())
        self.assertIn(["pgrep", "-x", "zen-bin"], self.calls())
        self.assertIn("running", (result.stdout + result.stderr).lower())

    def test_repair_refuses_held_posix_parentlock_when_pgrep_reports_stopped(self):
        self.env["PGREP_STATUS"] = "1"
        with self.connect(self.db) as con:
            con.execute("UPDATE moz_perms SET permission=2 WHERE origin='https://outlook.office.com'")
        with (self.profile / ".parentlock").open("w") as lock:
            # POSIX record locks are released if this process closes any fd
            # for the same inode, so snapshot before acquiring the lock.
            before = self.snapshot()
            fcntl.lockf(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = self.run_script("zen-sso-fix", "--repair-etp")
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(before, self.snapshot())
            self.assertIn(["pgrep", "-x", "zen-bin"], self.calls())
            self.assertRegex((result.stdout + result.stderr).lower(), r"lock|running|in use")

    def test_repair_only_upserts_etp_and_backs_up_original_permissions(self):
        with self.connect(self.db) as con:
            con.execute("UPDATE moz_perms SET permission=2")
            self.insert(con, "https://outlook.office.com", "trackingprotection", 2)
            for kind in ("cookie", "storageAccessAPI", "3rdPartyStorage^https://login.microsoftonline.com", "camera"):
                self.insert(con, "https://outlook.office.com", kind, 2)
            self.insert(con, "https://unrelated.test", "trackingprotection", 2)
        original_rows = self.rows()
        before = self.snapshot()
        self.assert_success(self.run_script("zen-sso-fix", "--repair-etp"))
        rows = self.rows()
        self.assertEqual([r for r in original_rows if not (r[1] in ALLOW_ORIGINS and r[2] == "trackingprotection")],
                         [r for r in rows if not (r[1] in ALLOW_ORIGINS and r[2] == "trackingprotection")])
        etp = [r for r in rows if r[1] in ALLOW_ORIGINS and r[2] == "trackingprotection"]
        self.assertEqual(len(etp), len(ALLOW_ORIGINS))
        self.assertEqual({r[1] for r in etp}, ALLOW_ORIGINS)
        self.assertTrue(all(r[3:6] == (1, 0, 0) for r in etp))
        backups = [p for p in self.profile.rglob("permissions.sqlite") if p != self.db]
        self.assertTrue(backups, "Original permissions DB must be backed up")
        self.assertTrue(any(self.rows(p) == original_rows for p in backups),
                        "Backup must preserve every original permission row")
        after = self.snapshot()
        for path, state in before.items():
            if path != str(self.db.relative_to(self.home)):
                # Backup creation may update the profile directory mtime only.
                self.assertEqual(state if not state[0] else state[:2],
                                 after[path] if not state[0] else after[path][:2], path)
        repaired = self.snapshot()
        backup_paths = {str(p.relative_to(self.profile)) for p in self.profile.rglob("permissions.sqlite") if p != self.db}
        self.assert_success(self.run_script("zen-sso-fix", "--repair-etp"))
        self.assertEqual(repaired, self.snapshot(), "Second repair must not rewrite files or create backups")
        self.assertEqual(backup_paths, {str(p.relative_to(self.profile)) for p in self.profile.rglob("permissions.sqlite") if p != self.db})
        self.assertEqual(len([r for r in self.rows() if r[2] == "trackingprotection"]), len(ALLOW_ORIGINS) + 1)

    def test_repair_missing_permissions_creates_only_etp(self):
        self.db.unlink()
        self.assert_success(self.run_script("zen-sso-fix", "--repair-etp"))
        rows = self.rows()
        self.assertEqual({(r[1], r[2], r[3]) for r in rows},
                         {(origin, "trackingprotection", 1) for origin in ALLOW_ORIGINS})
        self.assertEqual(len(rows), len(ALLOW_ORIGINS))

    def test_guard_default_is_read_only(self):
        before = self.snapshot()
        result = self.run_script("zen-sso-guard")
        self.assertIn("outlook.cloud.microsoft", result.stdout, result.stderr)
        self.assertEqual(before, self.snapshot())
        self.assertNotIn(["zen-sso-harden"], self.calls())

    def test_guard_check_is_read_only(self):
        before = self.snapshot()
        result = self.run_script("zen-sso-guard", "--check")
        self.assertIn("outlook.cloud.microsoft", result.stdout, result.stderr)
        self.assertEqual(before, self.snapshot())
        self.assertNotIn(["zen-sso-harden"], self.calls())

    def test_guard_metadata_without_token_keys_is_not_poison(self):
        result = self.run_script("zen-sso-guard", "--check")
        # Missing extension hardening may independently affect exit status.
        self.assertNotRegex(result.stdout, r"(?im)^.*outlook[^\n]*\bPOISON\b")
        self.assertNotIn("half-auth", result.stdout.lower())

    def test_guard_detects_incorrect_etp_permission(self):
        good = self.run_script("zen-sso-guard", "--check")
        with self.connect(self.db) as con:
            con.execute("UPDATE moz_perms SET permission=2 WHERE origin='https://outlook.office.com'")
        before = self.snapshot()
        bad = self.run_script("zen-sso-guard", "--check")
        self.assertEqual(before, self.snapshot())
        self.assertNotEqual(bad.returncode, 0)
        self.assertNotEqual(good.stdout, bad.stdout, "Guard must distinguish ETP permission=2 from permission=1")
        self.assertRegex(bad.stdout.lower(), r"(?s)(trackingprotection|etp).*(2|incorrect|wrong|invalid|unhealthy|repair)")

    def test_guard_reads_uncheckpointed_wal_and_cleans_scratch(self):
        con = sqlite3.connect(self.db)
        try:
            con.execute("PRAGMA journal_mode=WAL")
            con.execute("PRAGMA wal_autocheckpoint=0")
            con.execute("UPDATE moz_perms SET permission=2 WHERE origin='https://outlook.office.com'")
            con.commit()
            self.assertTrue(Path(str(self.db) + "-wal").exists())
            # A stale sibling scratch directory must neither contaminate this
            # diagnostic nor be removed as though it belonged to this run.
            stale = self.home / "zen-sso-check-stale"
            stale.mkdir()
            (stale / "sentinel").write_text("unrelated scratch")
            before = self.snapshot()
            scratch_before = {p.name for p in self.home.glob("zen-sso-*")}
            result = self.run_script("zen-sso-guard", "--check")
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertRegex(result.stdout.lower(), r"(?s)(trackingprotection|etp).*(2|incorrect|wrong|invalid|unhealthy|repair)")
            self.assertEqual(before, self.snapshot())
            self.assertEqual(scratch_before, {p.name for p in self.home.glob("zen-sso-*")})
            self.assertEqual((stale / "sentinel").read_text(), "unrelated scratch")
        finally:
            con.close()

    def test_cold_launch_repairs_then_checks_then_uses_zen_bin(self):
        self.assert_success(self.run_script("zen", "--new-tab", "https://example.test/"))
        self.assertEqual([c for c in self.calls() if c[0] != "pgrep"], [
            ["zen-sso-fix", "--repair-etp"], ["zen-sso-guard", "--check"],
            ["zen-bin", "--new-tab", "https://example.test/"],
        ])

    def test_cold_launch_remains_best_effort_when_helpers_fail(self):
        self.env["STUB_STATUS"] = "1"
        self.stub("zen-bin", "raise SystemExit(0)")
        self.assert_success(self.run_script("zen", "about:blank"))
        self.assertEqual([c for c in self.calls() if c[0] != "pgrep"], [
            ["zen-sso-fix", "--repair-etp"], ["zen-sso-guard", "--check"], ["zen-bin", "about:blank"],
        ])

    def test_running_launch_does_not_repair_or_guard(self):
        self.env["PGREP_STATUS"] = "0"
        self.assert_success(self.run_script("zen", "about:blank"))
        self.assertEqual([c for c in self.calls() if c[0] != "pgrep"], [["zen-bin", "about:blank"]])

    def test_outlook_normal_launch_uses_path_wrapper(self):
        for running in ("0", "1"):
            with self.subTest(running=running):
                self.log.unlink(missing_ok=True)
                self.env["PGREP_STATUS"] = running
                result = self.run_script("zen-outlook")
                calls = self.calls()
                self.assertTrue(any(c[0] == "zen" and any(a.startswith("https://") and "/mail/" in a for a in c[1:]) for c in calls),
                                result.stdout + result.stderr + repr(calls))
                self.assert_success(result)
                self.assertFalse(any(c[0] in ("zen-sso-fix", "zen-sso-guard", "zen-bin") for c in calls))

    def test_outlook_recover_explicitly_preserves_deep_recovery(self):
        result = self.run_script("zen-outlook", "--recover")
        calls = [c for c in self.calls() if c[0] != "pgrep"]
        self.assertGreaterEqual(len(calls), 2, result.stdout + result.stderr)
        self.assertEqual(calls[0], ["zen-sso-fix", "--deep"])
        self.assertTrue(any(c in (["zen-sso-guard"], ["zen-sso-harden"]) for c in calls[1:]),
                        "Explicit recovery must retain guard/hardening after the deep wipe")
        # Old recovery's hardcoded exec is safely blocked by BASH_ENV.
        self.assertIn(result.returncode, (0, 97), result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
