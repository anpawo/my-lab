#!/usr/bin/env python3
"""UserPromptSubmit: warns when the session's context crosses a threshold.

In absolute tokens, not as a percentage of the window: on 1M, 402k shows as
"40%" and looks healthy, while attention quality drops off well before that —
attention is quadratic, the threshold is absolute, not a fraction of the model.

One warning per threshold crossed (state in /tmp), reset when the context drops
back under the first threshold — so after a /clear or a compaction.
"""
import json, os, sys

STEPS = [100_000, 200_000, 400_000, 600_000, 800_000]
TAIL = 1 << 20  # the last MB of the transcript is enough to find a usage block


def ctx_tokens(path):
    try:
        with open(path, "rb") as fh:
            fh.seek(0, 2)
            start = max(0, fh.tell() - TAIL)
            fh.seek(start)
            lines = fh.read().decode("utf-8", "ignore").split("\n")
            if start:
                del lines[0]  # line truncated by the seek, only if we skipped ahead
    except OSError:
        return 0
    for line in reversed(lines):
        if '"usage"' not in line:
            continue
        try:
            usage = (json.loads(line).get("message") or {}).get("usage")
        except (ValueError, AttributeError):
            continue
        if usage:
            return sum(usage.get(k) or 0 for k in (
                "input_tokens", "cache_read_input_tokens",
                "cache_creation_input_tokens"))
    return 0


def state_path(session_id):
    return "/tmp/cc-ctx-" + "".join(
        c for c in str(session_id) if c.isalnum() or c in "-_")[:64]


def main():
    try:
        event = json.load(sys.stdin)
    except ValueError:
        return
    path = event.get("transcript_path")
    if not path or not os.path.exists(path):
        return

    n = ctx_tokens(path)
    marker = state_path(event.get("session_id", "unknown"))
    try:
        seen = int(open(marker).read().strip() or 0)
    except (OSError, ValueError):
        seen = 0

    if n < STEPS[0]:
        if seen:
            try:
                os.remove(marker)
            except OSError:
                pass
        return

    step = max(s for s in STEPS if n >= s)
    if seen >= step:
        return
    try:
        with open(marker, "w") as fh:
            fh.write(str(step))
    except OSError:
        pass

    print("[context] This session holds ~%dk tokens. Beyond roughly 100k, attention "
          "quality drops whatever the model and whatever the window size. If the "
          "topic has changed since the start: /clear. Otherwise, ignore this "
          "reminder — it will only come back at the next threshold "
          "(100k / 200k / 400k / 600k / 800k)." % (n // 1000))


main()
