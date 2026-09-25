// Ces encarts n'ont aucun attribut distinctif : seul leur texte les identifie,
// donc CSS ne suffit pas.
const JUNK = /membership|content label|explore more topics/i;
const BLOCKS = "ytd-rich-section-renderer, ytd-statement-banner-renderer";

const kill = (b) => {
  // le titre de l'étagère s'il est non vide, sinon tout le texte (bannière)
  const title = b.querySelector("#title, h2")?.textContent;
  if (JUNK.test(title || b.textContent))
    (b.closest("ytd-rich-section-renderer") ?? b).remove();
};

// Synchrone dans le callback (microtâche) et limité au sous-arbre inséré :
// l'encart part avant le premier layout. Un rAF le laissait peindre, prendre
// sa hauteur, puis disparaître — d'où le saut de scroll.
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
