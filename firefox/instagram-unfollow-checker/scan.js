// Tourne dans la page instagram.com : les requêtes sont same-origin, donc les
// cookies de session partent tout seuls. Pas de scraping du DOM — l'app web
// utilise elle-même cette API, et le modal ne charge que ce qui est scrollé.
// Le popup se ferme dès qu'il perd le focus (alt-tab) et son JS meurt avec lui.
// Le scan tourne donc ici, et le popup ne fait que lire le résultat dans storage.
globalThis.browser ??= chrome;

const CREATOR = 10000; // abonnés au-delà desquels ce n'est plus un vrai contact
const LOOKUP_CAP = 100; // ponytail: borne les requêtes /info/, IG bloque au-delà

// ponytail: app id public du web IG, en dur. Si IG le change : le lire dans le HTML de la page.
const APP_ID = "936619743392459";
const uid = () => document.cookie.match(/ds_user_id=(\d+)/)?.[1];

// URL absolue : dans un content script Firefox, fetch() ne résout pas le relatif
const api = (path) =>
  fetch(`${location.origin}/api/v1/${path}`, {
    credentials: "include",
    headers: { "X-IG-App-ID": APP_ID },
  });

const wait = (ms) => new Promise((r) => setTimeout(r, ms));

async function fetchPage(kind, cursor) {
  const q = new URLSearchParams({ count: "50" });
  if (cursor) q.set("max_id", cursor);
  const r = await api(`friendships/${uid()}/${kind}/?${q}`);
  if (!r.ok) throw new Error(`${kind} : HTTP ${r.status}`);
  return r.json();
}

async function fetchAll(kind) {
  const users = [];
  let cursor;
  do {
    const d = await fetchPage(kind, cursor);
    users.push(...d.users.map((u) => ({ username: u.username, pk: u.pk, verified: u.is_verified })));
    cursor = d.next_max_id;
    if (cursor) await wait(400); // IG throttle au-delà
  } while (cursor);
  return users;
}

// Le nombre d'abonnés n'est pas dans la liste : une requête par compte, d'où
// l'appel réservé à la liste croisée.
async function followerCounts(pks) {
  const counts = {};
  for (const pk of pks) {
    const r = await api(`users/${pk}/info/`);
    if (r.ok) counts[pk] = (await r.json()).user?.follower_count ?? null;
    await wait(300);
  }
  return counts;
}

const notify = (title, message) => browser.runtime.sendMessage({ cmd: "notify", title, message });

async function run() {
  await browser.storage.local.set({ running: true, error: null });
  try {
    if (!uid()) throw new Error("Not logged in to Instagram");
    const now = { followers: await fetchAll("followers"), following: await fetchAll("following") };
    // Les listes renvoient des comptes que le profil ne compte plus (vu : 419 distincts
    // listés pour 418 affichés) : les chiffres affichés viennent des compteurs d'IG.
    const r = await api(`users/${uid()}/info/`);
    const me = r.ok ? (await r.json()).user : null;
    const { snapshot } = await browser.storage.local.get("snapshot");

    const names = (users) => users.map((u) => u.username);
    const followers = names(now.followers);
    const since = snapshot ? diff(snapshot.followers, followers) : null;
    // lost = je le suis, il ne me suit pas ; gained = il me suit, je ne le suis pas
    const cross = diff(names(now.following), followers);

    const byName = new Map([...now.followers, ...now.following].map((u) => [u.username, u]));
    const shown = [...cross.lost, ...cross.gained].slice(0, LOOKUP_CAP);
    const counts = await followerCounts(shown.map((n) => byName.get(n).pk));

    const tag = (name) => {
      const u = byName.get(name);
      const count = u ? counts[u.pk] ?? null : null;
      return { username: name, count, creator: count >= CREATOR };
    };

    const result = {
      ts: Date.now(),
      prevTs: snapshot?.ts ?? null,
      followers: me?.follower_count ?? followers.length,
      following: me?.following_count ?? now.following.length,
      listed: { followers: followers.length, following: now.following.length },
      since: since && { lost: since.lost.map(tag), gained: since.gained.map(tag) },
      cross: { lost: cross.lost.map(tag), gained: cross.gained.map(tag) },
    };

    await browser.storage.local.set({
      result,
      running: false,
      snapshot: { ts: result.ts, followers },
    });

    notify(
      `${result.followers} followers · ${result.following} following`,
      `${result.cross.lost.length} don't follow you back · ${result.cross.gained.length} you don't follow back` +
        (result.since ? `\n${result.since.lost.length} unfollowed you · ${result.since.gained.length} new` : ""),
    );
  } catch (e) {
    await browser.storage.local.set({ running: false, error: e.message });
    notify("Scan failed", e.message);
  }
}

browser.runtime.onMessage.addListener((m, _sender, respond) => {
  if (m.cmd === "start") run();
  respond(); // sans réponse, Chrome fait rejeter le sendMessage du popup
});
