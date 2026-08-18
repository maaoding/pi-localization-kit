import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const [beforeArg, afterArg] = process.argv.slice(2);
if (!beforeArg || !afterArg) {
  console.error("用法：node tools/diff-inventory.mjs <old-inventory.json> <new-inventory.json>");
  process.exit(2);
}
const before = JSON.parse(readFileSync(resolve(beforeArg), "utf8"));
const after = JSON.parse(readFileSync(resolve(afterArg), "utf8"));
const left = new Map(before.files.map((f) => [f.path, f.upstreamSha256]));
const right = new Map(after.files.map((f) => [f.path, f.upstreamSha256]));

const added = [...right.keys()].filter((p) => !left.has(p)).sort();
const removed = [...left.keys()].filter((p) => !right.has(p)).sort();
const changed = [...left.keys()]
  .filter((p) => right.has(p) && left.get(p) !== right.get(p))
  .sort();

console.log(`${before.package.name}@${before.package.version} -> ${after.package.name}@${after.package.version}`);
console.log(`新增 ${added.length} / 删除 ${removed.length} / 内容变化 ${changed.length} / 未变 ${left.size - removed.length - changed.length}`);
for (const path of added) console.log(`+ ${path}`);
for (const path of removed) console.log(`- ${path}`);
for (const path of changed) console.log(`~ ${path}`);
