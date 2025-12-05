import os
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DOC_FILES = [ROOT / ".bash_aliases", ROOT / ".bash_functions"]


FUNC_RE = re.compile(r"^\s*(?:function\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*\(\)?\s*\{")
ALIAS_RE = re.compile(r"^\s*alias\s+([A-Za-z_][A-Za-z0-9_]*)=")


def parse_doc_block(lines, kind: str, default_name: str):
    """Return (tag, desc, display_name) from a block of ##! lines."""
    cleaned = []
    for line in lines:
        stripped = re.sub(r"^\s*##!\s*", "", line).rstrip()
        cleaned.append(stripped)

    first_idx = next((i for i, line in enumerate(cleaned) if line.strip()), 0)
    tag = ""
    doc_name = ""
    if cleaned and cleaned[first_idx].startswith("["):
        match = re.match(r"\[([^\]]+)\]\s*(.*)", cleaned[first_idx])
        if match:
            tag = match.group(1).strip()
            doc_name = match.group(2).strip()
            cleaned[first_idx] = doc_name

    desc = ""
    for line in cleaned[first_idx:]:
        if re.match(r"^\s*Desc:\s*", line, re.IGNORECASE):
            desc = re.sub(r"^\s*Desc:\s*", "", line, flags=re.IGNORECASE).strip()
            break
    if not desc:
        for line in cleaned[first_idx:]:
            candidate = re.sub(r"^\s*Desc:\s*", "", line, flags=re.IGNORECASE).strip()
            if candidate:
                desc = candidate
                break

    if not tag:
        tag = kind
    if not desc:
        desc = "(no docs)"
    display_name = default_name or doc_name or "(unknown)"
    return tag, desc, display_name


def collect_expected():
    expected = {}
    for path in DOC_FILES:
        pending = []
        for line in path.read_text().splitlines():
            if line.lstrip().startswith("##!"):
                pending.append(line)
                continue

            func_match = FUNC_RE.match(line)
            alias_match = ALIAS_RE.match(line)
            if func_match:
                name = func_match.group(1)
                tag, desc, display = parse_doc_block(pending, "function", name)
                expected[display] = (tag, desc)
                pending = []
                continue

            if alias_match:
                name = alias_match.group(1)
                tag, desc, display = parse_doc_block(pending, "alias", name)
                expected[display] = (tag, desc)
                pending = []
                continue

        pending = []
    return expected


def collect_actual():
    cmd = "source ~/.dot/.bash_import && iforgot"
    result = subprocess.run(
        ["bash", "-lc", cmd],
        check=True,
        capture_output=True,
        text=True,
        env={**os.environ, "HOME": str(Path.home())},
    )
    actual = {}
    for line in result.stdout.splitlines():
        if not line.strip() or line.startswith("Available helpers"):
            continue
        parts = line.split(None, 2)
        if len(parts) < 3:
            raise AssertionError(f"Unexpected iforgot line format: {line!r}")
        tag, name, desc = parts[0], parts[1], parts[2].strip()
        actual[name] = (tag, desc)
    return actual


def main():
    expected = collect_expected()
    actual = collect_actual()

    missing = expected.keys() - actual.keys()
    extra = actual.keys() - expected.keys()
    mismatched = {
        name: (expected[name], actual[name])
        for name in expected.keys() & actual.keys()
        if expected[name] != actual[name]
    }

    problems = []
    if missing:
        problems.append(f"Missing entries in iforgot: {sorted(missing)}")
    if extra:
        problems.append(f"Unexpected entries from iforgot: {sorted(extra)}")
    if mismatched:
        detail = "; ".join(
            f"{name}: expected {exp} got {got}" for name, (exp, got) in mismatched.items()
        )
        problems.append(f"Mismatched tags/descriptions: {detail}")

    if problems:
        raise AssertionError(" ; ".join(problems))


if __name__ == "__main__":
    main()
