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
    $sourceKind = if ($inventory.source.PSObject.Properties.Name -contains "kind") { [string]$inventory.source.kind } else { "npm" }
    if ([string]::IsNullOrWhiteSpace($sourceKind) -or $sourceKind -eq "npm") {
        if ([string]$inventory.source.tarball -notmatch '\S' -or
            [string]$inventory.source.integrity -notmatch '^sha512-[A-Za-z0-9+/]+={0,2}$' -or
            [string]$inventory.source.shasum -notmatch '^[0-9a-f]{40}$') {
            $failures.Add("npm registry 元数据无效：$($path.FullName)")
        }
    }
    elseif ($sourceKind -eq "git") {
        if ([string]$inventory.source.repository -notmatch '^https://' -or
            [string]::IsNullOrWhiteSpace([string]$inventory.source.tag) -or
            [string]$inventory.source.commit -notmatch '^[0-9a-f]{40}$') {
            $failures.Add("git 来源元数据无效：$($path.FullName)")
        }
        if ($null -ne $inventory.source.build) {
            foreach ($buildStep in @($inventory.source.build)) {
                if ([string]::IsNullOrWhiteSpace([string]$buildStep)) {
                    $failures.Add("git build 步骤无效：$($path.FullName)")
                }
            }
        }
    }
    else {
        $failures.Add("未知 source.kind：$($path.FullName) / $sourceKind")
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
Write-Host "inventory 校验通过：路径、上游 SHA-256、来源元数据和载荷边界均有效。"
