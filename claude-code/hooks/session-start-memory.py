#!/usr/bin/env python3
"""SessionStart hook: inject this project's MEMORY.md and the global memory index.

Runs once per session start (startup, resume, clear), so it needs no de-duplication
guard of its own — the events it fires on are exactly the moments the context was
either empty or just discarded.
"""
import json
import os
import sys
from pathlib import Path

MAX_PROJECT_LINES = 200


def project_memory_path(project_dir: str, home: Path) -> Path:
    """Map a project directory to its ~/.claude/projects key.

    /Users/you/Projects/foo -> -Users-you-Projects-foo (leading dash kept).
    """
    mapped = project_dir.replace('/', '-').replace('.', '-')
    return home / '.claude' / 'projects' / mapped / 'memory' / 'MEMORY.md'


def build_context() -> str:
    project_dir = os.environ.get('CLAUDE_PROJECT_DIR', os.getcwd())
    home = Path.home()

    memory_file = project_memory_path(project_dir, home)
    global_idx = home / '.claude' / 'memory' / 'memory.md'

    parts = []

    if memory_file.exists():
        lines = memory_file.read_text().splitlines()[:MAX_PROJECT_LINES]
        parts.append(f"=== Project Memory: {project_dir} ===\n" + '\n'.join(lines))
    else:
        parts.append(f"(no project MEMORY.md at {memory_file})")

    if global_idx.exists():
        parts.append("=== Global Memory Index ===\n" + global_idx.read_text())

    return '\n\n'.join(parts)


def main():
    # A hook that throws takes the session start banner with it, and missing memory is
    # not worth that: on any failure, emit nothing and let the session proceed.
    try:
        context = build_context()
    except Exception as exc:  # noqa: BLE001 - deliberately broad, see above
        print(f"memory hook skipped: {exc}", file=sys.stderr)
        sys.exit(0)

    output = {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": context,
        }
    }

    print(json.dumps(output))
    sys.exit(0)


if __name__ == "__main__":
    main()
