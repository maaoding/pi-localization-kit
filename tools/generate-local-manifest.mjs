import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { resolve, join, dirname } from "node:path";

const [inventoryArg, outputArg] = process.argv.slice(2);
if (!inventoryArg || !outputArg) {
  console.error("用法：node tools/generate-local-manifest.mjs <inventory.json> <local-output.json>");
  process.exit(2);
}
const inventory = JSON.parse(readFileSync(resolve(inventoryArg), "utf8"));
const manifest = {
  schemaVersion: 1,
  inventory: inventoryArg,
  package: {
    name: inventory.package.name,
    version: inventory.package.version,
  },
  files: inventory.files.map((file) => ({
    path: file.path,
    upstreamSha256: file.upstreamSha256,
    localizedSha256: "",
    stringCount: file.stringCount ?? 0,
    replacements: [],
  })),
};
mkdirSync(dirname(resolve(outputArg)), { recursive: true });
writeFileSync(resolve(outputArg), JSON.stringify(manifest, null, 2) + "\n");
console.log(`已生成本地 manifest 骨架：${resolve(outputArg)}`);
console.log("请仅在本机填写 replacements 和 localizedSha256；不要提交该文件。");
