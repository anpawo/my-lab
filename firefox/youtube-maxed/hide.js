// These cards have no distinguishing attribute: only their text identifies them,
// so CSS isn't enough.
const JUNK = /membership|content label|explore more topics/i;
const BLOCKS = "ytd-rich-section-renderer, ytd-statement-banner-renderer";

const kill = (b) => {
  // the shelf title if non-empty, otherwise the whole text (banner)
  const title = b.querySelector("#title, h2")?.textContent;
  if (JUNK.test(title || b.textContent))
    (b.closest("ytd-rich-section-renderer") ?? b).remove();
};

// Synchronous in the callback (microtask) and limited to the inserted subtree:
// the card is gone before the first layout. A rAF let it paint, take its
// height, then vanish — hence the scroll jump.
new MutationObserver((records) => {
  for (const r of records)
    for (const n of r.addedNodes) {
      if (n.nodeType !== Node.ELEMENT_NODE) continue;
      const b = n.closest(BLOCKS);
      if (b) kill(b);
      else n.querySelectorAll(BLOCKS).forEach(kill);
    }
}).observe(document.documentElement, { childList: true, subtree: true });

document.querySelectorAll(BLOCKS).forEach(kill);
