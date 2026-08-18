#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Spec,
    [Parameter(Mandatory = $true)][string]$ExpectedVersion,
    [Parameter(Mandatory = $true)][string]$ExpectedIntegrity,
    [Parameter(Mandatory = $true)][string]$ExpectedShasum,
    [Parameter(Mandatory = $true)][string]$Destination,
    [switch]$Unpack
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$npmCommand = @(Get-Command "npm.cmd" -CommandType Application -ErrorAction Stop)[0].Source
$tarCommand = Join-Path $env:SystemRoot ("System32" + [char]92 + "tar.exe")
if (-not (Test-Path -LiteralPath $tarCommand)) { throw "找不到 Windows tar.exe" }

function Get-Sha512Integrity {
    param([Parameter(Mandatory)][string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $hash = [System.Security.Cryptography.SHA512]::HashData($bytes)
    return "sha512-" + [Convert]::ToBase64String($hash)
}

New-Item -ItemType Directory -Path $Destination -Force | Out-Null

$viewOutput = @(& $npmCommand "view" $Spec "version" "dist.integrity" "dist.shasum" "--json" 2>$null)
if ($LASTEXITCODE -ne 0) {
    throw "npm view 失败：$Spec"
}
$metadata = ($viewOutput -join [Environment]::NewLine) | ConvertFrom-Json -Depth 10
$records = if ($metadata -is [System.Array]) { @($metadata) } else { @($metadata) }
$record = $records | Where-Object { [string]$_.version -eq $ExpectedVersion } | Select-Object -First 1
if ($null -eq $record) {
    throw "npm view 未返回预期版本 $ExpectedVersion：$Spec"
}
if ([string]$record."dist.integrity" -cne $ExpectedIntegrity) {
    throw "registry integrity 不匹配：$Spec"
}
if ([string]$record."dist.shasum" -cne $ExpectedShasum) {
    throw "registry shasum 不匹配：$Spec"
}

$packOutput = @(& $npmCommand "pack" $Spec "--pack-destination" $Destination "--json")
if ($LASTEXITCODE -ne 0) {
    throw "npm pack 失败：$Spec"
}
$parsed = ($packOutput -join [Environment]::NewLine) | ConvertFrom-Json -Depth 20
$packRecords = if ($parsed -is [System.Array]) {
    @($parsed)
} elseif ($null -ne $parsed.PSObject.Properties["version"]) {
    @($parsed)
} else {
    @($parsed.PSObject.Properties | ForEach-Object { $_.Value })
}
$packRecord = $packRecords | Where-Object { [string]$_.version -eq $ExpectedVersion } | Select-Object -First 1
if ($null -eq $packRecord) {
    throw "npm pack 未返回唯一记录：$Spec"
}
$archivePath = Join-Path $Destination ([string]$packRecord.filename)
if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
    throw "npm pack 未生成 tarball：$archivePath"
}
$actualShasum = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA1).Hash.ToLowerInvariant()
$actualIntegrity = Get-Sha512Integrity -Path $archivePath
if ($actualShasum -cne $ExpectedShasum) {
    throw "tarball SHA-1 不匹配：$actualShasum"
}
if ($actualIntegrity -cne $ExpectedIntegrity) {
    throw "tarball integrity 不匹配：$actualIntegrity"
}

$extractRoot = Join-Path $Destination "package"
if ($Unpack) {
    if (Test-Path -LiteralPath $extractRoot) {
        Remove-Item -LiteralPath $extractRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $extractRoot | Out-Null
    & $tarCommand -xf $archivePath -C $extractRoot --strip-components 1
    if ($LASTEXITCODE -ne 0) {
        throw "tar 解包失败：$archivePath"
    }
}

Write-Host "官方包校验通过：$Spec"
Write-Host "Archive: $archivePath"
if ($Unpack) {
    Write-Host "Unpacked: $extractRoot"
}
