// Chrome kills a service worker idle for 30 s: the scan (up to a minute of
// waiting) therefore runs in the content script; here we only notify.
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
