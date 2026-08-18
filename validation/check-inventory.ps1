#Requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$inventoryDir = Join-Path $root "inventories"
$failures = [System.Collections.Generic.List[string]]::new()

foreach ($path in @(Get-ChildItem -LiteralPath $inventoryDir -Recurse -Filter "*.json" -File | Sort-Object FullName)) {
    $inventory = Get-Content -LiteralPath $path.FullName -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100
    if ([int]$inventory.schemaVersion -ne 1) { $failures.Add("schemaVersion 无效：$($path.FullName)") }
    if ([string]::IsNullOrWhiteSpace([string]$inventory.package.name) -or
        [string]::IsNullOrWhiteSpace([string]$inventory.package.version) -or
        [string]::IsNullOrWhiteSpace([string]$inventory.package.installPath)) {
        $failures.Add("package 元数据不完整：$($path.FullName)")
    }
    if ([string]$inventory.source.integrity -notmatch '^sha512-[A-Za-z0-9+/]+={0,2}$' -or
        [string]$inventory.source.shasum -notmatch '^[0-9a-f]{40}$') {
        $failures.Add("registry 元数据无效：$($path.FullName)")
    }
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($file in @($inventory.files)) {
        if ([string]::IsNullOrWhiteSpace([string]$file.path) -or
            [string]$file.upstreamSha256 -notmatch '^[0-9A-Fa-f]{64}$') {
            $failures.Add("文件条目无效：$($path.FullName)")
        }
        if (-not $seen.Add([string]$file.path)) {
            $failures.Add("文件路径重复：$($path.FullName) / $($file.path)")
        }
        $hasPayload = $file.PSObject.Properties.Name -contains "replacements" -or $file.PSObject.Properties.Name -contains "localizedSha256"
        if ($hasPayload) {
            $failures.Add("inventory 不得包含翻译载荷：$($path.FullName) / $($file.path)")
        }
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Host "inventory 校验通过：路径、上游 SHA-256、registry 元数据和载荷边界均有效。"
