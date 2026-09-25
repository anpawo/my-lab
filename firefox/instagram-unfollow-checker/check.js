const assert = require("node:assert");
const { diff } = require("./diff.js");

assert.deepEqual(diff(["a", "b", "c"], ["b", "c", "d"]), { lost: ["a"], gained: ["d"] });
assert.deepEqual(diff([], []), { lost: [], gained: [] });
assert.deepEqual(diff(["a"], []), { lost: ["a"], gained: [] });
console.log("ok");
