#!/usr/bin/env python3
"""Pre-approve the Claude Code trust dialog for everything under $HOME.

Claude Code stores trust per-directory in ~/.claude.json under
projects["<path>"].hasTrustDialogAccepted. Trust is inherited by subdirectories,
but the lookup stops at the enclosing git repo root -- so every git repo needs
its own entry. This script trusts $HOME (covering all non-git paths) plus every
git repo found beneath it.

Run manually, or let the SessionStart hook in ~/.claude/settings.json run it.
"""
import json
import os
import shutil
import subprocess
import time

HOME = os.path.expanduser("~")
CFG = os.path.join(HOME, ".claude.json")
MAX_DEPTH = "7"

# Directory names never worth walking into.
PRUNE = [
    "Library", "Applications", ".Trash", "node_modules", ".venv", "venv",
    ".cache", "Pictures", "Music", "Movies", ".npm", ".cargo", ".rustup",
    "site-packages", ".pyenv", "Containers",
]

DEFAULT_ENTRY = {
    "allowedTools": [],
    "mcpContextUris": [],
    "mcpServers": {},
    "enabledMcpjsonServers": [],
    "disabledMcpjsonServers": [],
    "hasTrustDialogAccepted": True,
    "projectOnboardingSeenCount": 0,
    "hasClaudeMdExternalIncludesApproved": False,
    "hasClaudeMdExternalIncludesWarningShown": False,
}


def git_repos():
    cmd = ["find", HOME, "-maxdepth", MAX_DEPTH]
    for name in PRUNE:
        cmd += ["-name", name, "-prune", "-o"]
    cmd += ["-name", ".git", "-print"]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    return [os.path.dirname(p) for p in out.split("\n") if p.strip()]


def main():
    with open(CFG) as f:
        cfg = json.load(f)
    projects = cfg.setdefault("projects", {})

    added = []
    for path in [HOME] + sorted(set(git_repos())):
        entry = projects.get(path)
        if entry is None:
            projects[path] = dict(DEFAULT_ENTRY)
            added.append(path)
        elif not entry.get("hasTrustDialogAccepted"):
            entry["hasTrustDialogAccepted"] = True
            added.append(path)

    if not added:
        return

    shutil.copy(CFG, CFG + ".bak-" + time.strftime("%Y%m%d-%H%M%S"))
    tmp = CFG + ".tmp"
    with open(tmp, "w") as f:
        json.dump(cfg, f, indent=2)
    os.replace(tmp, CFG)

    print(f"trusted {len(added)} new folder(s):")
    for path in added:
        print("  +", path)


if __name__ == "__main__":
    main()
