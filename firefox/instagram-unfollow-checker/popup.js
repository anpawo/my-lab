globalThis.browser ??= chrome;

const out = document.getElementById("out");
const esc = (s) => s.replace(/[<&"]/g, (c) => ({ "<": "&lt;", "&": "&amp;", '"': "&quot;" })[c]);

const short = (n) => (n >= 1e6 ? `${(n / 1e6).toFixed(1)}M` : n >= 1e3 ? `${Math.round(n / 1e3)}k` : n);

const row = (u) =>
  `<li><a href="https://instagram.com/${esc(u.username)}" target="_blank">${esc(u.username)}</a>` +
  (u.count != null ? ` <span class="count">${short(u.count)}</span>` : "") +
  "</li>";

const list = (title, users) =>
  users.length ? `<h2>${title} (${users.length})</h2><ul>${users.map(row).join("")}</ul>` : "";

// Les créateurs sortent dans leur propre bloc : les suivre sans retour est normal,
// c'est la liste des vraies personnes qui est actionnable.
const split = (title, users) =>
  list(title, users.filter((u) => !u.creator)) + list(`${title} — creators`, users.filter((u) => u.creator));

async function render() {
  const { result, running, error } = await browser.storage.local.get(["result", "running", "error"]);
  if (running) return void (out.innerHTML = `<p class="when">Scanning… you can close this, it keeps running.</p>`);
  if (error) return void (out.innerHTML = `<p class="when">${esc(error)}</p>`);
  if (!result) return void (out.innerHTML = "");

  out.innerHTML =
    `<p class="counts">${result.followers} followers · ${result.following} following</p>` +
    (result.listed && (result.listed.followers !== result.followers || result.listed.following !== result.following)
      ? `<p class="when">Instagram's lists return ${result.listed.followers} · ${result.listed.following}</p>`
      : "") +
    `<p class="when">scanned ${new Date(result.ts).toLocaleString()}</p>` +
    (result.since
      ? list("Unfollowed you", result.since.lost) +
        list("New followers", result.since.gained) +
        (result.since.lost.length || result.since.gained.length
          ? ""
          : `<h2>No change since ${new Date(result.prevTs).toLocaleString()}</h2>`)
      : `<p class="when">First scan: baseline saved.</p>`) +
    split("Not following you back", result.cross.lost) +
    split("Fans you don't follow", result.cross.gained);
}

document.getElementById("scan").onclick = async () => {
  out.innerHTML = `<p class="when">Scanning… you can close this, it keeps running.</p>`;
  try {
    const [tab] = await browser.tabs.query({ url: "*://www.instagram.com/*" });
    if (!tab) throw new Error("No instagram.com tab open.");
    await browser.tabs.sendMessage(tab.id, { cmd: "start" });
  } catch (e) {
    await browser.storage.local.set({ running: false, error: e.message });
  }
};

browser.storage.onChanged.addListener(render);
render();
