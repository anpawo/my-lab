// Chrome tue un service worker inactif 30 s : le scan (jusqu'à une minute
// d'attente) tourne donc dans le content script, ici on ne fait que notifier.
globalThis.browser ??= chrome;

browser.runtime.onMessage.addListener((m, _sender, respond) => {
  if (m.cmd === "notify")
    browser.notifications.create({
      type: "basic",
      iconUrl: browser.runtime.getURL("icon-32.png"),
      title: m.title,
      message: m.message,
    });
  respond();
});
