import { resolve } from "node:path";
import {
  loadJson,
  resolveInventory,
  validateManifest,
} from "./lib/manifest-core.mjs";

const [manifestArg, packageRootArg] = process.argv.slice(2);
if (!manifestArg || !packageRootArg) {
  console.error("用法：node tools/check-manifest-local.mjs <local-manifest.json> <package-root>");
  console.error("core 传 Pi 包根目录；extension 传扩展包根目录。");
  process.exit(2);
}

const manifestPath = resolve(manifestArg);
const manifest = loadJson(manifestPath);
const inventory = loadJson(resolveInventory(manifest, manifestPath));
const results = validateManifest(inventory, manifest, packageRootArg, manifestPath);
console.log(`本机 manifest 校验通过：${manifest.package.name}@${manifest.package.version}，${results.length} 个文件。`);
console.log("正向重放、反向重放、上游 SHA-256 与 localizedSha256 均一致。");
