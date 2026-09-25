function diff(before, after) {
  const b = new Set(before);
  const a = new Set(after);
  return {
    lost: before.filter((u) => !a.has(u)),
    gained: after.filter((u) => !b.has(u)),
  };
}

if (typeof module !== "undefined") module.exports = { diff };
