"""Build an audited Windows package from immutable committed Git blobs."""
import argparse
import hashlib
import json
import zipfile
from pathlib import Path
from release_audit import read_tree, findings, validate_bundle

PREFIX = "GPT-Niang-Mikotoshire/"
EXTRAS = {
    "LICENSE", "README.md", "gpt-niang-usage/LICENSE",
    ".agents/plugins/marketplace.json", "安装GPT娘.cmd", "打开GPT娘.cmd", "停用GPT娘.cmd",
    "检测套餐.cmd", "查看额度诊断.cmd", "docs/PRIVACY.md",
    "gpt-niang-usage/assets/CHARACTER-NOTICE.txt",
    "gpt-niang-usage/assets/quotes-LICENSE.txt", "gpt-niang-usage/assets/生成说明.md",
    "gpt-niang-usage/runtime/vendor/aether/LICENSE.txt", "gpt-niang-usage/runtime/vendor/aether/NOTICE.md",
}


def build(root, output, ref="HEAD"):
    commit, tree = read_tree(root, ref)
    issues = findings(tree)
    if issues:
        raise ValueError("Committed source audit failed: " + repr(issues))
    required = json.loads(tree["gpt-niang-usage/runtime/install-files.json"])
    names = EXTRAS | {"gpt-niang-usage/" + name for name in required}
    missing = names - tree.keys()
    if missing:
        raise ValueError("Missing required release files: " + repr(sorted(missing)))
    payload = {name: tree[name] for name in sorted(names)}
    version = validate_bundle(payload)
    notes = tree[f"docs/releases/{version}.md"].decode("utf-8")
    payload["SOURCE.json"] = (json.dumps({"repository": "https://github.com/Mikotoshire/GPT-Niang", "commit": commit, "version": version}, indent=2) + "\n").encode()
    payload["FILE-MANIFEST.json"] = (json.dumps({name: hashlib.sha256(data).hexdigest() for name, data in payload.items()}, indent=2, ensure_ascii=False) + "\n").encode()
    output.mkdir(parents=True, exist_ok=True)
    archive_name = f"gpt-niang-mikotoshire-v{version}-windows.zip"
    target = output / archive_name
    with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(payload.items()):
            info = zipfile.ZipInfo(PREFIX + name, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data)
    with zipfile.ZipFile(target) as archive:
        if archive.testzip() is not None:
            raise ValueError("Archive integrity failure")
        for name, expected in payload.items():
            if archive.read(PREFIX + name) != expected:
                raise ValueError("Archive content mismatch: " + name)
    report = {"commit": commit, "version": version, "sourceFilesAudited": len(tree), "packagedFiles": len(payload),
              "privacyFindings": 0, "source": "committed Git blobs; local worktree configuration excluded",
              "licenses": ["MIT code", "MS-PL Aether", "character noncommercial project-copy notice", "quotation MIT notice"],
              "limitations": ["Pattern scanning is not a legal certification or proof of absence of every secret.",
                              "Clean-device installation and full logon/Codex restart remain user acceptance tests."]}
    report_path = output / "RELEASE-AUDIT.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    sums = []
    for file in [target, report_path]:
        sums.append(f"{hashlib.sha256(file.read_bytes()).hexdigest()}  {file.name}")
    (output / "SHA256SUMS.txt").write_text("\n".join(sums) + "\n", encoding="utf-8")
    (output / "release-notes.md").write_text(notes + f"\n源码提交：`{commit}`。\n\n安装包 SHA256：`{hashlib.sha256(target.read_bytes()).hexdigest()}`。\n", encoding="utf-8")
    return target, report


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--ref", default="HEAD")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    target, report = build(root, args.output or root / "dist", args.ref)
    print(json.dumps({"archive": target.name, **report}, ensure_ascii=False))
