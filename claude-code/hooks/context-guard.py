#!/usr/bin/env python3
"""UserPromptSubmit : prévient quand le contexte de la session franchit un palier.

En tokens absolus et non en pourcentage de la fenêtre : sur 1 M, 402k s'affiche
« 40 % » et paraît sain, alors que la qualité d'attention décroche bien avant —
l'attention est quadratique, le seuil est absolu, pas une fraction du modèle.

Un seul avertissement par palier franchi (état dans /tmp), remis à zéro quand le
contexte redescend sous le premier palier — donc après un /clear ou un compactage.
"""
import json, os, sys

STEPS = [100_000, 200_000, 400_000, 600_000, 800_000]
TAIL = 1 << 20  # le dernier Mo du transcript suffit à trouver un bloc usage


def ctx_tokens(path):
    try:
        with open(path, "rb") as fh:
            fh.seek(0, 2)
            start = max(0, fh.tell() - TAIL)
            fh.seek(start)
            lines = fh.read().decode("utf-8", "ignore").split("\n")
            if start:
                del lines[0]  # ligne tronquee par le seek, seulement si on a saute
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

    print("[contexte] Cette session porte ~%dk tokens. Au-delà d'environ 100k, la "
          "qualité d'attention baisse quel que soit le modèle et quelle que soit la "
          "taille de la fenêtre. Si le sujet a changé depuis le début : /clear. "
          "Sinon, ignore ce rappel — il ne reviendra qu'au palier suivant "
          "(100k / 200k / 400k / 600k / 800k)." % (n // 1000))


main()
