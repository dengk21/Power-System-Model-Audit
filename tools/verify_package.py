#!/usr/bin/env python3
"""Verify this source snapshot without external packages or course inputs."""
import hashlib
import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs/package-manifest.json"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify():
    errors = []
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    tracked = {item["path"]: item for item in manifest["files"]}
    for name, item in tracked.items():
        file = ROOT / name
        if not file.is_file():
            errors.append(f"Missing: {name}")
        elif file.stat().st_size != item["bytes"] or digest(file) != item["sha256"]:
            errors.append(f"Changed: {name} (update manifest for an intentional release change)")

    ignored = {"outputs", ".git", "__pycache__", ".vscode", ".idea"}
    actual = {
        p.relative_to(ROOT).as_posix()
        for p in ROOT.rglob("*")
        if p.is_file() and p.name != '.DS_Store' and not (set(p.relative_to(ROOT).parts) & ignored)
    }
    unexpected = actual - set(tracked) - {"docs/package-manifest.json"}
    errors.extend(f"Unlisted file: {name}" for name in sorted(unexpected))

    source = json.loads((ROOT / "docs/source-manifest.json").read_text(encoding="utf-8"))
    changed = set()
    for item in source["files"]:
        file = ROOT / item["path"]
        if not file.is_file():
            errors.append(f"Missing Skill resource: {item['path']}")
            continue
        current = digest(file)
        if current != item["packageSha256"]:
            errors.append(f"Skill snapshot mismatch: {item['path']}")
        if item["sourceSha256"] != item["packageSha256"]:
            changed.add(item["path"])
            if file.suffix.lower() != ".md":
                errors.append(f"Core non-Markdown file changed: {item['path']}")
    if changed != set(source["packagingEdits"]):
        errors.append("Packaging edit list does not match the source manifest")

    skill_root = ROOT / "skills/power-system-model-audit"
    if (skill_root / "examples").exists():
        errors.append("Project examples must be outside the Skill")
    for name in ("psaudit_run.m", "psaudit_test_run.m"):
        if (skill_root / "scripts" / name).exists():
            errors.append("Fixed course entrypoint must be project-owned: " + name)

    links_checked = 0
    for name in tracked:
        file = ROOT / name
        if file.suffix.lower() not in {".md", ".m", ".yaml", ".py"} or not file.is_file():
            continue
        body = file.read_text(encoding="utf-8")
        if re.search(r"[A-Za-z]:[/\\](?:Users|File)[/\\]", body, re.I):
            errors.append(f"Private absolute path: {name}")
        if file.suffix.lower() != ".md":
            continue
        # Skip fenced code; only concrete inline Markdown destinations apply.
        prose = re.sub(r"```.*?```", "", body, flags=re.S)
        for match in re.finditer(r"!?\[[^\]\n]*\]\(([^)\n]+)\)", prose):
            target = match.group(1).strip().split(' "', 1)[0].strip("<>")
            if re.match(r"[a-zA-Z][\w+.-]*:", target) or target.startswith("#"):
                continue
            relative = unquote(target.split("#", 1)[0])
            if not relative:
                continue
            resolved = (file.parent / relative).resolve()
            if not resolved.is_relative_to(ROOT) or not resolved.exists():
                errors.append(f"Broken local Markdown link: {name} -> {target}")
            links_checked += 1

    if errors:
        print("FAIL\n" + "\n".join(errors))
        return 1
    print(f"PASS: {len(tracked)} tracked files; {len(source['files'])} Skill resources; "
          f"{len(source['files']) - len(changed)} byte-identical; "
          f"{len(changed)} documentation adaptations; {links_checked} local links.")
    return 0


if __name__ == "__main__":
    sys.exit(verify())
