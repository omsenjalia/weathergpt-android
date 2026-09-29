import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("judges", Path(__file__).parents[1] / "update_judges_readme.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

SHA = "a" * 64
README = """# Title

> ## For judges
>
> <!-- judges-download:start -->
> old download line
> <!-- judges-download:end -->
>
> 1. step one
>
> <!-- judges-safety:start -->
> old safety text
> <!-- judges-safety:end -->

## Rest of the README stays untouched
"""


class JudgesReadmeTests(unittest.TestCase):
    def run_script(self, *extra, text=README):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "README.md"
            path.write_text(text)
            module.main([str(path), "--repo", "owner/repo", "--tag", "nightly-20260930", "--sha256", SHA, *extra])
            return path.read_text()

    def test_scanned_build_links_apk_report_and_verdict(self):
        out = self.run_script("--report", "https://www.virustotal.com/gui/file/" + SHA,
                              "--malicious", "0", "--suspicious", "0", "--engines", "62")
        self.assertIn("https://github.com/owner/repo/releases/download/nightly-20260930/release.apk", out)
        self.assertIn("VirusTotal report: 0 of 62 antivirus engines flagged it", out)
        self.assertIn(f"`{SHA}`", out)
        self.assertNotIn("old download line", out)
        self.assertNotIn("old safety text", out)
        self.assertIn("> 1. step one", out)
        self.assertTrue(out.endswith("## Rest of the README stays untouched\n"))

    def test_report_without_a_verdict_yet_still_links_it(self):
        out = self.run_script("--report", "https://www.virustotal.com/gui/file/" + SHA)
        self.assertIn("**[VirusTotal report](https://www.virustotal.com/gui/file/", out)
        self.assertNotIn("flagged", out)

    def test_no_report_points_to_manual_scan(self):
        out = self.run_script()
        self.assertIn("scan it at [virustotal.com]", out)
        self.assertIn(f"`{SHA}`", out)

    def test_is_idempotent(self):
        args = ("--report", "https://www.virustotal.com/gui/file/" + SHA, "--malicious", "0", "--suspicious", "0", "--engines", "60")
        once = self.run_script(*args)
        self.assertEqual(self.run_script(*args, text=once), once)

    def test_missing_markers_or_bad_input_fail(self):
        with self.assertRaises(ValueError):
            self.run_script(text="# No markers here\n")
        with self.assertRaises(SystemExit):
            module.main(["README.md", "--repo", "owner/repo", "--tag", "t", "--sha256", "not-a-sha"])

    def test_rejects_injection_in_repo_or_tag(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "README.md"
            path.write_text(README)
            for repo, tag in (("owner/repo)](evil", "t"), ("owner/repo", "t v")):
                with self.subTest(repo=repo, tag=tag), self.assertRaises(SystemExit):
                    module.main([str(path), "--repo", repo, "--tag", tag, "--sha256", SHA])


if __name__ == "__main__":
    unittest.main()
