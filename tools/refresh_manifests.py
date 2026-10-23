#!/usr/bin/env python3
"""Rebuild release manifests from the single Git-maintained source.

Uses Git's tracked/unignored file list. Does not rebind pattern source hashes,
alter expected fixture results or silently promote knowledge states.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import re

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    result = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
                            cwd=ROOT, check=True, stdout=subprocess.PIPE)
    names = sorted(set(x.decode("utf-8") for x in result.stdout.split(b"\0") if x))
    names = [n for n in names if (ROOT / n).is_file() and not (ROOT / n).is_symlink()]
    resources = [n for n in names if n.startswith("skills/power-system-model-audit/")]
    files = [{"path": n, "sourceSha256": sha(ROOT / n), "packageSha256": sha(ROOT / n),
              "bytes": (ROOT / n).stat().st_size} for n in resources]
    entrypoint = (ROOT / "skills/power-system-model-audit/SKILL.md").read_text(encoding="utf-8")
    version = re.search(r'^  version: "([^"]+)"$', entrypoint, re.MULTILINE).group(1)
    source = {"skillVersion": version, "semanticContractVersion": "0.12",
              "source": "Git-maintained skills/power-system-model-audit; workspace copies are generated mirrors",
              "packagingEdits": [], "files": files}
    (ROOT / "docs/source-manifest.json").write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    names = sorted(set(names) | {"docs/source-manifest.json"})
    manifest = {"algorithm": "SHA-256", "files": [
        {"path": n, "bytes": (ROOT / n).stat().st_size, "sha256": sha(ROOT / n)}
        for n in names if n != "docs/package-manifest.json"]}
    (ROOT / "docs/package-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Refreshed {len(files)} Skill resources and {len(manifest['files'])} package entries.")


if __name__ == "__main__":
    main()
