import { writeFileSync, mkdirSync, renameSync, rmSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import {
  loadJson,
  resolveInventory,
  targetPathFor,
  validateManifest,
} from "./lib/manifest-core.mjs";

const [manifestArg, packageRootArg] = process.argv.slice(2);
if (!manifestArg || !packageRootArg) {
  console.error("用法：node tools/apply-local-manifest.mjs <local-manifest.json> <package-root>");
  console.error("core 传 Pi 包根目录；extension 传扩展包根目录。");
  process.exit(2);
}

const manifestPath = resolve(manifestArg);
const manifest = loadJson(manifestPath);
const inventory = loadJson(resolveInventory(manifest, manifestPath));
const results = validateManifest(inventory, manifest, packageRootArg, manifestPath);

for (const result of results) {
  const target = targetPathFor(inventory, packageRootArg, result.file);
  const parent = dirname(target);
  const temporary = join(parent, `.localize-${process.pid}-${Date.now()}.tmp`);
  mkdirSync(parent, { recursive: true });
  writeFileSync(temporary, result.localizedText, "utf8");
  renameSync(temporary, target);
}

console.log(`本机 manifest 应用成功：${manifest.package.name}@${manifest.package.version}，${results.length} 个文件。`);
console.log("所有目标均先通过正向/反向重放与双 SHA-256 校验。");
