#!/usr/bin/env python3
"""Validate CI config before Flutter runs; never interpolate secrets into shell code."""
import base64
import binascii
from datetime import datetime, timezone
import os
from pathlib import Path
import re
import sys
from urllib.parse import urlsplit

KEYS = ("KEYSTORE_BASE64", "KEYSTORE_PASSWORD", "KEY_ALIAS", "KEY_PASSWORD")


def prepare(env, root, now=None):
    app = root / "app"
    release = env.get("REQUIRE_RELEASE") == "true"
    url = env.get("BACKEND_URL", "").strip().rstrip("/")
    local_backend = not url
    if not url:
        if release:
            raise ValueError("Nightly releases require the BACKEND_URL repository variable (HTTPS).")
        url = "http://10.0.2.2:8888"
    parsed = urlsplit(url)
    if (parsed.scheme not in ("https", "http") or not parsed.hostname
            or parsed.username or parsed.password or parsed.query or parsed.fragment
            or any(c.isspace() for c in url) or any(c in url for c in "'\"\\$")):
        raise ValueError("BACKEND_URL must be a plain HTTP(S) base URL without credentials or query.")
    if release and (parsed.scheme != "https" or parsed.hostname in ("localhost", "127.0.0.1", "10.0.2.2", "placeholder.onrender.com")):
        raise ValueError("Nightly releases require a deployed HTTPS backend, not a placeholder/local URL.")
    present = [bool(env.get(key)) for key in KEYS]
    if any(present) and not all(present):
        raise ValueError("Signing configuration is incomplete; set all four keystore secrets.")
    if release and not all(present):
        raise ValueError("Nightly releases require a stable release keystore; debug signing is CI-only.")
    mode = "signed" if all(present) else "debug-keys"
    store = app / "android/app/release.keystore"
    if mode == "signed":
        try:
            data = base64.b64decode("".join(env["KEYSTORE_BASE64"].split()), validate=True)
        except (ValueError, binascii.Error) as exc:
            raise ValueError("KEYSTORE_BASE64 is not valid base64.") from exc
        if not data:
            raise ValueError("Keystore is empty.")
        store.parent.mkdir(parents=True, exist_ok=True)
        store.write_bytes(data)
        store.chmod(0o600)
    stamp = env.get("NIGHTLY_STAMP", "")
    if stamp and not re.fullmatch(r"\d{8}", stamp):
        raise ValueError("NIGHTLY_STAMP must be YYYYMMDD.")
    now = now or datetime.now(timezone.utc)
    # One versionCode scheme across CI and nightly, well below Android's 2.1B limit.
    build_number = int(now.timestamp()) - 1577836800  # seconds since 2020-01-01 UTC
    (app / ".env").write_text(f"BACKEND_URL={url}\n")
    sha = env.get("GITHUB_SHA", "local")
    artifact = f"weathergpt-{'release-signed' if mode == 'signed' else 'debug-signed'}-{sha}"
    if local_backend:
        artifact += "-local-backend"
    return {
        "SIGNING_MODE": mode,
        "KEYSTORE_PATH": str(store.resolve()),  # Gradle file() is app-module-relative
        "BUILD_NAME": f"1.0.0-nightly.{stamp}" if stamp else "1.0.0",
        "BUILD_NUMBER": str(build_number),
    }, artifact


def main():
    root = Path(__file__).resolve().parents[1]
    try:
        values, artifact = prepare(os.environ, root)
    except ValueError as exc:
        print(f"::error::{exc}", file=sys.stderr)
        return 1
    with open(os.environ["GITHUB_ENV"], "a") as handle:
        for key, value in values.items():
            handle.write(f"{key}={value}\n")
    with open(os.environ["GITHUB_OUTPUT"], "a") as handle:
        handle.write(f"artifact_name={artifact}\n")
    print(f"APK configuration: {artifact}; signing={values['SIGNING_MODE']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
