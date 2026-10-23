"""Automatic-learning policy, with structural evidence and local preferences.

The Agent recognizes semantics and writes an assessment. This module checks
its coverage and source bindings; it is not an arbitrary-code model classifier.
It never treats a model family as proof that its equations are correct.
"""
import hashlib
import json
import os
from pathlib import Path

SKILL = Path(__file__).resolve().parents[1]
CHOICES = ["本次学习", "以后默认都自动学习", "本次不学习"]


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def preference_path(explicit=None):
    if explicit:
        return Path(explicit).expanduser()
    home = Path(os.environ["CODEX_HOME"]) if os.environ.get("CODEX_HOME") else Path.home() / ".codex"
    return home / "power-system-model-audit" / "preferences.json"


def preferences(explicit=None, nonclassic=None):
    path = preference_path(explicit)
    value = {"schema_version": 1, "nonclassic_learning": "ask"}
    if path.exists():
        value = json.loads(path.read_text(encoding="utf-8"))
        if value.get("schema_version") != 1 or value.get("nonclassic_learning") not in {"ask", "auto", "never"}:
            raise ValueError("Invalid local preference; do not silently enable automatic learning")
    if nonclassic is not None:
        if nonclassic not in {"ask", "auto", "never"}:
            raise ValueError("Unknown preference")
        value = {"schema_version": 1, "nonclassic_learning": nonclassic}
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_name(path.name + ".tmp")
        temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        temporary.replace(path)
    return value


def contained(root, relative):
    part = Path(relative)
    if part.is_absolute() or ".." in part.parts or "\\" in relative or ":" in relative:
        raise ValueError("Source evidence requires a contained relative path")
    result = (Path(root) / part).resolve()
    if not result.is_relative_to(Path(root).resolve()):
        raise ValueError("Source evidence escapes the model root")
    return result


def classify(assessment, source_root):
    catalog = json.loads((SKILL / "references/model-family-catalog.json").read_text(encoding="utf-8"))["families"]
    if assessment.get("schema_version") != 1:
        raise ValueError("Unknown assessment schema")
    components = assessment.get("components")
    if not isinstance(components, list) or not components:
        raise ValueError("A model assessment requires explicit component coverage")
    issues = []; known = []; unfamiliar = []; dependencies = []
    if assessment.get("coverage_complete") is not True or assessment.get("unresolved_structure") is not False:
        issues.append("组件覆盖或结构尚未确认")
    novelty = assessment.get("novel_components")
    if not isinstance(novelty, list) or any(not isinstance(x, str) or not x.strip() for x in novelty):
        issues.append("必须显式列出新增机制，无新增时使用空列表")
        novelty = []
    ids = set()
    for component in components:
        identifier = component.get("id")
        if not isinstance(identifier, str) or not identifier or identifier in ids:
            raise ValueError("Each component requires a unique identifier")
        ids.add(identifier)
        family = component.get("family")
        if family not in catalog:
            unfamiliar.append(identifier)
        required = set(catalog[family]["roles"]) if family in catalog else set()
        roles = set(); active = False; valid = True
        evidence = component.get("evidence", [])
        if not isinstance(evidence, list):
            raise ValueError("Evidence must be an array")
        for item in evidence:
            try:
                path = contained(source_root, item["path"])
                first, last = item["first_line"], item["last_line"]
                if (type(first) is not int or type(last) is not int or first < 1 or last < first
                        or not isinstance(item.get("meaning"), str) or not item["meaning"].strip()
                        or item.get("kind") not in {"active_code", "specification", "data_definition"}):
                    raise ValueError("Incomplete structural evidence")
                if not path.is_file() or digest(path) != item["sha256"]:
                    raise ValueError("Structural source changed or unavailable")
                lines = path.read_text(encoding="utf-8").splitlines()
                if last > len(lines) or not "".join(lines[first-1:last]).strip():
                    raise ValueError("Evidence line range unavailable")
                roles.add(item["role"])
                active |= item["kind"] == "active_code"
                dependencies.append({"path": item["path"], "sha256": item["sha256"]})
            except (KeyError, ValueError, OSError, UnicodeError, TypeError):
                valid = False
        if valid and active and required.issubset(roles) and family in catalog:
            known.append(identifier)
        elif not valid or not active or not required.issubset(roles):
            issues.append(identifier + "：经典模型结构证据不充分或已过期")
    if issues:
        kind = "UNCERTAIN"
    elif unfamiliar or novelty:
        kind = "HYBRID" if known else "NONCLASSIC"
    else:
        kind = "CLASSIC"
    return {"classification": kind, "known_components": known, "unfamiliar_components": unfamiliar,
            "novel_components": novelty, "issues": issues, "dependencies": dependencies}


def automatic_plan(assessment, source_root, preference_file=None, decision=None):
    recognition = classify(assessment, source_root)
    prefs = preferences(preference_file)
    if decision not in {None, "learn-once", "always", "skip"}:
        raise ValueError("Unknown current user decision")
    if decision == "always":
        prefs = preferences(preference_file, "auto")
    if decision == "skip":
        action = "SKIP"
    elif decision in {"learn-once", "always"}:
        action = "AUTO_LEARN"
    elif recognition["classification"] == "CLASSIC":
        action = "AUTO_LEARN"
    elif prefs["nonclassic_learning"] == "auto":
        action = "AUTO_LEARN"
    elif prefs["nonclassic_learning"] == "never":
        action = "SKIP"
    else:
        action = "ASK_USER"
    result = {"schema_version": 1, **recognition, "action": action,
              "nonclassic_preference": prefs["nonclassic_learning"],
              "current_user_decision": decision, "source_root": str(Path(source_root).resolve()),
              "preference_file": str(preference_path(preference_file).resolve()),
              "assessment": assessment,
              "learning_means": "Agent extracts and reviews locally; snapshots alone are not learning",
              "automatic_confirmation_of_correctness": False}
    if action == "ASK_USER":
        result["question"] = "这个模型含非经典或尚未确认的结构，是否把可复用约束加入知识库？"
        result["options"] = CHOICES
        result["known_components_may_be_learned_separately"] = recognition["known_components"]
    return result


def require_automatic_permission(plan):
    if plan.get("schema_version") != 1 or plan.get("action") != "AUTO_LEARN":
        raise ValueError("Automatic learning is pending user choice or was skipped")
    # Plans are workflow records, not security tokens. Recompute classification
    # from bound source evidence so an old CLASSIC plan cannot silently persist.
    recognition = classify(plan["assessment"], plan["source_root"])
    if recognition["classification"] != plan["classification"] or recognition["dependencies"] != plan["dependencies"]:
        raise ValueError("Model evidence changed; recompute the automatic-learning plan")
    if (plan["classification"] != "CLASSIC" and plan.get("current_user_decision") != "learn-once"
            and preferences(plan["preference_file"])["nonclassic_learning"] != "auto"):
        raise ValueError("Nonclassic learning has no affirmative decision or stored preference")
    return recognition
