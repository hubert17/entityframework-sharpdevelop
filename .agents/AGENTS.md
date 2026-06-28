# Workspace Rules

## Git & Shell Command Execution
- **High-Resource/Token Cost Actions:** For operations with high token usage or interactive prompts (e.g., `git push`, `git fetch`, `git pull`, `git log`, large `git diff`, or commands requiring network authentication), the AI must NOT run them directly. Instead, prompt the user with the exact commands to run locally.
- **Medium to Low Resource/Token Cost Actions:** For lightweight, local, and non-interactive operations (e.g., `git add`, `git commit` [unless heavy pre-commit hooks are active], unstaging files, simple `git status` checks, or local file updates), the AI is permitted to execute them directly to speed up workflows, provided no manual approval loops are triggered.

## Build & Test Operations
- **Verbosity Constraints:** For successful/routine runs, use minimal verbosity to keep context clean.
- **Exception for Failures:** If a build or test fails, use standard or detailed verbosity to ensure the full error messages, stack traces, and compiler warnings are captured for accurate debugging.

## Code Inspection & Search
- **Precise File Views:** Do not read entire large files at once. Read targeted line ranges (using start/end parameters) to locate class definitions or functions.
- **Scoped Searching:** When searching the codebase via grep or ripgrep, scope the query to specific file paths or extensions (e.g. using `Includes` filters) rather than scanning the entire directory.

## Entity Framework 6.2.0 Porting Guidelines

### 1. Build System & Target Framework
- **Explicit Targets:** Hardcode target framework properties explicitly inside `.csproj` configuration files to target `.NET Framework 4.5.2` (e.g., `<TargetFrameworkVersion>v4.5.2</TargetFrameworkVersion>`).
- **Simplify Projects:** Strip out modern `Microsoft.NET.Sdk` formats, multi-targeting rules, and NetStandard/ .NET 4.0 targets that SharpDevelop 5's MSBuild engine cannot parse.
- **Signing & Telemetry:** Remove Microsoft-internal assembly signature configurations (`.snk` references) and custom proprietary pre/post-build tasks. Use standard signing or local keys if needed.

### 2. PowerShell PMC Migrations Integration
- **DTE Limitations:** SharpDevelop 5's PMC does not support Visual Studio's `EnvDTE` (`$dte`) API. Native EF6 PowerShell module commands will fail.
- **Proxy Script Redirection:** When porting or packaging tools, use wrapper/proxy scripts (like `Add-Migration.ps1` and `Update-Database.ps1`) that:
  - Query the active project context via SharpDevelop's native API: `[ICSharpCode.SharpDevelop.Project.ProjectService]::CurrentProject`.
  - Extract the project path, output assembly (`.dll`), and configuration file (`App.config`).
  - Run the migration database update out-of-process by executing `migrate.exe` using `Start-Process`. This prevents assembly loading locks inside the IDE `AppDomain`.

### 3. Version Verification
- Verify that codebase matches EF 6.2.0 via:
  - `src/EntityFramework/Properties/AssemblyInfo.cs`: Must have `AssemblyFileVersion` as `6.2.0.1014` and `AssemblyInformationalVersion` as `6.2.0-61014`.
  - `src/NuGet/EntityFramework/EntityFramework.nuspec`: Must specify version `<version>6.2.0</version>`.
  - Command-line tools: Ensure migration utilizes the classic `migrate.exe` tool (found in `src/Migrate/`) instead of the .NET Core-era `ef6.exe` tool.

## Current Porting Progress (June 2026)
- **Phase 1: Clean Up & Version Verification (Completed)**
  - Fixed trailing solution directory spaces in NuGet target configurations.
  - Removed SQL Server Compact project from the build files.
  - Aligned versions to `6.2.0.1014` file version, `6.2.0-61014` informational version, and `6.2.0` package version.
- **Phase 2: Project Target Alignment (Completed)**
  - Explicitly targeted `.NET Framework 4.5.2` on all core projects and removed conditional .NET 4.0 configuration blocks.
- **Phase 3: PowerShell PMC Redirection (Completed)**
  - Implemented standalone `Add-Migration.ps1` and `Update-Database.ps1` proxy scripts using native SharpDevelop APIs and out-of-process execution.
  - Added redirection logic in `EntityFramework.psm1`.
- **Phase 4: Verification & Walkthrough (Completed)**
  - Fixed console buffer crash in `migrate.exe` when run out-of-process.
  - Verified successful compilation and packaging of `EntityFramework.6.2.0.nupkg`.
