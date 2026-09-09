import { createHash } from "node:crypto";
import { readFileSync, existsSync } from "node:fs";
import { join, resolve } from "node:path";

const [inventoryArg, packageRootArg] = process.argv.slice(2);
if (!inventoryArg || !packageRootArg) {
  console.error("用法：node tools/verify-upstream.mjs <inventory.json> <package-root>");
  console.error("core: package-root 为 Pi 包根目录；extension: package-root 为扩展包根目录。");
  process.exit(2);
}

const inventory = JSON.parse(readFileSync(resolve(inventoryArg), "utf8"));
if (inventory.schemaVersion !== 1) throw new Error(`不支持的 inventory schemaVersion: ${inventory.schemaVersion}`);
const packageRoot = resolve(packageRootArg);
const installPath = inventory.package.installPath;
const targetRoot = inventory.package.kind === "core"
  ? join(packageRoot, ...installPath.split("/"))
  : packageRoot;

const failures = [];
if (inventory.package.kind === "core") {
  const packageJsonPath = join(packageRoot, "package.json");
  if (!existsSync(packageJsonPath)) {
    failures.push("package.json: 文件缺失，无法核对实际 CLI 入口");
  } else {
    const packageJson = JSON.parse(readFileSync(packageJsonPath, "utf8"));
    const bin = packageJson.bin;
    const packageBasename = String(packageJson.name ?? "").split("/").at(-1);
    const entrypoint = typeof bin === "string" ? bin : bin?.pi ?? bin?.[packageBasename];
    if (typeof entrypoint !== "string" || entrypoint.length === 0) {
      failures.push("package.json#bin.pi: 未找到实际 CLI 入口");
    } else {
      const normalizedEntrypoint = entrypoint.replace(/^\.\//, "").replaceAll("\\", "/");
      const normalizedInstallPath = String(installPath).replace(/^\.\//, "").replace(/\/$/, "");
      const prefix = `${normalizedInstallPath}/`;
      if (!normalizedEntrypoint.startsWith(prefix)) {
        failures.push(`package.json#bin.pi: ${normalizedEntrypoint} 不在 installPath ${normalizedInstallPath} 下`);
      } else {
        const inventoryEntrypoint = normalizedEntrypoint.slice(prefix.length);
        if (!inventory.files.some((file) => file.path === inventoryEntrypoint)) {
          failures.push(`package.json#bin.pi: 实际入口 ${inventoryEntrypoint} 未纳入 inventory`);
        }
      }
    }
  }
}

for (const file of inventory.files) {
  const target = join(targetRoot, ...file.path.split("/"));
  if (!existsSync(target)) {
    failures.push(`${file.path}: 文件缺失`);
    continue;
  }
  const actual = createHash("sha256").update(readFileSync(target)).digest("hex").toUpperCase();
  const expected = file.upstreamSha256.toUpperCase();
  if (actual !== expected) failures.push(`${file.path}: 哈希不符（期望 ${expected}，实际 ${actual}）`);
}

if (failures.length > 0) {
  console.error(`上游校验失败：${inventory.package.name}@${inventory.package.version}，${failures.length}/${inventory.files.length}`);
  for (const failure of failures) console.error(`  - ${failure}`);
  process.exit(1);
}
console.log(`上游校验通过：${inventory.package.name}@${inventory.package.version}，${inventory.files.length} 个文件与 inventory 一致。`);
