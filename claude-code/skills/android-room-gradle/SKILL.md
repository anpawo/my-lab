---
name: android-room-gradle
description: >
  Verified traps of the Android/Gradle build and of Room on this machine (my-hub). Load as soon
  as you compile an Android project, touch KSP/Room or a database migration, or see an
  unexplained Kotlin build error. Triggers: "ksp", "Room", "migration",
  "gradle build", "KotlinCompileDaemon", "IllegalArgumentException: 26.0.1", "Migration didn't
  properly handle", "Expected/Found".
---

# Android / Gradle / Room — what breaks on this machine

Two families of traps, all measured on my-hub. Each one looks like a code error in whatever
was just edited, while the cause lies elsewhere (the daemon's JDK, a migration).

## KSP dies on Homebrew's JDK 26

Room's KSP processor dies with `e: [ksp] java.lang.IllegalArgumentException: 26.0.1`. The
message **names no file** → it looks like an error in the edited code. brew's `gradle` runs on
JDK 26 by default; my-hub needs a 17.
- **Fixed** machine-wide in `~/.gradle/gradle.properties`:
  `org.gradle.java.home=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`
  (not in the repo: it is this Mac's path; CI installs its own 17 via `setup-java`).
  `tools/release.sh` already exports that JDK.
- **The daemon's JDK decides, not the env variable.** `JAVA_HOME=<17>` is enough **if the
  daemon is fresh**. A daemon left warm on 26 gets reused and fails whatever you export,
  and a `KotlinCompileDaemon` **survives `gradle --stop`**. So, facing an unexplained `26.0.1`:
  `gradle --stop` **and** `pkill -f KotlinCompileDaemon`, then run again.
- **`jvmToolchain(17)` does NOT fix this bug** (measured): the toolchain only sets the
  compilation target; the Kotlin 1.9 daemon follows Gradle's JVM. Drop it from the list of
  leads; moving to Kotlin 2.x should make all of this moot.

## Room: index created by a migration but not declared on the entity = crash at launch

An `ALTER TABLE` + `CREATE INDEX` in a `Migration` **without** adding the same `Index(...)` to
the `@Entity`'s `indices` fails the post-migration validation:
`IllegalStateException: Migration didn't properly handle: <table>`, with an Expected/Found where
only the `indices=[...]` list differs. Room re-reads every `index_*` index and compares.
- **Invisible on a fresh install**: `createAllTables` starts from the entity, no migration
  runs. Only phones that **migrate** crash → a build "tested on the emulator" can ship
  the crash.
- **Reproducing a real migration** with no device and no exported schemas: build the database
  at the old version with `sqlite3` (DDL copyable from `<Db>_Impl.java` under
  `build/generated/ksp/`, minus the columns added since, + `PRAGMA user_version=<n>`), then:
  ```
  adb push base /data/local/tmp/x.db
  adb shell run-as <pkg> sh -c 'cp /data/local/tmp/x.db databases/<name>.db'
  # read back: adb exec-out run-as <pkg> cat databases/<name>.db > local.db
  ```
  (run-as cannot write to /data/local/tmp). Launch, then
  `adb logcat -d | grep -c "FATAL EXCEPTION"`.
- Make the `ALTER`s replayable (`runCatching`): an `onUpgrade` that fails validation sometimes
  leaves the column in place, and the fixed build would crash on "duplicate column". No risk:
  Room validates right after, a genuinely broken migration still fails there.

## Environment reminder (see memory)

Prefix every command with an explicit `cd <project>`: the Bash shell's cwd persists from one
call to the next, and several Claude sessions sometimes fight over the same repo.
