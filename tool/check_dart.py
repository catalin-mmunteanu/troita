#!/usr/bin/env python3
"""Cheap static checks over lib/ and the Kotlin sources.

Not a substitute for `flutter analyze` — run that when you can. This exists to
catch the specific classes of error that keep breaking builds here, without
needing a Dart or Kotlin toolchain:

Dart:
  1. a type used in a file that never imports the file declaring it
  2. a private widget referenced but never declared in the same file
  3. unbalanced braces, parens or brackets

Kotlin:
  4. an `import ro.troita.…` pointing at a class that no longer exists

Number 4 was added after deleting Channels.kt left MainActivity importing it —
the Dart checks passed, and the failure only surfaced at compileDebugKotlin.

    python3 tool/check_dart.py
"""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"

EXTERNAL = (
    "package:flutter", "dart:", "package:sqflite", "package:intl",
    "package:permission_handler",
)


def strip_code(src: str) -> str:
    """Remove comments and string literals so we only match real code."""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                i += 1
        elif c == "/" and i + 1 < n and src[i + 1] == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                i += 1
            i += 2
        elif c in "'\"":
            q, i = c, i + 1
            while i < n and src[i] != q:
                i += 2 if src[i] == "\\" else 1
            i += 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


def declared_types() -> dict[str, pathlib.Path]:
    """Top-level types only. Methods and keywords are not top-level symbols —
    including them makes the check so noisy it stops being read."""
    found: dict[str, pathlib.Path] = {}
    for p in sorted(LIB.rglob("*.dart")):
        for m in re.finditer(
            r"^(?:abstract\s+final\s+|abstract\s+|final\s+|sealed\s+|base\s+)?"
            r"(?:class|enum|mixin)\s+([A-Z]\w*)",
            p.read_text(encoding="utf-8"), re.M,
        ):
            found[m.group(1)] = p
    return found


def reachable(p: pathlib.Path) -> set[pathlib.Path]:
    out = {p}
    for m in re.finditer(r"import\s+'([^']+)'", p.read_text(encoding="utf-8")):
        spec = m.group(1)
        if spec.startswith(EXTERNAL):
            continue
        target = (LIB / spec[len("package:troita/"):]
                  if spec.startswith("package:troita/") else p.parent / spec)
        target = target.resolve()
        if target.exists():
            out.add(target)
    return out


def check_kotlin() -> int:
    """Every `import ro.troita.…` must resolve to a declared class.

    Deleting a Kotlin file is easy; finding the imports that referenced it is
    not, because nothing outside the Kotlin compiler knows they are broken.
    """
    root = ROOT / "android" / "app" / "src" / "main" / "kotlin"
    if not root.is_dir():
        return 0

    declared: dict[str, pathlib.Path] = {}
    for p in root.rglob("*.kt"):
        package = re.search(r"^package\s+([\w.]+)", p.read_text(encoding="utf-8"), re.M)
        if not package:
            continue
        for m in re.finditer(
            r"^(?:internal\s+|private\s+|abstract\s+|open\s+|sealed\s+|data\s+)*"
            r"(?:class|object|interface|enum class)\s+(\w+)",
            p.read_text(encoding="utf-8"), re.M,
        ):
            declared[f"{package.group(1)}.{m.group(1)}"] = p

    problems = 0
    for p in sorted(root.rglob("*.kt")):
        rel = p.relative_to(ROOT).as_posix()
        for m in re.finditer(r"^import\s+(ro\.troita\.[\w.]+)", 
                             p.read_text(encoding="utf-8"), re.M):
            target = m.group(1)
            if target in declared:
                continue
            # Could be a member import, e.g. ro.troita.TroitaConfig.PREFS
            if any(target.startswith(f"{k}.") for k in declared):
                continue
            print(f"{rel}: imports {target}, which no longer exists")
            problems += 1
    return problems


def main() -> int:
    problems = check_kotlin()
    types = declared_types()

    for p in sorted(LIB.rglob("*.dart")):
        src = p.read_text(encoding="utf-8")
        code = strip_code(src)
        rel = p.relative_to(ROOT).as_posix()

        # 1. missing imports
        seen = reachable(p)
        for sym, home in sorted(types.items()):
            if home in seen:
                continue
            if re.search(rf"(?<![\w.]){re.escape(sym)}(?=\s*[.(<]|\s+\w)", code):
                print(f"{rel}: uses {sym}, declared in "
                      f"{home.relative_to(ROOT).as_posix()} — not imported")
                problems += 1

        # 2. private widgets referenced but not declared here
        local = {m.group(1) for m in re.finditer(r"^class\s+(_\w+)", src, re.M)}
        for m in re.finditer(r"\b(_[A-Z]\w*)\s*\(", code):
            if m.group(1) not in local:
                print(f"{rel}: {m.group(1)} used but not declared in this file")
                problems += 1

        # 3. balance
        for opener, closer in (("{", "}"), ("(", ")"), ("[", "]")):
            delta = code.count(opener) - code.count(closer)
            if delta:
                print(f"{rel}: unbalanced {opener}{closer} ({delta:+d})")
                problems += 1

    print("OK — no problems found" if not problems
          else f"\n{problems} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
