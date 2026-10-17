#!/usr/bin/env python3
"""Validate Agent Skills against the official best-practices limits.

Usage: check-skill.py <skill-dir>...   validate (exit 1 on any failure)
       check-skill.py --all            validate ~/.claude/skills/*, print count and token cost
       check-skill.py --audit          warn on risky content in ~/.claude/skills/* (scripts, network, secrets)

Read-only, stdlib only, no network. Run with `python3 -I`.
"""
import re
import sys
from pathlib import Path

ROOT = Path.home() / ".claude" / "skills"
LINK = re.compile(r"\]\(([^)#\s]+)")
AUDIT = {
    "network": re.compile(r"https?://|\bcurl\b|\bwget\b|\bfetch\(|\brequests\.", re.I),
    "path escape": re.compile(r"\.\./|~/\.ssh|/etc/"),
    "secret": re.compile(r"\bsk-[A-Za-z0-9]{16,}|\bghp_[A-Za-z0-9]{16,}|api[_-]?key\s*[=:]\s*\S{8,}", re.I),
    "manipulation": re.compile(r"ignore (all )?previous|do not tell the user|don't tell the user", re.I),
}


def frontmatter(text):
    m = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None
    out = {}
    for line in m.group(1).split("\n"):
        k, _, v = line.partition(":")
        if _ and not line.startswith(" "):
            out[k.strip()] = v.strip().strip("\"'")
    return out


def check(d):
    errs = []
    skill = d / "SKILL.md"
    if not skill.is_file():
        return [f"{d}: SKILL.md missing"], None
    text = skill.read_text()
    fm = frontmatter(text)
    if fm is None:
        return [f"{d.name}: frontmatter missing"], None
    name, desc = fm.get("name", ""), fm.get("description", "")
    if name != d.name or not re.fullmatch(r"[a-z0-9-]{1,64}", name):
        errs.append(f"{d.name}: name '{name}' must equal the directory and match [a-z0-9-]{{1,64}}")
    if re.search(r"anthropic|claude", name):
        errs.append(f"{d.name}: name contains a reserved word")
    if not desc or len(desc) > 1024:
        errs.append(f"{d.name}: description must be 1-1024 chars (is {len(desc)})")
    if re.search(r"[<>]", desc):
        errs.append(f"{d.name}: description contains < or >")
    if len(text.split("\n")) > 500:
        errs.append(f"{d.name}: SKILL.md over 500 lines")
    mds = [p for p in d.rglob("*.md")]
    for p in mds:
        t = p.read_text()
        rel = p.relative_to(d)
        if p.name != "SKILL.md" and len(t.split("\n")) > 100 and "## Contents" not in t:
            errs.append(f"{d.name}/{rel}: over 100 lines without '## Contents'")
        for link in LINK.findall(t):
            if "://" in link or link.startswith("mailto:"):
                continue
            target = (p.parent / link).resolve()
            if not target.exists():
                errs.append(f"{d.name}/{rel}: broken link {link}")
            elif p.name != "SKILL.md" and target.suffix == ".md" and d.resolve() in target.parents:
                errs.append(f"{d.name}/{rel}: links to {link}; references must be one level deep")
    return errs, len(name) + len(desc)


def audit(d):
    hits = []
    for p in d.rglob("*"):
        if not p.is_file():
            continue
        rel = p.relative_to(d)
        if p.suffix in (".py", ".sh", ".js"):
            hits.append(f"{d.name}/{rel}: executable script, read it before trusting")
        try:
            t = p.read_text()
        except UnicodeDecodeError:
            continue
        for label, rx in AUDIT.items():
            if rx.search(t):
                hits.append(f"{d.name}/{rel}: {label}")
    return hits


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    mode = argv[0]
    dirs = sorted(p for p in ROOT.iterdir() if p.is_dir()) if mode in ("--all", "--audit") else [Path(a) for a in argv]
    if mode == "--audit":
        hits = [h for d in dirs for h in audit(d)]
        print("\n".join(hits) or "no findings")
        print(f"{len(dirs)} skills audited (warnings only)")
        return 0
    failed, chars = 0, 0
    for d in dirs:
        errs, size = check(d)
        chars += size or 0
        failed += bool(errs)
        print("\n".join(errs) if errs else f"OK {d.name}")
    if mode == "--all":
        print(f"{len(dirs)} skills, ~{chars // 4} tokens of name+description per request")
    return 1 if failed else 0


sys.exit(main(sys.argv[1:]))
