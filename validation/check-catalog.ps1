#Requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { $failures.Add($Message) }
}

function Read-Json {
    param([Parameter(Mandatory)][string]$Path)
    Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100
}

foreach ($catalogPath in @(
    (Join-Path $root "catalog\core.json"),
    (Join-Path $root "catalog\extensions.json")
)) {
    if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
        $failures.Add("缺少 catalog：$catalogPath")
        continue
    }
    $catalog = Read-Json -Path $catalogPath
    Assert-True -Condition ([int]$catalog.schemaVersion -eq 1) -Message "catalog schemaVersion 无效：$catalogPath"
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($record in @($catalog.packages)) {
        $name = [string]$record.name
        $version = [string]$record.version
        $identity = "$name@$version"
        Assert-True -Condition ($seen.Add($identity)) -Message "catalog 包重复：$identity"
        Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string]$record.inventory)) -Message "catalog 缺少 inventory：$identity"
        $inventoryPath = Join-Path $root ([string]$record.inventory)
        Assert-True -Condition (Test-Path -LiteralPath $inventoryPath -PathType Leaf) -Message "inventory 不存在：$inventoryPath"
        if (-not (Test-Path -LiteralPath $inventoryPath -PathType Leaf)) { continue }
        $inventory = Read-Json -Path $inventoryPath
        Assert-True -Condition ([int]$inventory.schemaVersion -eq 1) -Message "inventory schemaVersion 无效：$inventoryPath"
        Assert-True -Condition ([string]$inventory.package.name -ceq $name) -Message "inventory 包名不匹配：$inventoryPath"
        Assert-True -Condition ([string]$inventory.package.version -ceq $version) -Message "inventory 版本不匹配：$inventoryPath"
        Assert-True -Condition ([string]$record.source.integrity -ceq [string]$inventory.source.integrity) -Message "integrity 不匹配：$identity"
        Assert-True -Condition ([string]$record.source.shasum -ceq [string]$inventory.source.shasum) -Message "shasum 不匹配：$identity"
        Assert-True -Condition (@($inventory.files).Count -eq [int]$record.fileCount) -Message "fileCount 不匹配：$identity"
        $stringCount = (@($inventory.files | ForEach-Object { if ($_.PSObject.Properties.Name -contains "stringCount") { [int]$_.stringCount } else { 0 } }) | Measure-Object -Sum).Sum
        Assert-True -Condition ($stringCount -eq [int]$record.stringCount) -Message "stringCount 不匹配：$identity"
        foreach ($file in @($inventory.files)) {
            $hasPayload = $file.PSObject.Properties.Name -contains "replacements" -or $file.PSObject.Properties.Name -contains "localizedSha256"
            Assert-True -Condition (-not $hasPayload) -Message "inventory 泄露翻译载荷：$inventoryPath / $($file.path)"
        }
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Host "catalog 校验通过：core 与 extensions 的 registry 元数据、inventory 引用和载荷边界一致。"
