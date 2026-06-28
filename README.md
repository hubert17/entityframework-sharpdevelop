# Entity Framework 6.2.0 - SharpDevelop 5.x Port

This repository is a customized fork of Entity Framework 6.2.0 ported to target **.NET Framework 4.5.2** and optimized to run inside the **SharpDevelop 5.x** IDE and its Package Management Console (PMC).

---

## Key Porting Changes

### 1. Build System & Target Alignment
- **Explicit Target:** Project target frameworks are explicitly set to `.NET Framework 4.5.2` (via `<TargetFrameworkVersion>v4.5.2</TargetFrameworkVersion>`).
- **Simplification:** Removed legacy .NET 4.0 configurations (`DebugNet40`/`ReleaseNet40`) and SDK multi-targeting rules that SharpDevelop 5's MSBuild engine cannot parse.
- **SQL Server Compact Removal:** Cleaned up and stripped out all legacy SQL Server Compact dependencies and project references.
- **NuGet Path Escaping Fix:** Resolved Windows backslash path escaping issues inside `nuget.targets` and `EFTools.msbuild` when restoring packages.

### 2. PowerShell PMC Migrations Integration
SharpDevelop 5's Package Management Console does not support Visual Studio's `EnvDTE` (`$dte`) or COM Interop assemblies (e.g., `Microsoft.VisualStudio.Interop`). Running the standard EF6 PowerShell module commands natively will fail. 

To resolve this, we implemented:
- **Redirection Proxy Scripts:** Inside the NuGet tools directory, `Add-Migration` and `Update-Database` commands check if they are running inside SharpDevelop (by testing for the presence of native IDE types). If detected, they redirect to:
  - [Add-Migration.ps1](src/NuGet/EntityFramework/tools/Add-Migration.ps1): Scaffolds migrations using the `ToolingFacade` and adds compile/resource files back into the project using SharpDevelop's native `[ICSharpCode.SharpDevelop.Project.ProjectService]` API.
  - [Update-Database.ps1](src/NuGet/EntityFramework/tools/Update-Database.ps1): Invokes database updates out-of-process via `migrate.exe` and `Start-Process`, preventing assembly lock conflicts inside the IDE's main AppDomain.
- **Pure PowerShell XML Config Manipulators:** Dynamic configuration steps (`Initialize-EFConfiguration` and `Add-EFProvider`) were rewritten in pure PowerShell using XML DOM manipulation to bypass VS Interop dependencies and safely update the project's `App.config`/`Web.config`.

---

## Package Name & Unique Identity
To avoid ownership and publishing conflicts on NuGet.org with the original package:
- The package ID has been renamed to **`EntityFramework.SharpDevelop5`**.
- It generates the completed artifact: `bin\Release\NuGet\EntityFramework.SharpDevelop5.6.2.0.nupkg`.

---

## Building the Repository

To build the core assemblies and pack the NuGet package locally, execute the following command:

```cmd
MSBuild.exe EF.msbuild /t:Package /p:Configuration=Release /p:StyleCopEnabled=false /p:RunCodeAnalysis=false /p:BuildCoreOnly=true /p:NuGetPackSymbols=false
```
