// Runs inside the instagram.com page: requests are same-origin, so the session
// cookies go along on their own. No DOM scraping — the web app itself uses this
// API, and the modal only loads what gets scrolled.
// The popup closes as soon as it loses focus (alt-tab) and its JS dies with it.
// So the scan runs here, and the popup only reads the result from storage.
globalThis.browser ??= chrome;

const CREATOR = 10000; // followers beyond which this is no longer a real contact
const LOOKUP_CAP = 100; // ponytail: caps the /info/ requests, IG blocks past that

// ponytail: IG web's public app id, hardcoded. If IG changes it: read it from the page HTML.
const APP_ID = "936619743392459";
const uid = () => document.cookie.match(/ds_user_id=(\d+)/)?.[1];

// Absolute URL: in a Firefox content script, fetch() doesn't resolve relative paths
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
    if (cursor) await wait(400); // IG throttles past that
  } while (cursor);
  return users;
}

// The follower count isn't in the list: one request per account, hence the
// call being reserved for the cross list.
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
    // The lists return accounts the profile no longer counts (seen: 419 distinct
    // listed for 418 displayed): the displayed numbers come from IG's counters.
    const r = await api(`users/${uid()}/info/`);
    const me = r.ok ? (await r.json()).user : null;
    const { snapshot } = await browser.storage.local.get("snapshot");

    const names = (users) => users.map((u) => u.username);
    const followers = names(now.followers);
    const since = snapshot ? diff(snapshot.followers, followers) : null;
    // lost = I follow them, they don't follow me; gained = they follow me, I don't follow them
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
  respond(); // without a response, Chrome makes the popup's sendMessage reject
});
