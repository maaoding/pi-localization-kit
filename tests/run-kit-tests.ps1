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

function Get-TextHash {
    param([Parameter(Mandatory)][string]$Text)
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Text)
    return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes))
}

function New-FilledFixtureManifest {
    param(
        [Parameter(Mandatory)][string]$InventoryPath,
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$PackagePath
    )
    $result = Invoke-Node -Arguments @(
        (Join-Path $root "tools\generate-local-manifest.mjs"), $InventoryPath, $ManifestPath
    )
    Assert-True -Condition ($result.ExitCode -eq 0) -Message "generate-local-manifest 失败：$($result.Output)"
    $manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100
    $index = @($manifest.files | Where-Object path -eq "index.txt")[0]
    $keep = @($manifest.files | Where-Object path -eq "keep.txt")[0]
    $index.replacements = @([pscustomobject]@{ id = "fixture:hello"; from = "Hello world"; to = "Hallo Welt"; expectedCount = 1 })
    $keep.replacements = @([pscustomobject]@{ id = "fixture:plain"; from = "plain text only"; to = "nur Text"; expectedCount = 1 })
    $indexUpstream = [System.IO.File]::ReadAllText((Join-Path $PackagePath "index.txt"), [System.Text.UTF8Encoding]::new($false))
    $keepUpstream = [System.IO.File]::ReadAllText((Join-Path $PackagePath "keep.txt"), [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText(
        $ManifestPath,
        (($manifest | ConvertTo-Json -Depth 100) + [Environment]::NewLine),
        [System.Text.UTF8Encoding]::new($false)
    )
}

New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
try {
    $fixtures = Join-Path $root "tests\fixtures"
    $inventory = Join-Path $fixtures "inventory-a.json"
    $oldInventory = Join-Path $fixtures "inventory-old.json"
    $fixturePackage = Join-Path $fixtures "pkg-a"

    $result = Invoke-Node -Arguments @(
        (Join-Path $root "tools\verify-upstream.mjs"), $inventory, $fixturePackage
    )
    Assert-True -Condition ($result.ExitCode -eq 0) -Message "verify-upstream 未通过：$($result.Output)"

    $tampered = Join-Path $testRoot "tampered-pkg"
    Copy-Item -LiteralPath $fixturePackage -Destination $tampered -Recurse
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

    $manifest = Join-Path $testRoot "local-manifest.json"
    New-FilledFixtureManifest -InventoryPath $inventory -ManifestPath $manifest -PackagePath $fixturePackage

    $result = Invoke-Node -Arguments @(
        (Join-Path $root "tools\compute-manifest-hashes.mjs"), $manifest, $fixturePackage
    )
    Assert-True -Condition ($result.ExitCode -eq 0) -Message "compute-manifest-hashes 未通过：$($result.Output)"

    $result = Invoke-Node -Arguments @(
        (Join-Path $root "tools\check-manifest-local.mjs"), $manifest, $fixturePackage
    )
    Assert-True -Condition ($result.ExitCode -eq 0) -Message "check-manifest-local 未通过：$($result.Output)"

    $applyPackage = Join-Path $testRoot "apply-pkg"
    Copy-Item -LiteralPath $fixturePackage -Destination $applyPackage -Recurse
    $result = Invoke-Node -Arguments @(
        (Join-Path $root "tools\apply-local-manifest.mjs"), $manifest, $applyPackage
    )
    Assert-True -Condition ($result.ExitCode -eq 0) -Message "apply-local-manifest 失败：$($result.Output)"
    $applied = [System.IO.File]::ReadAllText((Join-Path $applyPackage "index.txt"), [System.Text.UTF8Encoding]::new($false))
    Assert-True -Condition ($applied.Contains("Hallo Welt")) -Message "apply-local-manifest 未写入本地化文本"

    Write-Host "套件工具合成测试通过：verify/diff/audit/generate/check/apply。"
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
