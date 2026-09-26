import base64
from datetime import datetime, timezone
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("prepare", Path(__file__).parents[1] / "prepare_android_build.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class AndroidBuildTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "app").mkdir()
        self.now = datetime(2026, 9, 26, tzinfo=timezone.utc)

    def prepare(self, **env):
        return module.prepare(env, self.root, self.now)

    def test_ci_defaults_are_explicitly_development_only(self):
        values, artifact = self.prepare()
        self.assertEqual(values["SIGNING_MODE"], "debug-keys")
        self.assertIn("local-backend", artifact)
        self.assertIn("10.0.2.2", (self.root / "app/.env").read_text())
        self.assertLess(int(values["BUILD_NUMBER"]), 2100000000)

    def test_release_requires_url_and_all_credentials(self):
        for env in ({}, {"BACKEND_URL": "https://weather.example.com"},
                    {"BACKEND_URL": "http://10.0.2.2:8888"}):
            with self.subTest(env=env), self.assertRaises(ValueError):
                self.prepare(REQUIRE_RELEASE="true", **env)

    def test_partial_or_invalid_signing_never_silently_falls_back(self):
        with self.assertRaises(ValueError):
            self.prepare(KEYSTORE_PASSWORD="x")
        with self.assertRaises(ValueError):
            self.prepare(KEYSTORE_BASE64="not base64", KEYSTORE_PASSWORD="x", KEY_ALIAS="x", KEY_PASSWORD="x")

    def test_signed_build_uses_absolute_private_keystore(self):
        values, artifact = self.prepare(
            REQUIRE_RELEASE="true", BACKEND_URL="https://weather.example.com/",
            KEYSTORE_BASE64=base64.b64encode(b"test-keystore").decode(),
            KEYSTORE_PASSWORD="x", KEY_ALIAS="x", KEY_PASSWORD="x", NIGHTLY_STAMP="20260926",
        )
        self.assertEqual(values["SIGNING_MODE"], "signed")
        self.assertEqual(values["BUILD_NAME"], "1.0.0-nightly.20260926")
        self.assertIn("release-signed", artifact)
        store = Path(values["KEYSTORE_PATH"])
        self.assertTrue(store.is_absolute())
        self.assertEqual(store.read_bytes(), b"test-keystore")
        self.assertEqual(store.stat().st_mode & 0o777, 0o600)

    def test_url_rejects_credentials_and_env_injection(self):
        for url in ("not-a-url", "https://user:pass@example.com", "https://example.com\nGROQ_API_KEY=x", "https://example.com?x=1", 'https://example.com/$SECRET'):
            with self.subTest(url=url), self.assertRaises(ValueError):
                self.prepare(BACKEND_URL=url)


if __name__ == "__main__":
    unittest.main()
