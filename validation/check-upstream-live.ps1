#Requires -Version 7.0
[CmdletBinding()]
param(
    [switch]$KeepWork
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$fetchScript = Join-Path $root "tools\fetch-official.ps1"
$verifyScript = Join-Path $root "tools\verify-upstream.mjs"
$node = @(Get-Command node.exe -CommandType Application -ErrorAction Stop)[0].Source
$gitCommand = @(Get-Command git.exe -CommandType Application -ErrorAction Stop)[0].Source
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("pi-kit-upstream-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work -Force | Out-Null

try {
    foreach ($catalogPath in @(
        (Join-Path $root "catalog\core.json"),
        (Join-Path $root "catalog\extensions.json")
    )) {
        $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100
        foreach ($record in @($catalog.packages)) {
            $spec = "$($record.name)@$($record.version)"
            $inventoryPath = Join-Path $root ([string]$record.inventory)
            $destination = Join-Path $work ($spec.Replace("/", "__"))
            $sourceKind = if ($record.source.PSObject.Properties.Name -contains "kind") { [string]$record.source.kind } else { "npm" }
            if ($sourceKind -eq "git") {
                $inventory = Get-Content -LiteralPath $inventoryPath -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100
                & $gitCommand "clone" "--depth" "1" "--branch" ([string]$record.source.tag) ([string]$record.source.repository) $destination | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "git clone 失败：$spec" }
                Push-Location $destination
                try {
                    $head = ((& $gitCommand "rev-parse" "HEAD") -join [Environment]::NewLine).Trim()
                    if ($head -cne ([string]$record.source.commit)) {
                        throw "git commit 不匹配：$spec（期望 $($record.source.commit)，实际 $head）"
                    }
                    $buildSteps = if ($inventory.source.PSObject.Properties.Name -contains "build") {
                        @($inventory.source.build)
                    } else {
                        @()
                    }
                    foreach ($buildStep in $buildSteps) {
                            $parts = @(([string]$buildStep) -split "\s+" | Where-Object { $_ })
                            if ($parts.Count -eq 0) { throw "git build 步骤为空：$spec" }
                            $command = $parts[0]
                            $args = @($parts | Select-Object -Skip 1)
                            if ($command -eq "npm") { $command = "npm.cmd" }
                            & $command @args
                            if ($LASTEXITCODE -ne 0) { throw "git build 步骤失败：$spec / $buildStep" }
                        }
                    }
                finally {
                    Pop-Location
                }
                & $node $verifyScript $inventoryPath $destination | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "verify-upstream 失败：$spec" }
                Write-Host "通过：$spec (git)"
                continue
            }

            & $fetchScript -Spec $spec `
                -ExpectedVersion ([string]$record.version) `
                -ExpectedIntegrity ([string]$record.source.integrity) `
                -ExpectedShasum ([string]$record.source.shasum) `
                -Destination $destination `
                -Unpack | Out-Null
            $packageRoot = if ([string]$record.kind -eq "core") {
                Join-Path $destination "package"
            } else {
                Join-Path $destination "package"
            }
            & $node $verifyScript $inventoryPath $packageRoot | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "verify-upstream 失败：$spec" }
            Write-Host "通过：$spec"
        }
    }
    Write-Host "上游实时校验全部通过。"
}
finally {
    if (-not $KeepWork) {
        $tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/')
        $full = [System.IO.Path]::GetFullPath($work)
        if ($full.StartsWith($tempBase + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) -and
            [System.IO.Path]::GetFileName($full).StartsWith("pi-kit-upstream-")) {
            Remove-Item -LiteralPath $full -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
