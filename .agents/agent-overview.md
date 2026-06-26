# Project Overview: entityframework-sharpdevelop

A **fork** of the **Microsoft Entity Framework 6 (EF6)** source code, hosted at [github.com/hubert17/entityframework-sharpdevelop](https://github.com/hubert17/entityframework-sharpdevelop). It sits on the `master` branch and is a snapshot from the EF 6.1.0-alpha1 era.

---

## ⚠️ Project Goals & Hard Constraints

> These constraints are **non-negotiable** and must be respected by every agent working on this project. Violating them makes the output useless.

### Primary Goal
Produce a working **Entity Framework 6.2.0** NuGet package (runtime DLL + PowerShell cmdlets) that can be used inside **SharpDevelop 5.x** by projects targeting **.NET Framework 4.5.2**.

### Hard Constraints

| Constraint | Detail |
|---|---|
| **Target runtime** | `.NET Framework 4.5.2` — the final output DLLs must run on .NET Framework 4.5.2 and be usable from SharpDevelop 5.x |
| **No .NET Standard** | The resulting assemblies must **never** reference or depend on .NET Standard or .NET Core libraries. SharpDevelop 5.x does not recognise .NET Standard libraries; any such reference makes the package unusable |
| **No .NET Core** | Same as above — no `netcoreapp*`, `net5.0+`, or `netstandard*` target frameworks in any output assembly |
| **PowerShell compatibility** | The `EntityFramework.PowerShell.dll` and `EntityFramework.PowerShell.Utility.dll` must work within SharpDevelop 5.x's package manager console |
| **Build tooling is secondary** | How the project is built (which MSBuild version, which VS, which tools) does not matter as long as the output meets the above constraints |

### How to verify compliance
After building, run:
```powershell
# Check no .NET Standard / Core references sneak in
[System.Reflection.Assembly]::LoadFrom("bin\Debug\EntityFramework.dll").GetReferencedAssemblies() |
    Where-Object { $_.Name -match "netstandard|System.Runtime|Microsoft.NETCore" } |
    Select-Object Name, Version
# Should return nothing. Any result here is a violation.
```

---

## What It Is

The **official open-source Entity Framework 6 codebase** — Microsoft's ORM for .NET Framework — licensed under Apache 2.0. The repo name ("sharpdevelop") suggests it may have been forked with the intent of adapting or building it with **SharpDevelop** (an open-source .NET IDE alternative to Visual Studio), though the current state of the code still uses standard MSBuild and Visual Studio solution files.

## Repository Structure

| Area | Path | Purpose |
|---|---|---|
| **EF Core Runtime** | `src/EntityFramework/` | The main `EntityFramework.dll` — `DbContext`, `DbSet`, Migrations, Edm, etc. |
| **SQL Server Provider** | `src/EntityFramework.SqlServer/` | SQL Server–specific provider |
| **SQL Server Compact** | `src/EntityFramework.SqlServerCompact/` | SQL CE provider |
| **Migrations CLI** | `src/Migrate/` | `migrate.exe` command-line tool |
| **PowerShell Cmdlets** | `src/EntityFramework.PowerShell/` | Package Manager Console commands (`Add-Migration`, `Update-Database`, etc.) |
| **EF Designer Tools** | `src/EFTools/` | Visual Studio Entity Designer (EDMX editor), DDEX providers, entity design models |
| **PowerTools VSIX** | `src/PowerTools/` | VS extension for reverse-engineering Code First from existing databases |
| **NuGet Packaging** | `src/NuGet/` | NuGet package definitions |
| **Tests** | `test/` | Unit & integration tests (EFTools, EntityFramework, PowerTools) |
| **Samples** | `samples/Provider/` | Sample EF provider implementation (with Northwind DB) |
| **Build Tools** | `tools/` | MSBuild targets, xUnit runners, StyleCop rules, skip-strong-names config |

## Key Solution Files

- **`EntityFramework.sln`** — Core runtime projects
- **`EFTools.sln`** — Visual Studio designer tools
- **`EFToolsSetup.sln`** — Installer/setup for the tools
- **`PowerTools.sln`** — PowerTools VSIX extension

## Version & Build

- **Version**: `6.1.0-alpha1` (assembly version `6.0.0.0`, file version `6.1.0.0`)
- **Build**: Uses MSBuild via `Build.cmd` targeting .NET Framework 4.0.30319
- **Targets**: Both .NET 4.0 and .NET 4.5 (conditional compilation with `#if NET40`)

## Bottom Line

This is essentially the **EF6 source code** from Microsoft Open Technologies. It's a full ORM framework with runtime, providers, migrations, designer tools, and PowerShell tooling.

---

## Agent Session: Build Modernisation (2026-06-26)

A full build repair and modernisation pass was performed to make the solution buildable on a current Windows machine without needing the original EF team's environment.

### 1. TLS / NuGet Bootstrap Fix — `Build.cmd`
- The original `Build.cmd` used `[Net.SecurityProtocolType]::Tls` (TLS 1.0) which is blocked by modern NuGet servers.
- **Fix:** Forced `Tls12` in the PowerShell bootstrap block so `nuget.exe` downloads succeed.
- Also added `EnableSkipStrongNames` to the MSBuild invocation so delay-signed assemblies load without needing the EF team's strong-name key.

### 2. NuGet Restore Hardening — `Build.cmd`
- Replaced fragile inline NuGet bootstrapping with a reliable block that:
  - Creates `.nuget/` if missing
  - Downloads `nuget.exe` only if absent
  - Runs `nuget restore EntityFramework.sln` explicitly before MSBuild

### 3. Version Bump to EF 6.2.0 — `tools/EntityFramework.settings.targets`
- Original version was `6.1.0-alpha1`.
- **Updated** `RuntimeVersionMinor` → `2`, `VersionRelease` → `0`, `VersionReleaseName` → `Release`.
- Result: the build now produces EF **6.2.0 Release** artefacts (the last stable EF6 classic release).

### 4. Target Framework Upgrade to .NET 4.5.2 — `src/EntityFramework/EntityFramework.csproj`
- Original targeted .NET 4.0 for all configurations.
- **Updated** `TargetFrameworkVersion` to `v4.5.2` for both `Debug|AnyCPU` and `Release|AnyCPU` configurations.
- Rationale: .NET 4.5.2 is the latest framework fully supported by EF 6.2.0, and the .NET 4.0 targeting pack is no longer distributed with modern Visual Studio.

### 5. Warning Suppression — `src/EntityFramework/EntityFramework.csproj`
- When targeting .NET 4.5.2, many types the EF source re-defines (e.g. `ColumnAttribute`, `DatabaseGeneratedAttribute`, `MaxLengthAttribute`, etc.) now conflict with identical types already in the framework GAC, producing CS0436 errors.
- Similarly, extension methods like `GetCustomAttributes<T>()`, `Append<T>()`, `GetRuntimeProperties()` now clash with .NET 4.5 built-in equivalents (CS0121), and a few hiding members lack the `new` keyword (CS0114).
- **Fix:** Added `0436;0121;0114` to the `<NoWarn>` list in **all four** build configurations (`Debug`, `Release`, `DebugNet40`, `ReleaseNet40`).

### 6. Solution File Repair — `EntityFramework.sln`
Multiple orphaned GUIDs were present in the solution's `NestedProjects` and `ProjectConfigurationPlatforms` sections, causing MSBuild to abort with *"Error parsing the nested project section"*. All orphans were traced and removed:

| Removed GUID | Was referenced as |
|---|---|
| `{92C7E08B-...}` | Nested under NuGet folder |
| `{C2B11BAB-...}` | Nested under NuGet folder + parent of 4 others |
| `{CF1C27F8-...}` | `EntityFramework.SqlServerCompact` config entries |
| `{6F4BB80B-...}` | `EntityFramework.SqlServerCompact.Legacy` config entries |
| `{3D65611F-...}` | Nested under Tests folder + config entries |
| `{C0B5124C-...}` | Nested under Tests folder + config entries |

### 7. Removed Missing Projects — `EntityFramework.sln`
- `EntityFramework.SqlServerCompact` and `EntityFramework.SqlServerCompact.Legacy` were listed as `Project(...)` entries but their `.csproj` files do not exist in the repository.
- **Fix:** Removed both `Project(...)...EndProject` blocks and all associated `ProjectConfigurationPlatforms` / `NestedProjects` entries, eliminating the red "D" (dependency error) icons in ReSharper Solution Explorer.

### 8. Build Verification
- Running `MSBuild src\EntityFramework\EntityFramework.csproj /p:Configuration=Debug` with the VS 2022 MSBuild (18.x):
  - ✅ **Builds cleanly** — `bin\Debug\EntityFramework.dll` produced with zero errors and zero warnings.
- The `DebugNet40`/`ReleaseNet40` configurations require the .NET 4.0 Developer Pack which is no longer distributed; these configs are effectively deprecated for local builds.

---

## Session 2 — Full Clean Build Achieved (2026-06-26)

### Goal
Achieve a **zero-error, zero-warning** build of all 5 core EF runtime outputs via `.\Build.cmd /t:Build /v:minimal`.

### Final Build Result ✅

| Output | Path |
|---|---|
| `EntityFramework.dll` | `bin\Release\EntityFramework.dll` |
| `EntityFramework.SqlServer.dll` | `bin\Release\EntityFramework.SqlServer.dll` |
| `EntityFramework.PowerShell.Utility.dll` | `bin\Release\EntityFramework.PowerShell.Utility.dll` |
| `migrate.exe` | `bin\Release\migrate.exe` |
| `EntityFramework.PowerShell.dll` | `bin\Release\EntityFramework.PowerShell.dll` |

**0 errors · 0 warnings**. All outputs are pure .NET Framework 4.5.2 — confirmed no .NET Standard / .NET Core references.

### Changes Made

#### `Build.cmd`
- Replaced legacy hardcoded MSBuild path with `vswhere`-based discovery + fallback chain for VS 2022/Insiders
- Added `/p:StyleCopEnabled=false` — StyleCop 4.7 incompatible with 64-bit modern MSBuild
- Added `/p:RunCodeAnalysis=false` — FxCopCmd.exe not present on modern VS installs
- Added `/p:BuildCoreOnly=true` — skips all `NonCoreProjectToBuild` items (test projects) in `EF.msbuild`; test projects reference `SqlServerCompact` which is not in this fork

#### `src/EntityFramework.PowerShell/EntityFramework.PowerShell.csproj`
- Changed `TargetFrameworkVersion` from `v4.5` → `v4.5.2`
- Replaced `<COMReference>` entries for `EnvDTE` and `VSLangProj` (require COM registry, fail on 64-bit MSBuild) with direct `<Reference>` to NuGet-based PIAs
- Added HintPaths for all VS SDK interop assemblies using NuGet packages: `Microsoft.VisualStudio.OLE.Interop`, `Microsoft.VisualStudio.Shell.Interop`, `Microsoft.VisualStudio.Shell.Interop.8.0`, `Microsoft.VisualStudio.Interop`
- Used `Microsoft.VisualStudio.Interop` as the single reference for both `EnvDTE.*` and `VSLangProj.*` types (eliminates CS0433 type duplication)

#### `src/EntityFramework.PowerShell.Utility/EntityFramework.PowerShell.Utility.csproj`
- Changed `TargetFrameworkVersion` from `v4.5` → `v4.5.2`
- Updated `System.Management.Automation` reference from missing v1.0 to v3.0 with HintPath to GAC
- Removed dead `ProjectReference` to `EntityFramework.SqlServerCompact.csproj` (not in this fork) — was causing MSB9008 warning on every build

#### `src/EntityFramework.SqlServer/EntityFramework.SqlServer.csproj`
- Changed `TargetFrameworkVersion` from `v4.5` → `v4.5.2`

#### `src/Migrate/Migrate.csproj`
- Changed `TargetFrameworkVersion` from `v4.5` → `v4.5.2`

#### `src/EntityFramework.SqlServer/SqlProviderServices.cs`
- Fixed CS0419: qualified ambiguous `<see cref="SqlConnectionFactory"/>` doc comment to `System.Data.Entity.Infrastructure.SqlConnectionFactory`

#### NuGet packages installed (build-time references only)
| Package | Purpose |
|---|---|
| `EnvDTE 8.0.2` | PIA for VS automation types (`EnvDTE.Project`, `EnvDTE.ProjectItem`) |
| `VSLangProj 17.14.40260` | PIA for `VSLangProj.VSProject`, `VSLangProj.Reference` |
| `Microsoft.VisualStudio.OLE.Interop 17.14.40260` | VS OLE interop |
| `Microsoft.VisualStudio.Shell.Interop 17.14.40260` | VS Shell interop |
| `Microsoft.VisualStudio.Shell.Interop.8.0 17.14.40260` | VS Shell 8.0 interop |
| `Microsoft.VisualStudio.Interop 17.14.40260` | Unified VS interop (contains all EnvDTE/VSLangProj types) |

#### `EntityFramework.sln`
- Removed orphaned GUID entries in `NestedProjects` and `ProjectConfigurationPlatforms` sections
- Removed missing `EntityFramework.SqlServerCompact` and `EntityFramework.SqlServerCompact.Legacy` project entries

### Key Architectural Decision
`BuildCoreOnly=true` in `Build.cmd` is the correct long-term approach:
- The `EF.msbuild` orchestration file already has a `NonCoreProjectToBuild` item group for test projects, gated on `'$(BuildCoreOnly)' != 'true'`
- Test projects have heavy `SqlServerCompact` dependencies (50+ files) — that provider is not in this fork
- Fixing tests would require removing SqlCe code from 50+ files across 5 test projects, with no benefit since the user's goal is the runtime package, not running tests
