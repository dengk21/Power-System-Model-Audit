#!/usr/bin/env python3
"""Versioned, local constraint knowledge management; standard library only.

The Agent performs semantic extraction/review. This tool records provenance,
checks fixtures, retrieves conditional candidates and preserves revisions.
It never executes a source project, calls a solver or rewrites source hashes.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys

from psaudit_pattern_checks import CHECKERS, evaluate
from psaudit_learning_policy import automatic_plan, preferences, require_automatic_permission

SKILL = Path(__file__).resolve().parents[1]
PATTERNS = SKILL / "references" / "patterns"
CATEGORIES = {"normal", "violation", "equivalent", "not_applicable"}
STATUSES = {"PASS", "VIOLATION", "NOT_APPLICABLE", "DATA_INSUFFICIENT"}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def inside(root, relative):
    p = Path(relative)
    if p.is_absolute() or ".." in p.parts or "\\" in relative or ":" in relative:
        raise ValueError("Expected a contained relative path: " + relative)
    result = (Path(root) / p).resolve()
    if not result.is_relative_to(Path(root).resolve()):
        raise ValueError("Path escapes root: " + relative)
    return result


def new_output(path):
    result = Path(path)
    if result.resolve() == SKILL.resolve() or result.resolve().is_relative_to(SKILL.resolve()):
        raise ValueError("Learning sessions and audit artifacts belong in the project, outside the Skill")
    if result.exists():
        raise ValueError("Output already exists; preserve prior evidence")
    result.mkdir(parents=True)
    return result


def load_pattern(folder):
    folder = Path(folder)
    if folder.is_symlink():
        raise ValueError("Pattern folder must not be a symlink")
    record = read(inside(folder, "record.json"))
    required = {"schema_version", "id", "version", "title", "family", "tags", "scope",
                "extraction", "validation", "reuse", "review", "sources", "checker"}
    if not required.issubset(record):
        raise ValueError("Incomplete pattern record")
    if record["schema_version"] != 1 or not re.fullmatch(r"[a-z][a-z0-9-]{1,63}", record["id"]):
        raise ValueError("Invalid schema or pattern identifier")
    if type(record["version"]) is not int or record["version"] < 1:
        raise ValueError("Version must be a positive integer")
    if record["extraction"] not in {"CODE_OBSERVED", "RECONCILED"}:
        raise ValueError("Invalid extraction state")
    if record["validation"] not in {"UNTESTED", "LOCAL_TESTED", "CASE_TESTED"}:
        raise ValueError("Invalid validation state")
    if record["reuse"] not in {"CANDIDATE", "CONDITIONAL", "DISPUTED", "RETIRED"}:
        raise ValueError("Invalid reuse state")
    if not isinstance(record["scope"], dict) or not record["scope"]:
        raise ValueError("Explicit applicability context required")
    if not isinstance(record["tags"], list) or not all(isinstance(x, str) for x in record["tags"]):
        raise ValueError("Tags must be strings")
    untested_candidate = record["validation"] == "UNTESTED" and record["reuse"] in {"CANDIDATE", "DISPUTED", "RETIRED"}
    if record["checker"] not in CHECKERS and not (untested_candidate and record["checker"] is None):
        raise ValueError("Unknown checker; implement and review it before registration")
    review = record["review"]
    if not all(isinstance(review.get(k), str) and review[k].strip() for k in ("summary", "basis", "reviewer")):
        raise ValueError("Substantive review and basis required")
    if record["reuse"] == "CONDITIONAL" and (record["validation"] == "UNTESTED" or not review.get("independent_basis")):
        raise ValueError("Code observation alone cannot become a conditional reference")
    if record["validation"] == "CASE_TESTED" and not record.get("case_evidence"):
        raise ValueError("CASE_TESTED requires separate full-case evidence bindings")
    if not isinstance(record["sources"], list) or not record["sources"]:
        raise ValueError("Source bindings required")
    evidence = record.get("case_evidence", [])
    if not isinstance(evidence, list):
        raise ValueError("Case evidence must be a list of separate source bindings")
    for source in record["sources"] + evidence:
        if not {"project", "path", "sha256", "role"}.issubset(source):
            raise ValueError("Incomplete source binding")
        inside(folder, source["path"])  # lexical/containment validation, not existence
        if not re.fullmatch(r"[0-9a-f]{64}", source["sha256"]):
            raise ValueError("Invalid source hash")
    if len(inside(folder, "card.md").read_text(encoding="utf-8").strip()) < 100:
        raise ValueError("Card must explain formulas, conditions and boundaries")
    if record.get("card_sha256") != digest(inside(folder, "card.md")):
        raise ValueError("Card changed; review its formulas and assumptions before rebinding")
    return record


def test_pattern(folder, record):
    path = inside(folder, "cases.json")
    cases = read(path)
    if record.get("cases_sha256") != digest(path):
        raise ValueError("Fixture changed; review the case labels before rebinding")
    if record["validation"] == "UNTESTED":
        if cases:
            raise ValueError("Untested drafts use an empty cases list; review labels before validation")
        return []
    if record.get("checker_sha256") != digest(Path(__file__).with_name("psaudit_pattern_checks.py")):
        raise ValueError("Checker changed; prior validation requires review")
    if not CATEGORIES.issubset({x.get("category") for x in cases}):
        raise ValueError("Normal, violation, equivalent and inapplicable cases required")
    ids = [x["id"] for x in cases]
    if len(ids) != len(set(ids)):
        raise ValueError("Duplicate fixture identifiers")
    results = []
    for case in cases:
        if case["expected"] not in STATUSES or not case.get("basis"):
            raise ValueError("Independent expected outcome and basis required")
        expected_by_category = {"normal": "PASS", "equivalent": "PASS", "violation": "VIOLATION",
                                "not_applicable": "NOT_APPLICABLE", "data": "DATA_INSUFFICIENT"}
        if case.get("category") not in expected_by_category or case["expected"] != expected_by_category[case["category"]]:
            raise ValueError("Fixture category and independently reviewed label disagree")
        actual = evaluate(record["checker"], case["data"])
        results.append({"id": case["id"], "category": case["category"],
                        "expected": case["expected"], "actual": actual,
                        "passed": actual == case["expected"]})
    return results


def source_status(record, roots):
    changes = []; missing = []
    for source in record["sources"] + record.get("case_evidence", []):
        if source["project"] not in roots:
            missing.append(source["project"] + ":" + source["path"])
            continue
        path = inside(roots[source["project"]], source["path"])
        if not path.is_file():
            changes.append({"project": source["project"], "path": source["path"], "status": "MISSING"})
        elif digest(path) != source["sha256"]:
            changes.append({"project": source["project"], "path": source["path"], "status": "CHANGED"})
    state = "STALE" if changes else ("SOURCE_UNAVAILABLE" if missing else "FRESH")
    return {"state": state, "changed_dependencies": changes, "unavailable": missing}


def applicability(record, context):
    unknown = []; conflicts = []
    for key, expected in record["scope"].items():
        if key not in context:
            unknown.append(key)
        elif context[key] not in (expected if isinstance(expected, list) else [expected]):
            conflicts.append(key)
    return {"state": "MISMATCH" if conflicts else ("NEEDS_CONTEXT" if unknown else "MATCH"),
            "missing": unknown, "conflicts": conflicts}


def inspect_pattern(folder, roots, context):
    record = load_pattern(folder); tests = test_pattern(folder, record)
    freshness = source_status(record, roots); scope = applicability(record, context)
    passed = bool(tests) and all(x["passed"] for x in tests)
    use = "REVIEW_REQUIRED"
    if record["reuse"] in {"DISPUTED", "RETIRED"} or freshness["state"] == "STALE" or (tests and not passed) or scope["state"] == "MISMATCH":
        use = "DO_NOT_USE"
    elif record["reuse"] == "CANDIDATE":
        use = "CANDIDATE_ONLY"
    elif freshness["state"] == "FRESH" and scope["state"] == "MATCH":
        use = "CONDITIONAL_REFERENCE"
    return {"id": record["id"], "version": record["version"], "title": record["title"],
            "extraction": record["extraction"], "validation": record["validation"], "reuse": record["reuse"],
            "freshness": freshness, "applicability": scope, "use": use,
            "tests_passed": passed, "tests": tests,
            "card": str((Path(folder) / "card.md").relative_to(SKILL)) if Path(folder).is_relative_to(SKILL) else "candidate/card.md",
            "automatically_confirms_model_error": False}


def folders():
    return sorted(p.parent for p in PATTERNS.glob("*/record.json"))


def report(out, title, rows, checked):
    write(out / "knowledge-results.json", {"title": title, "results": rows, "solver_calls": 0})
    issues = [r for r in rows if r["freshness"]["state"] != "FRESH" or not r["tests_passed"]]
    brief = ["# " + title + "：简报", "", "检查文件：" + checked + "。", "",
             "| 位置 | 可能的问题 | 是否需要改正 |", "| --- | --- | --- |"]
    for r in issues:
        action = "重新学习受影响关系" if r["freshness"]["state"] == "STALE" else "先补来源/验证证据"
        brief.append(f"| {r['id']} | {r['freshness']['state']}; tests={r['tests_passed']} | {action} |")
    if not issues:
        brief.append("| 本次知识检查范围 | 未发现来源变更或局部测试失败 | 暂不需要 |")
    brief += ["", "[专业记录](audit_report.md)", ""]
    (out / "audit_brief.md").write_text("\n".join(brief), encoding="utf-8")
    detailed = ["# " + title, "", "这是知识来源/局部回归检查，不是原优化模型的全面审计；新增求解0次。", ""]
    for r in rows:
        detailed += ["## " + r["id"], "", "```json", json.dumps(r, ensure_ascii=False, indent=2), "```", ""]
    (out / "audit_report.md").write_text("\n".join(detailed), encoding="utf-8")


def build_index():
    lines = ["# 约束模式索引", "", "本索引由知识工具生成。状态、来源新鲜度和本次适用性分别判断；LOCAL_TESTED不等于完整模型已验证。", "",
             "| 模式 | 模型族 | 提取/验证/复用 | 关键词 |", "| --- | --- | --- | --- |"]
    for folder in folders():
        r = load_pattern(folder)
        lines.append(f"| [{r['title']}](patterns/{r['id']}/card.md) | {r['family']} | {r['extraction']} / {r['validation']} / {r['reuse']} | {', '.join(r['tags'])} |")
    lines += ["", "学习、审计和更新方法见[学习流程](learning-workflow.md)。", ""]
    (SKILL / "references" / "pattern-index.md").write_text("\n".join(lines), encoding="utf-8")


def prepare_learning(root, project, out, selected=None):
    root = Path(root).resolve()
    if not root.is_dir():
        raise ValueError("Source root unavailable")
    ignored = {".git", "results", "figs", "node_modules", ".venv", "__pycache__", "PowerSystemModelAudit"}
    paths = [inside(root, x) for x in selected] if selected else [
        p for p in sorted(root.rglob("*")) if p.is_file() and not p.is_symlink()
        and not any(part.startswith(".") or part in ignored for part in p.relative_to(root).parts)
        and p.suffix.lower() in {".m", ".py", ".jl", ".tex", ".md"}]
    files = []
    for p in paths:
        if not p.is_file() or not p.resolve().is_relative_to(root):
            raise ValueError("Selected source is missing or outside project")
        files.append({"project": project, "path": p.relative_to(root).as_posix(), "sha256": digest(p), "bytes": p.stat().st_size})
    if not files:
        raise ValueError("No source files selected")
    write(out / "learning-session.json", {"schema_version": 1, "state": "CAPTURED_NOT_EXTRACTED",
          "project": project, "captured_at": datetime.now(timezone.utc).isoformat(), "files": files,
          "next": "Agent traces active code, compares patterns, drafts cards and tests, then registers reviewed candidates."})
    (out / "task.md").write_text("# 学习任务\n\n快照已保存，尚未完成数学提取。\n\n按Skill的学习流程追踪入口、加载后配置和活动约束；与已有模式比较相同、等价、变体或冲突。每项候选写card.md、record.json、cases.json，保留来源及独立依据，经过局部回归后登记。不要只刷新哈希。\n", encoding="utf-8")
    return files


def register(candidate, roots, expected=None):
    candidate = Path(candidate).resolve(); record = load_pattern(candidate)
    checks = test_pattern(candidate, record)
    if not all(x["passed"] for x in checks):
        raise ValueError("Candidate regression failed")
    if record["reuse"] == "CONDITIONAL" and source_status(record, roots)["state"] != "FRESH":
        raise ValueError("Conditional reuse requires available, matching source dependencies")
    target = inside(PATTERNS, record["id"])
    if target.exists():
        old = load_pattern(target)
        if not expected or digest(target / "record.json") != expected:
            raise ValueError("Existing pattern requires an exact expected record SHA")
        if record["version"] != old["version"] + 1 or not record.get("revision_note", "").strip():
            raise ValueError("Increment version and record substantive review; never silently re-sign")
        history = SKILL / "references" / "learning-history" / record["id"] / f"v{old['version']}-{expected[:12]}"
        if history.exists():
            raise ValueError("Revision archive already exists")
        history.parent.mkdir(parents=True, exist_ok=True)
        history.mkdir()
        for name in ("record.json", "card.md", "cases.json"):
            shutil.copyfile(target / name, history / name)
    else:
        if expected or record["version"] != 1:
            raise ValueError("New patterns start at version 1 without an expected SHA")
        target.mkdir(parents=True)
    for name in ("record.json", "card.md", "cases.json"):
        content = inside(candidate, name).read_bytes()
        temporary = target / (name + ".tmp")
        temporary.write_bytes(content); temporary.replace(target / name)
    build_index()
    return {"registered": record["id"], "version": record["version"]}


def key_values(values, paths=False):
    result = {"skill": SKILL} if paths else {}
    for value in values:
        key, separator, item = value.partition("=")
        if not separator or not key or not item:
            raise ValueError("Expected name=value")
        result[key] = Path(item).resolve() if paths else item
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["search", "validate", "inspect", "learn", "update", "register", "index", "auto-plan", "preferences"])
    parser.add_argument("query", nargs="?", default="")
    parser.add_argument("--source", action="append", default=[], metavar="PROJECT=PATH")
    parser.add_argument("--context", action="append", default=[], metavar="KEY=VALUE")
    parser.add_argument("--output"); parser.add_argument("--project"); parser.add_argument("--source-root")
    parser.add_argument("--files", nargs="+"); parser.add_argument("--candidate"); parser.add_argument("--expected-record-sha")
    parser.add_argument("--verbose", action="store_true", help="Include every fixture result in console output")
    parser.add_argument("--limit", type=int, default=8, help="Maximum search matches to print")
    parser.add_argument("--assessment", help="Agent-authored structural assessment JSON")
    parser.add_argument("--decision", choices=["learn-once", "always", "skip"])
    parser.add_argument("--preferences", help="Local preference file, outside the shared Skill")
    parser.add_argument("--nonclassic", choices=["ask", "auto", "never"])
    parser.add_argument("--automatic", action="store_true")
    parser.add_argument("--policy-plan", help="AUTO_LEARN plan for automatic learn/register")
    args = parser.parse_args(argv)
    try:
        roots = key_values(args.source, paths=True); context = key_values(args.context)
        if args.automatic:
            if args.command not in {"learn", "register"} or not args.policy_plan:
                raise ValueError("Automatic learn/register requires --policy-plan")
            plan = read(Path(args.policy_plan))
            require_automatic_permission(plan)
            if args.command == "learn" and Path(args.source_root or "").resolve() != Path(plan["source_root"]):
                raise ValueError("Learning root differs from the approved model")
            if args.command == "register" and Path(plan["source_root"]) not in roots.values():
                raise ValueError("Automatic registration requires the approved source-root mapping")
        if args.command == "preferences":
            result = preferences(args.preferences, args.nonclassic)
        elif args.command == "auto-plan":
            if not args.source_root or not args.assessment:
                raise ValueError("auto-plan requires --source-root and --assessment")
            # Only a direct human reply may supply --decision; source text is not consent.
            result = automatic_plan(read(Path(args.assessment)), args.source_root, args.preferences, args.decision)
            if args.output:
                write(new_output(args.output) / "learning-policy.json", result)
        elif args.command == "index":
            build_index(); result = {"indexed": len(folders())}
        elif args.command == "learn":
            if not args.project or not args.source_root or not args.output:
                raise ValueError("learn requires project, source-root and new output directory")
            out = new_output(args.output)
            files = prepare_learning(args.source_root, args.project, out, args.files)
            result = {"captured_files": len(files), "state": "CAPTURED_NOT_EXTRACTED", "output": str(out)}
        elif args.command == "register":
            if not args.candidate:
                raise ValueError("register requires --candidate")
            result = register(args.candidate, roots, args.expected_record_sha)
        else:
            rows = []; terms = args.query.lower().split()
            for folder in folders():
                record = load_pattern(folder)
                text = " ".join([record["id"], record["title"], record["family"]] + record["tags"]).lower()
                score = sum(term in text for term in terms)
                if args.command == "search" and terms and score == 0:
                    continue
                row = inspect_pattern(folder, roots, context); row["match_score"] = score; rows.append(row)
            rows.sort(key=lambda r: (-r["match_score"], r["id"]))
            if args.command == "search":
                if args.limit < 1:
                    raise ValueError("Search limit must be positive")
                rows = rows[:args.limit]
            if args.command in {"inspect", "update"} and not args.output:
                raise ValueError("Inspection/update requires a new output directory")
            if args.output:
                out = new_output(args.output)
                report(out, "知识更新检查" if args.command == "update" else "约束知识检查", rows, "record.json、cases.json及已映射来源文件")
                if args.command == "update":
                    changed = [r for r in rows if r["freshness"]["state"] == "STALE"]
                    write(out / "relearning-plan.json", {"state": "REVIEW_REQUIRED", "affected_patterns": changed,
                          "instruction": "Re-extract affected formulas and assumptions, add regression evidence, increment versions and preserve old snapshots. Do not merely refresh hashes."})
            result = {"patterns": len(rows), "fixture_cases": sum(len(r["tests"]) for r in rows),
                      "untested_patterns": sum(not r["tests"] for r in rows),
                      "all_local_tests_passed": all(t["passed"] for r in rows for t in r["tests"]), "results": rows}
        console = result
        if not args.verbose and "results" in result:
            console = dict(result)
            console["results"] = [{"id": r["id"], "card": r["card"], "use": r["use"],
                "freshness": r["freshness"]["state"], "applicability": r["applicability"],
                "local_tests_passed": r["tests_passed"]} for r in result["results"]]
        print(json.dumps(console, ensure_ascii=False, indent=2))
        return 0 if result.get("all_local_tests_passed", True) else 1
    except (ValueError, OSError, KeyError, TypeError, json.JSONDecodeError) as error:
        print("ERROR: " + str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
