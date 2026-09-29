#!/usr/bin/env python3
"""Point the README's "For judges" section at a released APK and its VirusTotal report.

The nightly release runs this after publishing. It rewrites only the text between the
`<!-- judges-download:... -->` and `<!-- judges-safety:... -->` markers, so the rest of
the README is never touched.

    python scripts/update_judges_readme.py README.md --repo owner/name --tag nightly-20260929 \
        --sha256 <hex> [--report URL --malicious 0 --suspicious 0 --engines 60]
"""

import argparse
import re
import sys
from pathlib import Path

BLOCKS = ("judges-download", "judges-safety")


def verdict(args) -> str | None:
    """'0 of 60 antivirus engines flagged it', or None when the scan has no result yet."""
    if args.report is None or args.engines is None or args.malicious is None:
        return None
    flagged = args.malicious + (args.suspicious or 0)
    return f"{flagged} of {args.engines} antivirus engines flagged it"


def render(args) -> dict[str, str]:
    repo = f"https://github.com/{args.repo}"
    apk = f"{repo}/releases/download/{args.tag}/release.apk"
    summary = verdict(args)
    if args.report is None:
        badge = f"SHA-256 below; scan it at [virustotal.com](https://www.virustotal.com)"
    elif summary is None:
        badge = f"**[VirusTotal report]({args.report})**"
    else:
        badge = f"**[VirusTotal report: {summary}]({args.report})**"
    download = f"> **Download:** [**release.apk**]({apk}) (signed build `{args.tag}`)  ·  {badge}"

    if args.report is None:
        scanned = "> **Is it safe?** You can upload this APK to [VirusTotal](https://www.virustotal.com) to scan it with 70+ antivirus engines."
    elif summary is None:
        scanned = f"> **Is it safe?** This exact APK was submitted to [VirusTotal]({args.report}); open the report for the per-engine results."
    else:
        detail = f"({args.malicious} malicious, {args.suspicious or 0} suspicious)"
        scanned = f"> **Is it safe?** This exact APK was scanned by [VirusTotal]({args.report}) — **{summary}** {detail}."
    safety = "\n".join([
        scanned,
        "> To confirm the file you downloaded is the same one, compare its SHA-256 with",
        f"> `{args.sha256}`",
        "> (Windows: `certutil -hashfile release.apk SHA256` · macOS/Linux: `shasum -a 256 release.apk`).",
    ])
    return {"judges-download": download, "judges-safety": safety}


def apply(text: str, blocks: dict[str, str]) -> str:
    for name, body in blocks.items():
        pattern = re.compile(rf"(> <!-- {name}:start -->\n).*?(\n> <!-- {name}:end -->)", re.DOTALL)
        text, count = pattern.subn(lambda m: m.group(1) + body + m.group(2), text)
        if count != 1:
            raise ValueError(f"README must contain exactly one {name} block (found {count})")
    return text


def main(argv=None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("readme", type=Path)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--report")
    parser.add_argument("--malicious", type=int)
    parser.add_argument("--suspicious", type=int)
    parser.add_argument("--engines", type=int)
    args = parser.parse_args(argv)
    if not re.fullmatch(r"[0-9a-f]{64}", args.sha256):
        parser.error("--sha256 must be 64 lowercase hex characters")
    if not re.fullmatch(r"[\w.-]+/[\w.-]+", args.repo) or not re.fullmatch(r"[\w.-]+", args.tag):
        parser.error("--repo / --tag contain unexpected characters")
    raw = args.readme.read_bytes().decode("utf-8")
    crlf = "\r\n" in raw
    text = apply(raw.replace("\r\n", "\n"), render(args))
    args.readme.write_bytes((text.replace("\n", "\r\n") if crlf else text).encode("utf-8"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
