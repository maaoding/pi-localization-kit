import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  loadJson,
  resolveInventory,
  computeManifest,
} from "./lib/manifest-core.mjs";

const [manifestArg, packageRootArg] = process.argv.slice(2);
if (!manifestArg || !packageRootArg) {
  console.error("用法：node tools/compute-manifest-hashes.mjs <local-manifest.json> <package-root>");
  console.error("core 传 Pi 包根目录；extension 传扩展包根目录。");
  process.exit(2);
}

const manifestPath = resolve(manifestArg);
const manifest = loadJson(manifestPath);
const inventory = loadJson(resolveInventory(manifest, manifestPath));
const results = computeManifest(inventory, manifest, packageRootArg, manifestPath);

for (const result of results) {
  result.file.localizedSha256 = result.localizedHash;
}
writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n");
console.log(`已计算并写入 localizedSha256：${manifest.package.name}@${manifest.package.version}，${results.length} 个文件。`);
console.log("接下来可运行 check-manifest-local 或 apply-local-manifest。");
