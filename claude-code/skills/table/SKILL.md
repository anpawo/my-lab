---
name: table
description: État d'un projet en un seul tableau à icônes — ✅ fait / 🟠 en cours / ❌ à faire ou cassé. Déclencheurs : "/table", "table todo", "what works and what doesn't", "où on en est", "status table".
---

# table

Un seul tableau markdown, rien d'autre. Pas de phrase avant, pas de phrase après, pas de « next steps ».

| Colonne | Contenu |
|---|---|
| Item | nom court de la pièce (fichier, feature, démarche) |
| Status | `✅` fait et vérifié · `🟠` en cours / pas encore branché / non vérifié · `❌` à faire, cassé, ou bloqué |
| Note | ≤ 8 mots : ce qui manque ou ce qui bloque. Vide si ✅ |

Règles :
- Lire l'état réel (fichiers, tests, logs, process) avant d'écrire ; jamais depuis la mémoire de la conversation seule.
- `✅` seulement si vérifié dans la session (test vert, sortie vue). Écrit mais jamais exécuté = `🟠`.
- Trier : ❌ en haut, puis 🟠, puis ✅.
- Une ligne par pièce, pas de sous-tableaux, pas de sections. Si l'utilisateur donne un périmètre (`/table recon-v3`), s'y tenir.
