import importlib.util
import json
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path

from release_audit import findings, validate_bundle

spec = importlib.util.spec_from_file_location("builder", Path(__file__).with_name("build-release.py"))
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class ReleaseTests(unittest.TestCase):
    def test_sensitive_files_and_credentials_are_blocked_without_echoing_values(self):
        secret = b"ghp_" + b"A" * 32
        for name, data in [("auth.json", b"{}"), ("quota-diagnostics.jsonl", b"{}"),
                           ("source.mjs", secret), ("source.mjs", b"C:" + bytes([92]) + b"Users" + bytes([92]) + b"private-person" + bytes([92]) + b"state")]:
            result = findings({name: data})
            self.assertTrue(result)
            self.assertNotIn(secret.decode(), repr(result))

    def test_ai_notice_is_mandatory(self):
        with self.assertRaisesRegex(ValueError, "AI generation"):
            validate_bundle({})

    def test_unknown_binary_and_image_metadata_are_blocked(self):
        self.assertTrue(findings({"unknown.dll": b"binary"}))
        self.assertTrue(findings({"picture.png": b"\x89PNG\r\n\x1a\n" + b"\0\0\0\x04tEXtdata0000"}))

    def test_build_reads_commits_not_private_worktree_and_is_reproducible(self):
        with tempfile.TemporaryDirectory(prefix="gpt-release-test-") as directory:
            root = Path(directory)
            required = ["package.json", ".codex-plugin/plugin.json", ".mcp.json",
                        "runtime/install-files.json", "runtime/fork-policy.json"]
            files = {name: b"fixture\n" for name in builder.EXTRAS}
            files["AI-NOTICE.md"] = b"Maintenance changes and docs are AI-generated and insufficiently validated.\n"
            files.update({
                "gpt-niang-usage/package.json": b'{"version":"1.4.0"}',
                "gpt-niang-usage/.codex-plugin/plugin.json": b'{"version":"1.4.0"}',
                "gpt-niang-usage/runtime/install-files.json": json.dumps(required).encode(),
                "gpt-niang-usage/runtime/fork-policy.json": b'{"repository":"Mikotoshire/GPT-Niang","releaseUpdates":false}',
                "gpt-niang-usage/.mcp.json": b'{"mcpServers":{"gpt-niang-usage":{"command":"node","args":["${CLAUDE_PLUGIN_ROOT}/runtime/mcp.mjs"]}}}',
                "docs/releases/1.4.0.md": b"Fictional test release\n",
            })
            for name, data in files.items():
                file = root / name
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_bytes(data)
            def git(*args):
                return subprocess.check_output(["git", *args], cwd=root, stderr=subprocess.STDOUT)
            git("init", "-q")
            git("-c", "core.autocrlf=false", "add", ".")
            git("-c", "user.name=Release Test", "-c", "user.email=test@example.test", "commit", "-qm", "fixture")
            # Reproduce the original publisher's generated MCP/private-file trap.
            (root / "gpt-niang-usage/.mcp.json").write_text('{"private":"machine-specific-configuration"}')
            (root / "gpt-niang-usage/installation.json").write_text('{"private":"account-configuration"}')
            first, report = builder.build(root, root / "first")
            second, _ = builder.build(root, root / "second")
            self.assertEqual(first.read_bytes(), second.read_bytes())
            self.assertEqual(report["privacyFindings"], 0)
            self.assertTrue(report["aiGeneratedMaintenanceChangesAndDocs"])
            self.assertEqual(report["validationStatus"], "insufficiently_validated")
            with zipfile.ZipFile(first) as archive:
                self.assertEqual(archive.read(builder.PREFIX + "gpt-niang-usage/.mcp.json"), files["gpt-niang-usage/.mcp.json"])
                self.assertIn(b"insufficiently validated", archive.read(builder.PREFIX + "AI-NOTICE.md"))
                self.assertFalse(any("installation.json" in name for name in archive.namelist()))
                for name in archive.namelist():
                    self.assertNotIn(b"machine-specific-configuration", archive.read(name))
            (root / "gpt-niang-usage/.mcp.json").write_text('{"private":"contaminated-committed-template"}')
            git("add", "gpt-niang-usage/.mcp.json")
            git("-c", "user.name=Release Test", "-c", "user.email=test@example.test", "commit", "-qm", "bad template")
            with self.assertRaisesRegex(ValueError, "portable MCP"):
                builder.build(root, root / "bad")


if __name__ == "__main__":
    unittest.main()
