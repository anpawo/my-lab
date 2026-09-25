---
name: swift-macos
description: >
  Pièges vérifiés de la toolchain Swift/macOS SANS Xcode (Command Line Tools seuls) et du
  fenêtrage macOS, sur cette machine. Charger dès qu'on écrit, compile, teste ou signe du
  Swift/AppKit/Carbon, qu'on lit un titre ou une géométrie de fenêtre, qu'on capture l'écran,
  ou qu'on veut un retour visuel d'une app GUI (AppKit, Qt/QML). Projets concernés : alt-tab,
  vane, fleet, video-code. Déclencheurs : "swift test", "codesign", "titre de fenêtre",
  "screencapture", "ouvrir la fenêtre pour vérifier", "Space"/"bureau", WindowRef, TCC.
---

# Swift & macOS sans Xcode — ce qui casse en silence

Xcode n'est **pas** installé, seulement les Command Line Tools. Tout ce qui suit en découle,
et chaque point a été mesuré ici, pas lu. Le fil rouge : ces pièges **réussissent sans erreur**
(exit 0, sortie vide, chaîne vide) et se lisent comme un bug dans le code qu'on vient d'écrire.

## `swift test` est un vert silencieux, pas un run

`swift test` compile un bundle `.xctest` et **sort 0 sans rien exécuter** : XCTest vient avec
Xcode, pas avec les CLT, donc rien ne charge le bundle. `swift test list` est vide aussi.
- **Faire :** un `executableTarget` lancé par `swift run check`. Zéro dépendance, headless,
  échoue fort. Précédent : `app/alt-tab/Sources/check`.
- swift-testing est présent (`…/CommandLineTools/…/Testing.framework`) mais son **runner**
  manque — le lier n'achète rien.

## `WindowRef` est un typedef Carbon

Un target qui importe Carbon (`Carbon.HIToolbox`, pour `RegisterEventHotKey`) ne peut pas aussi
définir un type nommé `WindowRef` : Quickdraw le typedef encore, chaque usage devient "ambiguous
for type lookup". Même piège pour les autres noms de l'ère Quickdraw — renommer le type local.

## Un titre de fenêtre coûte toujours une autorisation TCC

Le chemin privé `CGSCopyWindowProperty(cid, wid, "kCGSWindowTitle")` est gaté **exactement comme**
le public `kCGWindowName` sur macOS 26.5 : depuis un `.app` signé sans Accessibilité ni Screen
Recording, il renvoie `kCGErrorSuccess` et une **chaîne vide** pour toute fenêtre. Le "truc des
titres sans permission" qui circule dans les repos de switchers est mort ici.
- Les titres coûtent Accessibilité (`kAXTitleAttribute`) ou Screen Recording (`kCGWindowName`) —
  choisir **lequel**, pas **si**. Sonde de 60 lignes de C rejouable dans l'historique d'`alt-tab`.

## Une fenêtre minimisée change de sous-rôle AX

Une fenêtre minimisée (ou d'app masquée) répond `kAXSubroleAttribute` = **`AXDialog`**, pas
`AXStandardWindow`. La règle "le sous-rôle standard est tout le filtre" rend donc les fenêtres
minimisées structurellement invisibles à un switcher, et ça ressemble à AX qui ne les reporte pas.
Il les reporte : `kAXWindowsAttribute` les liste, `_AXUIElementGetWindow` donne un id valide,
`CGSCopySpacesForWindows` donne encore leur Space. Elles sont absentes de
`CGWindowListCopyWindowInfo(.optionOnScreenOnly)` ; `.optionAll` les a mais les noie sous ~80
surfaces offscreen — **AX est la seule source utilisable**. Confirmé macOS 26.5, Firefox + app Swift.

## Signer déclenche des dialogues GUI qui bloquent un shell non-interactif

`security add-trusted-cert` et le premier `codesign` avec une identité fraîche lèvent des
**dialogues mot de passe** qui bloquent un shell non-interactif pour toujours. Un agent ne passe
pas ; **c'est à Marius de lancer `./make-signing-identity.sh`**. L'identité s'importe sans l'étape
de confiance, mais `codesign` prompte quand même.
- Les défauts PKCS#12 d'OpenSSL moderne (AES-256/PBES2) sont rejetés par `SecKeychainItemImport` :
  `-certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1` + mot de passe **non vide** requis.
  Script qui marche : `app/alt-tab/make-signing-identity.sh`.

## `screencapture` sur session verrouillée rend le fond d'écran, sans rien dire

`screencapture -x shot.png` **réussit** (exit 0, PNG de 7,7 Mo, aucun message) écran verrouillé.
Le fichier ne contient que le papier peint : ni fenêtres, ni **barre de menus** — l'absence de
barre de menus est le seul signe. Ça se lit comme "écran vide" ou "app sans fenêtre".
- **Ne pas conclure "permission manquante"** : réflexe faux ici. Distinguer en une commande —
  `swift -e 'import CoreGraphics; print(CGPreflightScreenCaptureAccess())'` (lecture seule).
  Verrou : `ioreg -n Root -d1 -a | grep -A1 CGSSessionScreenIsLocked`.
- La permission se donne à l'**app hôte du terminal** (remonter `ps -o ppid=,comm=`), pas à
  `claude` ni `screencapture`.
- Corollaire pilotage depuis le téléphone : le Mac est verrouillé la plupart du temps → **aucune
  capture possible sans déverrouillage**.

## Ne pas ouvrir de fenêtre pour vérifier — rendre ≠ afficher

macOS n'a **aucune API publique** pour ouvrir une fenêtre sur un Space choisi.
`NSWindow.collectionBehavior` ne sait que "sur tous les bureaux" ou "suis-moi", jamais "bureau 3".
Y arriver demande SkyLight/CGS privé + SIP désactivé (c'est pourquoi yabai s'injecte dans le Dock).
Donc **une fenêtre ouverte par un agent atterrit sur le bureau où Marius travaille** et lui coupe
son travail. La règle dure est dans `~/.claude/CLAUDE.md` ("Aucune fenêtre pour tester") ; voici le
**comment** obtenir des pixels sans afficher :
- **Qt/QML** : `QQuickWindow::grabWindow()` sur une fenêtre **créée et jamais montrée** renvoie une
  image complète (mesuré video-code : 2880×1800 non nulle). Le scene graph dessine, le compositeur
  n'est pas sollicité. `QQuickRenderControl` est la voie documentée si le chemin court lâche.
  Piège : `visible:` **et** `visibility:` sur un `ApplicationWindow` est un conflit tranché dans un
  ordre non spécifié — dire la visibilité avec `visibility:` seul.
- **AppKit** : rendre la vue dans un bitmap (`bitmapImageRepForCachingDisplay` /
  `cacheDisplay(in:)`) sans `makeKeyAndOrderFront`.
- Si aucun chemin sans fenêtre n'existe pour ce qu'il faut voir : **le dire et demander**.
