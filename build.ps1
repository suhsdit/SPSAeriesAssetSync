<#
.SYNOPSIS
    Stamps the CI build number into the module manifest before packaging.
.DESCRIPTION
    Major and minor versions are owned by SPSAeriesAssetSync.psd1 and are bumped
    by hand. The patch number is supplied by CI (the GitHub Actions run number),
    so published versions always increase and never collide on PSGallery.

    Run with no patch number (a normal local clone) and the manifest is left
    exactly as it is, so the module still imports straight from source.
.PARAMETER Patch
    Patch number to stamp in. Defaults to the 'patch' environment variable,
    which the deploy workflow sets to github.run_number.
.EXAMPLE
    ./build.ps1
    Leaves the manifest untouched and reports the current version.
.EXAMPLE
    ./build.ps1 -Patch 42
    Rewrites ModuleVersion to <major>.<minor>.42.
#>
[CmdletBinding()]
param(
    [string]$Patch = $env:patch
)

# Make every failure terminating. Without this the script reports success to CI
# even when it cannot find or write the manifest.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$moduleName   = 'SPSAeriesAssetSync'
$manifestPath = Join-Path -Path $PSScriptRoot -ChildPath $moduleName |
                Join-Path -ChildPath "$moduleName.psd1"

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Module manifest not found at '$manifestPath'."
}

$currentVersion = [version](Import-PowerShellDataFile -LiteralPath $manifestPath).ModuleVersion
Write-Host "Manifest version: $currentVersion"

if ([string]::IsNullOrWhiteSpace($Patch)) {
    Write-Host 'No patch number supplied; leaving the manifest unchanged.'
    return
}

if ($Patch -notmatch '^\d+$') {
    throw "Patch must be a non-negative integer, got '$Patch'."
}

$buildVersion = '{0}.{1}.{2}' -f $currentVersion.Major, $currentVersion.Minor, $Patch

$content = Get-Content -LiteralPath $manifestPath -Raw
$updated = $content -replace "(?m)^(\s*ModuleVersion\s*=\s*')[^']*(')", "`${1}$buildVersion`${2}"

if ($updated -eq $content) {
    throw "Could not find a ModuleVersion entry to update in '$manifestPath'."
}

Set-Content -LiteralPath $manifestPath -Value $updated -NoNewline
Write-Host "ModuleVersion set to $buildVersion"
