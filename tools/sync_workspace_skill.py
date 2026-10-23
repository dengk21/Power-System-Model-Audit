#!/usr/bin/env python3
"""Mirror the Git-maintained Skill without overwriting unrelated local edits.

The only maintained source is this repository's skills/power-system-model-audit.
First adoption accepts hashes from the previous source manifest; later runs
require the mirror to match its last synchronization marker. Retiring removed
resources requires an explicit flag and exact previous managed bytes.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

REPO = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def inventory(root):
    return {p.relative_to(root).as_posix(): digest(p) for p in Path(root).rglob("*")
            if p.is_file() and not p.is_symlink() and p.name != ".DS_Store"
            and "__pycache__" not in p.parts and p.suffix != ".pyc"}


def sync_tree(source, mirror, baseline=None, dry_run=False, retire_managed=False):
    source = Path(source).resolve(); mirror = Path(mirror).resolve()
    if source == mirror or source.is_relative_to(mirror) or mirror.is_relative_to(source):
        raise ValueError("Source and mirror must be separate trees")
    marker = mirror.parent / ("." + mirror.name + "-mirror.json")
    current = inventory(source)
    previous = json.loads(marker.read_text(encoding="utf-8"))["files"] if marker.exists() else {}
    accepted = {}
    if not previous and baseline:
        data = json.loads(Path(baseline).read_text(encoding="utf-8"))
        prefix = "skills/power-system-model-audit/"
        for item in data["files"]:
            if item["path"].startswith(prefix):
                accepted[item["path"][len(prefix):]] = {item["sourceSha256"], item["packageSha256"]}
    conflicts = []
    for name, value in current.items():
        target = mirror / name
        if target.is_symlink() or not target.resolve().is_relative_to(mirror):
            conflicts.append(name); continue
        if target.exists():
            allowed = {value, previous.get(name)} | accepted.get(name, set())
            if not target.is_file() or digest(target) not in allowed:
                conflicts.append(name)
    extras = set(inventory(mirror)) - set(current) if mirror.exists() else set()
    retired = []
    if retire_managed:
        for name in sorted(extras):
            target = mirror / name
            known = {previous.get(name)} | accepted.get(name, set())
            if target.is_symlink() or not target.resolve().is_relative_to(mirror) or digest(target) not in known:
                conflicts.append(name)
            else:
                retired.append(name)
        extras -= set(retired)
    if conflicts or extras:
        raise ValueError("Mirror has unmanaged edits/files; reconcile first: " + ", ".join(sorted(set(conflicts) | extras)))
    changed = [name for name, value in current.items() if not (mirror / name).exists() or digest(mirror / name) != value]
    if not dry_run:
        mirror.mkdir(parents=True, exist_ok=True)
        for name in retired:
            target = mirror / name
            target.unlink()
            parent = target.parent
            while parent != mirror:
                try:
                    parent.rmdir()
                except OSError:
                    break
                parent = parent.parent
        for name in changed:
            target = mirror / name; target.parent.mkdir(parents=True, exist_ok=True)
            temporary = target.with_name(target.name + ".sync-tmp")
            temporary.write_bytes((source / name).read_bytes()); temporary.replace(target)
        marker.write_text(json.dumps({"canonical_repository": "dengk21/Power-System-Model-Audit",
            "canonical_source": str(source), "files": current}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return {"managed_files": len(current), "changed": changed, "retired": retired, "dry_run": dry_run}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--mirror", required=True); p.add_argument("--baseline"); p.add_argument("--dry-run", action="store_true")
    p.add_argument("--retire-managed", action="store_true", help="Remove only unchanged files previously managed by this mirror")
    args = p.parse_args()
    try:
        print(json.dumps(sync_tree(REPO / "skills/power-system-model-audit", args.mirror, args.baseline, args.dry_run, args.retire_managed), ensure_ascii=False, indent=2))
        return 0
    except (OSError, ValueError, KeyError) as error:
        print("ERROR: " + str(error), file=sys.stderr); return 2


if __name__ == "__main__":
    raise SystemExit(main())
