#!/usr/bin/env python3
"""Rebuilds the end of README.md: one fold per app, holding a copy of that app's README."""
import re
from pathlib import Path

root = Path(__file__).parent
START, END = "<!-- apps:start -->", "<!-- apps:end -->"


def fold(readme):
    app = readme.parent.name
    # Links and pictures in an app's README are relative to its own folder.
    body = re.sub(r"\]\((?![a-z]+:|#|/)", f"]({app}/", readme.read_text())
    return f"<details>\n<summary><b>{app}</b></summary>\n\n{body.strip()}\n\n</details>"


page = root / "README.md"
head, rest = page.read_text().split(START)
folds = "\n\n".join(fold(r) for r in sorted(root.glob("*/README.md")))
page.write_text(f"{head}{START}\n{folds}\n{END}{rest.split(END)[1]}")
