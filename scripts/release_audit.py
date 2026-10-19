"""Local-only release checks. Findings contain filenames and rules, never secrets."""
import hashlib
import json
import re
import struct
import subprocess
from pathlib import PurePosixPath

AETHER_SHA256 = "56f511baadef2c521d7de983418813b075b3c2194825c7e17c06b59f267f2a78"
PRIVATE_NAMES = {
    "installation.json", "settings.json", "runtime.json", "presence.json", "status.json",
    "auth.json", "binding.json", "worker.lock", "update-preferences.json",
}
PATTERNS = {
    "credential": re.compile(rb"(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{30,}|sk-[A-Za-z0-9_-]{24,}|-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----)"),
    "private-setting": re.compile(rb'(?i)"(?:access_token|refresh_token|api_key|password)"\s*:\s*"(?![<*]|example|test|fake|fixture|dummy|redacted)[^"\r\n]{10,}"'),
    "machine-home": re.compile(rb"(?i)(?:[A-Z]:[\\/]+Users[\\/]+(?!Public|example|test|User[\\/]|<)[A-Za-z0-9_.-][^\s\"\r\n]*|/Users/(?!example|test|<)[A-Za-z0-9_.-]+/)"),
}


def git(root, *args):
    return subprocess.check_output(["git", *args], cwd=root)


def read_tree(root, ref="HEAD"):
    commit = git(root, "rev-parse", "--verify", ref + "^{commit}").decode().strip()
    files = {}
    for record in git(root, "ls-tree", "-r", "-z", commit).split(b"\0"):
        if not record:
            continue
        metadata, name = record.split(b"\t", 1)
        mode, kind, sha = metadata.split()
        if mode != b"100644" and mode != b"100755":
            raise ValueError("Unsupported tracked file mode: " + name.decode())
        if kind != b"blob":
            raise ValueError("Unsupported tracked object")
        files[name.decode("utf-8")] = git(root, "cat-file", "blob", sha.decode())
    return commit, files


def private_name(name):
    path = PurePosixPath(name)
    return (path.name in PRIVATE_NAMES or path.name.startswith((".env", "credentials", "quota-diagnostics."))
            or path.name.endswith(("-status.json", "-error.txt", ".flag", ".tmp", ".bak", ".bundle", ".log"))
            or bool(set(path.parts) & {".git", "node_modules", ".test-state", "sessions", "archived_sessions"}))


def findings(files):
    result = []
    for name, data in files.items():
        if private_name(name):
            result.append((name, "private-file"))
        if name.endswith(".dll"):
            if name != "gpt-niang-usage/runtime/vendor/aether/Aether.Physics2D.dll" or hashlib.sha256(data).hexdigest() != AETHER_SHA256:
                result.append((name, "unverified-binary"))
            continue
        if b"\0" not in data:
            for rule, pattern in PATTERNS.items():
                if pattern.search(data):
                    result.append((name, rule))
        if name.endswith(".png"):
            offset = 8
            while offset + 12 <= len(data):
                length = struct.unpack(">I", data[offset:offset + 4])[0]
                if data[offset + 4:offset + 8] in {b"tEXt", b"iTXt", b"zTXt", b"eXIf"}:
                    result.append((name, "image-metadata-review-required"))
                offset += length + 12
    return result


def validate_bundle(files):
    if "AI-NOTICE.md" not in files or b"insufficiently validated" not in files["AI-NOTICE.md"]:
        raise ValueError("Required AI generation and insufficient-validation notice is missing")
    issues = findings(files)
    if issues:
        raise ValueError("Release privacy checks failed: " + repr(issues))
    manifest = json.loads(files["gpt-niang-usage/.codex-plugin/plugin.json"])
    package = json.loads(files["gpt-niang-usage/package.json"])
    if manifest["version"] != package["version"] or not re.fullmatch(r"\d+\.\d+\.\d+", package["version"]):
        raise ValueError("Invalid or inconsistent release version")
    policy = json.loads(files["gpt-niang-usage/runtime/fork-policy.json"])
    if policy != {"repository": "Mikotoshire/GPT-Niang", "releaseUpdates": False}:
        raise ValueError("Personal fork update policy changed")
    servers = json.loads(files["gpt-niang-usage/.mcp.json"]).get("mcpServers")
    if servers != {"gpt-niang-usage": {"command": "node", "args": ["${CLAUDE_PLUGIN_ROOT}/runtime/mcp.mjs"]}}:
        raise ValueError("Only the portable MCP template may be distributed")
    return package["version"]
