#Requires -Version 7.0
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))

& (Join-Path $root "validation\check-catalog.ps1")
& (Join-Path $root "validation\check-inventory.ps1")
& (Join-Path $root "validation\check-manifest-local.ps1")
& (Join-Path $root "tests\run-kit-tests.ps1")
Write-Host "套件验证全部通过。"
