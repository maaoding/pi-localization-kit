import { createHash } from "node:crypto";
import { readFileSync, existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const KIT_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

export function sha256Text(text) {
  return createHash("sha256").update(Buffer.from(text, "utf8")).digest("hex").toUpperCase();
}

export function sha256File(path) {
  return createHash("sha256").update(readFileSync(path)).digest("hex").toUpperCase();
}

export function replaceLiteral(text, from, to) {
  return text.split(from).join(to);
}

export function loadJson(path) {
  return JSON.parse(readFileSync(resolve(path), "utf8"));
}

export function resolveInventory(manifest, manifestPath) {
  const value = manifest.inventory;
  if (!value) throw new Error(`local manifest 缺少 inventory：${manifestPath}`);
  if (resolve(value) === value) return value;
  return join(KIT_ROOT, value);
}

export function targetRootFor(inventory, packageRoot) {
  if (inventory.package.kind === "core") {
    return join(resolve(packageRoot), ...inventory.package.installPath.split("/"));
  }
  return resolve(packageRoot);
}

export function targetPathFor(inventory, packageRoot, file) {
  return join(targetRootFor(inventory, packageRoot), ...file.path.split("/"));
}

export function validateManifest(inventory, manifest, packageRoot, manifestPath) {
  if (manifest.schemaVersion !== 1) throw new Error(`schemaVersion 无效：${manifestPath}`);
  if (manifest.package.name !== inventory.package.name || manifest.package.version !== inventory.package.version) {
    throw new Error(`local manifest 包/版本与 inventory 不匹配：${manifestPath}`);
  }
  const inventoryFiles = new Map(inventory.files.map((file) => [file.path, file]));
  const results = [];
  const seenIds = new Set();
  for (const file of manifest.files) {
    const inventoryFile = inventoryFiles.get(file.path);
    if (!inventoryFile) throw new Error(`${file.path}: inventory 中不存在该文件`);
    if (file.upstreamSha256.toUpperCase() !== inventoryFile.upstreamSha256.toUpperCase()) {
      throw new Error(`${file.path}: upstreamSha256 与 inventory 不一致`);
    }
    if (!/^[0-9A-Fa-f]{64}$/.test(file.localizedSha256)) {
      throw new Error(`${file.path}: localizedSha256 无效`);
    }
    if (!Array.isArray(file.replacements) || file.replacements.length === 0) {
      throw new Error(`${file.path}: replacements 为空`);
    }
    const target = targetPathFor(inventory, packageRoot, file);
    if (!existsSync(target)) throw new Error(`${file.path}: 目标文件缺失：${target}`);
    const upstream = readFileSync(target, "utf8");
    if (sha256File(target) !== inventoryFile.upstreamSha256.toUpperCase()) {
      throw new Error(`${file.path}: 目标文件不是 inventory 对应的官方上游版本`);
    }
    let text = upstream;
    for (const replacement of file.replacements) {
      if (!replacement.id || typeof replacement.from !== "string" || typeof replacement.to !== "string") {
        throw new Error(`${file.path}: 替换项结构无效`);
      }
      if (seenIds.has(replacement.id)) throw new Error(`替换 ID 重复：${replacement.id}`);
      seenIds.add(replacement.id);
      if (replacement.from.length === 0) throw new Error(`${replacement.id}: from 不能为空`);
      const actual = text.split(replacement.from).length - 1;
      if (actual !== replacement.expectedCount) {
        throw new Error(`${replacement.id}: 预期 ${replacement.expectedCount} 次，实际 ${actual} 次`);
      }
      text = replaceLiteral(text, replacement.from, replacement.to);
    }
    const localizedHash = sha256Text(text);
    if (localizedHash !== file.localizedSha256.toUpperCase()) {
      throw new Error(`${file.path}: localizedSha256 不符（期望 ${file.localizedSha256}，实际 ${localizedHash}）`);
    }
    let reverse = text;
    for (const replacement of [...file.replacements].reverse()) {
      const actual = reverse.split(replacement.to).length - 1;
      if (actual !== replacement.expectedCount) {
        throw new Error(`${replacement.id} 反向: 预期 ${replacement.expectedCount} 次，实际 ${actual} 次`);
      }
      reverse = replaceLiteral(reverse, replacement.to, replacement.from);
    }
    if (reverse !== upstream) throw new Error(`${file.path}: 反向重放未恢复上游文本`);
    results.push({ file, target, localizedText: text });
  }
  return results;
}

export function computeManifest(inventory, manifest, packageRoot, manifestPath) {
  if (manifest.schemaVersion !== 1) throw new Error(`schemaVersion 无效：${manifestPath}`);
  if (manifest.package.name !== inventory.package.name || manifest.package.version !== inventory.package.version) {
    throw new Error(`local manifest 包/版本与 inventory 不匹配：${manifestPath}`);
  }
  const inventoryFiles = new Map(inventory.files.map((file) => [file.path, file]));
  const results = [];
  const seenIds = new Set();
  for (const file of manifest.files) {
    const inventoryFile = inventoryFiles.get(file.path);
    if (!inventoryFile) throw new Error(`${file.path}: inventory 中不存在该文件`);
    if (file.upstreamSha256.toUpperCase() !== inventoryFile.upstreamSha256.toUpperCase()) {
      throw new Error(`${file.path}: upstreamSha256 与 inventory 不一致`);
    }
    if (!Array.isArray(file.replacements) || file.replacements.length === 0) {
      throw new Error(`${file.path}: replacements 为空`);
    }
    const target = targetPathFor(inventory, packageRoot, file);
    if (!existsSync(target)) throw new Error(`${file.path}: 目标文件缺失：${target}`);
    const upstream = readFileSync(target, "utf8");
    if (sha256File(target) !== inventoryFile.upstreamSha256.toUpperCase()) {
      throw new Error(`${file.path}: 目标文件不是 inventory 对应的官方上游版本`);
    }
    let text = upstream;
    for (const replacement of file.replacements) {
      if (!replacement.id || typeof replacement.from !== "string" || typeof replacement.to !== "string") {
        throw new Error(`${file.path}: 替换项结构无效`);
      }
      if (seenIds.has(replacement.id)) throw new Error(`替换 ID 重复：${replacement.id}`);
      seenIds.add(replacement.id);
      if (replacement.from.length === 0) throw new Error(`${replacement.id}: from 不能为空`);
      const actual = text.split(replacement.from).length - 1;
      if (actual !== replacement.expectedCount) {
        throw new Error(`${replacement.id}: 预期 ${replacement.expectedCount} 次，实际 ${actual} 次`);
      }
      text = replaceLiteral(text, replacement.from, replacement.to);
    }
    results.push({ file, target, localizedText: text, localizedHash: sha256Text(text) });
  }
  return results;
}
