# Aeries-Google-Asset-Sync
syncs chromebook information from Google Workspace to Aeries Assets for the purpose of assigning and checking out chromebooks. The student who it's assigned to is written back into Google Workspace.

## Config
Looks for config files in individual named directories at:

```C:\Users\<username>\AppData\Local\powershell\SPSAeriesAssetSync\<Config Name>\DistrictAssetConfig.ps1```

## Versioning

The manifest owns the **major and minor** version. CI owns the **patch**.

On a push to `main`, `build.ps1` reads `ModuleVersion` out of `SPSAeriesAssetSync.psd1`,
swaps the patch for the GitHub Actions run number, and the `deploy` job publishes
`<major>.<minor>.<run_number>` to the PowerShell Gallery. Published versions therefore
always increase, and a release can never collide with one already on the gallery.

| Where | Value | Who changes it |
| --- | --- | --- |
| `SPSAeriesAssetSync/SPSAeriesAssetSync.psd1` | `0.3.0` | You, by hand, for a feature or breaking change |
| `.github/workflows/deploy.yml` | `patch: ${{ github.run_number }}` | Nobody — supplied fresh each run |
| PowerShell Gallery | `0.3.<run_number>` | Published by the `deploy` job |

Running `./build.ps1` locally without a patch number leaves the manifest untouched and
just reports the current version, so the module still imports straight from a clone.

### Cutting a release

1. Bump the minor in `SPSAeriesAssetSync.psd1` (`0.3.0` -> `0.4.0`) for anything beyond a fix.
2. Add an entry under [Changelog](#changelog) below.
3. Mirror that entry into `ReleaseNotes` in the manifest's `PSData` block — that is the
   text shown on the module's PowerShell Gallery page.
4. Merge to `main`. The `deploy` job publishes automatically.

## Changelog

### 0.4.0

- `Sync-ChromebooksFromGoogleToAeries` and `Sync-CBDataFromAeriesToGoogle` take a new
  `-DetailedLogging` switch, off by default. The verbose lines that reported each item
  merely being examined - one per device, every run, whether or not anything changed -
  are now behind it. A `-Verbose` run reports what changed rather than what was
  inspected, which keeps `Sync-DistrictAssets.ps1` transcripts readable and clear of the
  5000-line truncation that prompted the 0.3.0 summary work. Pass `-DetailedLogging` to
  get the per-device lines back when tracking down a single asset;
  `-DetailedLogging:$false` is the explicit form of the default.
- Two of those lines passed a hashtable to `Write-Verbose`'s `[string]` parameter and so
  printed the literal text `System.Collections.Hashtable`. They now render their
  contents, and are also behind `-DetailedLogging`.
- Comment-based help on both functions now documents `config` and `DetailedLogging`.
- Logging only: what is written to Aeries and Google is unchanged.

### 0.3.0

- `Sync-ChromebooksFromGoogleToAeries`: model names longer than 60 characters are still
  truncated the same way, but `-Verbose` now emits a single summary of what was truncated
  and how many devices each model affected, instead of two lines per device. On a
  district-wide sync this replaces thousands of lines with a handful. The truncation
  logic and the values written to Aeries are unchanged.
- Restored build-time versioning, which had been inert since `0.2.0`:
  - `build.ps1` resolved the manifest through `$env:SYSTEM_DEFAULTWORKINGDIRECTORY`, an
    Azure DevOps variable that is unset on GitHub Actions, so it looked for the manifest
    at an absolute `/SPSAeriesAssetSync` path that does not exist. It now resolves the
    path relative to its own location.
  - `build.ps1` read `$env:BUILDVER` while the workflow set `buildVer`. Environment
    variables are case-sensitive on the Linux runners, so the value was always empty.
    The patch number is now passed explicitly as `-Patch`, or read from `$env:patch`.
  - Both failures were non-terminating, so the build step reported success while doing
    nothing. `build.ps1` now sets `$ErrorActionPreference = 'Stop'` and validates its
    input, so a broken build fails the job instead of passing silently.
  - The manifest had a hardcoded `ModuleVersion = '0.2.0'` where `build.ps1` expected a
    `<ModuleVersion>` placeholder. The manifest now carries a real, valid version that
    imports locally, and CI rewrites only the patch component.
- Fixed comment-based help, which PowerShell had been discarding wholesale. A bare
  `.PARAMETER` keyword with no parameter name after it invalidates the entire help
  comment, so `Get-Help` showed only an auto-generated syntax line and no synopsis,
  description, examples or notes. This affected all four public Sync functions.
- Documented the truncation behaviour in `Sync-ChromebooksFromGoogleToAeries`'s `.NOTES`.
- Added `ProjectUri` and `ReleaseNotes` to the manifest so the gallery listing links back
  here and shows what changed.

### 0.2.0

Published to the PowerShell Gallery on 2025-01-31. Refactored function calls for Aeries
integration.

> Note: `0.2.0` is the only version that ever reached the gallery. Every `main` build
> between 2025-01-31 and the `0.3.0` work above failed at the publish step with
> *"the current version '0.2.0' is already available in the repository"*, because the
> version was pinned in source and the build-time substitution had been disabled.
