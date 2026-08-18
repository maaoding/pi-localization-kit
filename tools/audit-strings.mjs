import { readFileSync, readdirSync, statSync } from "node:fs";
import { extname, join } from "node:path";

const suspiciousSingleWords = new Set(["Aborted","Cancelled","Error","Failed","Loading","Retry","Unknown","Warning"]);

function normalizeValue(value) {
  return value
    .replaceAll("\\n", " ")
    .replaceAll("\\r", " ")
    .replaceAll("\\t", " ")
    .replace(/\s+/gu, " ")
    .trim();
}

function isCandidate(value) {
  const normalized = normalizeValue(value);
  if (!/[A-Za-z]{3}/u.test(normalized) || /[\u3400-\u9fff]/u.test(normalized)) {
    return false;
  }
  return (
    suspiciousSingleWords.has(normalized) ||
    /\s/u.test(normalized) ||
    /[.!?:]/u.test(normalized)
  );
}

function scanJavaScript(source) {
  const values = [];
  let index = 0;
  let line = 1;

  function advance() {
    if (source[index] === "\n") line += 1;
    index += 1;
  }

  function skipLineComment() {
    while (index < source.length && source[index] !== "\n") advance();
  }

  function skipBlockComment() {
    index += 2;
    while (index < source.length) {
      if (source[index] === "*" && source[index + 1] === "/") {
        index += 2;
        return;
      }
      advance();
    }
  }

  function isRegexStart() {
    let cursor = index - 1;
    while (cursor >= 0 && /\s/u.test(source[cursor])) cursor -= 1;
    if (cursor < 0) return true;
    if (/[[({=,:;!?&|+\-*%^~<>]/u.test(source[cursor])) return true;
    const prefix = source.slice(0, cursor + 1);
    return /(?:^|\W)(?:return|case|throw|else|do|yield|await|typeof|instanceof|in|of)\s*$/u.test(
      prefix,
    );
  }

  function skipRegexLiteral() {
    let inCharacterClass = false;
    advance();
    while (index < source.length) {
      const char = source[index];
      if (char === "\\") {
        advance();
        if (index < source.length) advance();
      } else if (char === "[") {
        inCharacterClass = true;
        advance();
      } else if (char === "]" && inCharacterClass) {
        inCharacterClass = false;
        advance();
      } else if (char === "/" && !inCharacterClass) {
        advance();
        while (index < source.length && /[A-Za-z]/u.test(source[index])) advance();
        return;
      } else {
        advance();
      }
    }
  }

  function readQuoted(quote) {
    const startLine = line;
    let value = "";
    advance();
    while (index < source.length) {
      const char = source[index];
      if (char === "\\") {
        value += char;
        advance();
        if (index < source.length) {
          value += source[index];
          advance();
        }
      } else if (char === quote) {
        advance();
        values.push({ line: startLine, value });
        return;
      } else {
        value += char;
        advance();
      }
    }
  }

  function scanExpression() {
    let braceDepth = 0;
    while (index < source.length) {
      const char = source[index];
      if (char === "'" || char === '"') {
        readQuoted(char);
      } else if (char === "`") {
        readTemplate();
      } else if (char === "/" && source[index + 1] === "/") {
        index += 2;
        skipLineComment();
      } else if (char === "/" && source[index + 1] === "*") {
        skipBlockComment();
      } else if (char === "/" && isRegexStart()) {
        skipRegexLiteral();
      } else if (char === "{") {
        braceDepth += 1;
        advance();
      } else if (char === "}") {
        if (braceDepth === 0) {
          advance();
          return;
        }
        braceDepth -= 1;
        advance();
      } else {
        advance();
      }
    }
  }

  function readTemplate() {
    advance();
    let chunkLine = line;
    let chunk = "";
    while (index < source.length) {
      const char = source[index];
      if (char === "\\") {
        chunk += char;
        advance();
        if (index < source.length) {
          chunk += source[index];
          advance();
        }
      } else if (char === "`") {
        values.push({ line: chunkLine, value: chunk });
        advance();
        return;
      } else if (char === "$" && source[index + 1] === "{") {
        values.push({ line: chunkLine, value: chunk });
        chunk = "";
        index += 2;
        scanExpression();
        chunkLine = line;
      } else {
        chunk += char;
        advance();
      }
    }
  }

  while (index < source.length) {
    const char = source[index];
    if (char === "'" || char === '"') {
      readQuoted(char);
    } else if (char === "`") {
      readTemplate();
    } else if (char === "/" && source[index + 1] === "/") {
      index += 2;
      skipLineComment();
    } else if (char === "/" && source[index + 1] === "*") {
      skipBlockComment();
    } else if (char === "/" && isRegexStart()) {
      skipRegexLiteral();
    } else {
      advance();
    }
  }
  return values;
}

function scanHtml(source) {
  const withoutComments = source.replace(/<!--[\s\S]*?-->/gu, "");
  const values = [];
  const lineOf = (index) => withoutComments.slice(0, index).split("\n").length;
  const attributePattern = /\b(?:title|placeholder|aria-label)\s*=\s*(["'])([\s\S]*?)\1/gu;
  for (const match of withoutComments.matchAll(attributePattern)) {
    values.push({ line: lineOf(match.index), value: match[2] });
  }
  const textPattern = />([^<]+)</gu;
  for (const match of withoutComments.matchAll(textPattern)) {
    const value = match[1].replace(/\{\{[\s\S]*?\}\}/gu, "");
    values.push({ line: lineOf(match.index), value });
  }
  return values;
}


const paths = process.argv.slice(2);
if (paths.length === 0) {
  console.error("用法：node tools/audit-strings.mjs <file-or-dir> [...]");
  process.exit(2);
}

function collect(p) {
  const stat = fsStatSafe(p);
  if (!stat) return [];
  if (stat.isDirectory()) return readdirSync(p).flatMap((name) => collect(join(p, name)));
  if (![".js", ".ts", ".mjs", ".cjs", ".html", ".md", ".txt"].includes(extname(p))) return [];
  const source = readFileSync(p, "utf8");
  const extension = extname(p);
  const values = extension === ".html"
    ? scanHtml(source)
    : extension === ".md" || extension === ".txt"
      ? scanText(source)
      : scanJavaScript(source);
  const seen = new Set();
  const rows = [];
  for (const item of values) {
    const value = normalizeValue(item.value);
    if (!isCandidate(value) || seen.has(value)) continue;
    seen.add(value);
    rows.push({ path: p, line: item.line, value });
  }
  return rows;
}

function scanText(source) {
  return source.replaceAll(String.fromCharCode(13), "").split(String.fromCharCode(10)).map((value, index) => ({ line: index + 1, value }));
}
function fsStatSafe(p) { try { return statSync(p); } catch { return null; } }

for (const p of paths) {
  for (const row of collect(p)) {
    console.log(row.path.replaceAll("\\", "/") + ":" + row.line + "	" + row.value);
  }
}
