#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$LocalManifestDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
if ([string]::IsNullOrWhiteSpace($LocalManifestDir)) {
    $LocalManifestDir = Join-Path $root "local\manifests"
}
if (-not (Test-Path -LiteralPath $LocalManifestDir -PathType Container)) {
    Write-Host "没有本机 manifest 目录，跳过本机载荷校验：$LocalManifestDir"
    exit 0
}

$failures = [System.Collections.Generic.List[string]]::new()
foreach ($path in @(Get-ChildItem -LiteralPath $LocalManifestDir -Filter "*.json" -File | Sort-Object Name)) {
    $manifest = Get-Content -LiteralPath $path.FullName -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100
    if ([int]$manifest.schemaVersion -ne 1) { $failures.Add("schemaVersion 无效：$($path.FullName)") }
    $inventoryPath = Join-Path $root ([string]$manifest.inventory)
    if (-not (Test-Path -LiteralPath $inventoryPath -PathType Leaf)) {
        $failures.Add("inventory 不存在：$($path.FullName)")
    }
    $seenIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($file in @($manifest.files)) {
        if ([string]$file.upstreamSha256 -notmatch '^[0-9A-Fa-f]{64}$' -or
            [string]$file.localizedSha256 -notmatch '^[0-9A-Fa-f]{64}$') {
            $failures.Add("SHA-256 无效：$($path.FullName) / $($file.path)")
        }
        if (@($file.replacements).Count -eq 0) {
            $failures.Add("replacements 为空：$($path.FullName) / $($file.path)")
        }
        foreach ($replacement in @($file.replacements)) {
            if ([string]::IsNullOrWhiteSpace([string]$replacement.id) -or
                [string]::IsNullOrEmpty([string]$replacement.from) -or
                [int]$replacement.expectedCount -lt 1) {
                $failures.Add("替换项无效：$($path.FullName) / $($file.path)")
            }
            if (-not $seenIds.Add([string]$replacement.id)) {
                $failures.Add("替换 ID 重复：$($replacement.id)")
            }
        }
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Host "本机 manifest 结构校验通过。"
