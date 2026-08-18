#Requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$node = @(Get-Command node.exe -CommandType Application -ErrorAction Stop)[0].Source
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pi-kit-tests-" + [guid]::NewGuid().ToString("N"))

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw "断言失败：$Message" }
}

function Invoke-Node {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(& $node @Arguments 2>&1)
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output = ($output | Out-String).Trim()
    }
}

New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
try {
    $fixtures = Join-Path $root "tests\fixtures"
    $inventory = Join-Path $fixtures "inventory-a.json"
    $oldInventory = Join-Path $fixtures "inventory-old.json"

    $result = Invoke-Node -Arguments @(
        (Join-Path $root "tools\verify-upstream.mjs"), $inventory, (Join-Path $fixtures "pkg-a")
    )
    Assert-True -Condition ($result.ExitCode -eq 0) -Message "verify-upstream 未通过：$($result.Output)"

    $tampered = Join-Path $testRoot "tampered-pkg"
    Copy-Item -LiteralPath (Join-Path $fixtures "pkg-a") -Destination $tampered -Recurse
    Add-Content -LiteralPath (Join-Path $tampered "index.txt") -Value "tampered"
    $result = Invoke-Node -Arguments @(
        (Join-Path $root "tools\verify-upstream.mjs"), $inventory, $tampered
    )
    Assert-True -Condition ($result.ExitCode -ne 0) -Message "verify-upstream 未检出篡改"

    $result = Invoke-Node -Arguments @(
        (Join-Path $root "tools\diff-inventory.mjs"), $oldInventory, $inventory
    )
    Assert-True -Condition ($result.ExitCode -eq 0 -and $result.Output -match "\+ keep\.txt") -Message "diff-inventory 输出异常：$($result.Output)"

    $result = Invoke-Node -Arguments @(
        (Join-Path $root "tools\audit-strings.mjs"), (Join-Path $fixtures "pkg-a\index.txt")
    )
    Assert-True -Condition ($result.ExitCode -eq 0 -and $result.Output -match "Hello world") -Message "audit-strings 未提取候选文案：$($result.Output)"

    $localManifest = Join-Path $testRoot "local-manifest.json"
    $result = Invoke-Node -Arguments @(
        (Join-Path $root "tools\generate-local-manifest.mjs"), $inventory, $localManifest
    )
    Assert-True -Condition ($result.ExitCode -eq 0) -Message "generate-local-manifest 失败：$($result.Output)"
    $manifest = Get-Content -LiteralPath $localManifest -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100
    Assert-True -Condition (@($manifest.files).Count -eq 2) -Message "生成 manifest 文件数错误"
    Assert-True -Condition (@($manifest.files | Where-Object { @($_.replacements).Count -ne 0 }).Count -eq 0) -Message "生成 manifest 不应预置翻译载荷"

    Write-Host "套件工具合成测试通过：verify-upstream、diff-inventory、audit-strings、generate-local-manifest。"
}
finally {
    $tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/')
    $full = [System.IO.Path]::GetFullPath($testRoot)
    $prefix = $tempBase + [System.IO.Path]::DirectorySeparatorChar
    if ($full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) -and
        [System.IO.Path]::GetFileName($full).StartsWith("pi-kit-tests-")) {
        Remove-Item -LiteralPath $full -Recurse -Force -ErrorAction SilentlyContinue
    }
}
