---
name: android-room-gradle
description: >
  Pièges vérifiés du build Android/Gradle et de Room sur cette machine (my-hub). Charger dès
  qu'on compile un projet Android, qu'on touche à KSP/Room, à une migration de base, ou qu'on
  voit une erreur de build Kotlin inexpliquée. Déclencheurs : "ksp", "Room", "migration",
  "gradle build", "KotlinCompileDaemon", "IllegalArgumentException: 26.0.1", "Migration didn't
  properly handle", "Expected/Found".
---

# Android / Gradle / Room — ce qui casse sur cette machine

Deux familles de pièges, tous mesurés sur my-hub. Chacun se présente comme une erreur de code
dans ce qu'on vient d'éditer alors que la cause est ailleurs (le JDK du daemon, une migration).

## KSP meurt sur le JDK 26 de Homebrew

Le processeur KSP de Room meurt avec `e: [ksp] java.lang.IllegalArgumentException: 26.0.1`. Le
message **ne nomme aucun fichier** → ça ressemble à une erreur dans le code édité. Le `gradle` de
brew tourne sur le JDK 26 par défaut ; my-hub a besoin d'un 17.
- **Réglé** au niveau machine dans `~/.gradle/gradle.properties` :
  `org.gradle.java.home=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`
  (pas dans le repo : chemin de ce Mac ; la CI installe son 17 via `setup-java`).
  `tools/release.sh` exporte déjà ce JDK.
- **C'est le JDK du daemon qui décide, pas la variable d'env.** `JAVA_HOME=<17>` suffit **si le
  daemon est frais**. Un daemon resté chaud sur le 26 est réutilisé et échoue quoi qu'on exporte,
  et un `KotlinCompileDaemon` **survit à `gradle --stop`**. Donc devant un `26.0.1` inexplicable :
  `gradle --stop` **et** `pkill -f KotlinCompileDaemon`, puis relancer.
- **`jvmToolchain(17)` ne corrige PAS ce bug** (mesuré) : la toolchain ne fixe que la cible de
  compilation ; le daemon Kotlin 1.9 suit la JVM de Gradle. À retirer des pistes ; le passage à
  Kotlin 2.x devrait rendre tout ça caduc.

## Room : index créé par migration mais non déclaré dans l'entité = crash au lancement

Un `ALTER TABLE` + `CREATE INDEX` dans une `Migration` **sans** ajouter le même `Index(...)` aux
`indices` de l'`@Entity` fait échouer la validation post-migration :
`IllegalStateException: Migration didn't properly handle: <table>`, avec Expected/Found où seule
la liste `indices=[...]` diffère. Room relit tous les index `index_*` et compare.
- **Invisible en installation neuve** : `createAllTables` part de l'entité, aucune migration ne
  tourne. Seuls les téléphones qui **migrent** plantent → un build "testé sur l'émulateur" peut
  expédier le crash.
- **Reproduire une vraie migration** sans device ni schémas exportés : fabriquer la base à
  l'ancienne version avec `sqlite3` (DDL copiable depuis `<Db>_Impl.java` sous
  `build/generated/ksp/`, moins les colonnes ajoutées depuis, + `PRAGMA user_version=<n>`), puis :
  ```
  adb push base /data/local/tmp/x.db
  adb shell run-as <pkg> sh -c 'cp /data/local/tmp/x.db databases/<name>.db'
  # relire : adb exec-out run-as <pkg> cat databases/<name>.db > local.db
  ```
  (run-as ne peut pas écrire dans /data/local/tmp). Lancer, puis
  `adb logcat -d | grep -c "FATAL EXCEPTION"`.
- Rendre les `ALTER` rejouables (`runCatching`) : un `onUpgrade` qui échoue à la validation laisse
  parfois la colonne posée, et le build correctif planterait sur "duplicate column". Sans risque :
  Room valide juste après, une vraie migration cassée échoue toujours là.

## Rappel environnement (voir mémoire)

Préfixer chaque commande d'un `cd <projet>` explicite : le cwd du shell Bash persiste d'un appel à
l'autre, et plusieurs sessions Claude se disputent parfois le même dépôt.
