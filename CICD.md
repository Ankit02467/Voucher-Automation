# CI/CD

`azure-pipelines.yml` builds and deploys this module to
`vcheck.dsucceedlearners.com`. Azure DevOps org **Dot-Net-Server**, project
**vcheck**, branch **`uat`**.

Section 6 of [DEPLOYMENT.md](DEPLOYMENT.md) describes doing this by hand. This is
that process, automated, with one deliberate difference: **the pipeline never
deploys `Web.config`.**

## Why the build and the deploy run on different agents

| Stage | Agent | Why |
|---|---|---|
| Build | Microsoft-hosted `windows-latest` | This is a net48 Web Forms app. It needs MSBuild with the web workload, the 4.8 targeting pack and `nuget.exe`. |
| Deploy | self-hosted `cicd-pool` | That agent runs **on the web server**, so deploying is a local file copy — no credentials, no open ports, no WinRM. |

The self-hosted agent cannot build this. It has no Visual Studio, no
`Microsoft.WebApplication.targets`, no .NET Framework reference assemblies and no
`nuget.exe`. The only modern MSBuild on the box ships with SQL Server Management
Studio and has no Roslyn compiler — it fails with:

```
error MSB4019: The imported project "...\Roslyn\Microsoft.CSharp.Core.targets" was not found.
```

Installing Visual Studio Build Tools there would fix it, but that machine hosts
around forty live sites and the hosted agent already has everything. If the org
ever loses its hosted parallel job, installing Build Tools with the
`Microsoft.VisualStudio.Workload.WebBuildTools` workload is the fallback.

The csproj makes this unavoidable, not optional:

```xml
<VSToolsPath Condition="'$(VSToolsPath)' == ''">$(MSBuildExtensionsPath32)\Microsoft\VisualStudio\v$(VisualStudioVersion)</VSToolsPath>
<Import Project="$(VSToolsPath)\WebApplications\Microsoft.WebApplication.targets" Condition="'$(VSToolsPath)' != ''" />
```

`VSToolsPath` always gets a value, so the condition is always true and the import
is never skipped — MSBuild fails hard if the targets file is absent.

## Web.config is owned by the server

The copy in this repo points at `(localdb)\MSSQLLocalDB` with integrated
security. The server's copy holds the real one — SQL authentication against
`webserver-vm-00\SQLEXPRESS`, database `voucher.dsucceedlearners.com`.

`.gitignore` excludes `Web.*.config`, so `Web.Release.config` is not in the repo
and **the publish transform therefore does nothing**. A publish output copied
straight to the server would carry the LocalDB string and the site would fail on
its first query. DEPLOYMENT.md section 4 flags exactly this.

Three independent layers stop that:

1. **The build renames it.** After WebPublish, `Web.config` becomes
   `Web.config.template` and the stage asserts nothing named `Web.config` remains.
   The artifact physically cannot carry one.
2. **`robocopy /MIR /XF Web.config`.** `/XF` excludes a file from the copy *and*
   from `/MIR`'s delete pass — without it, mirroring would delete the server's
   copy for not existing in the source.
3. **Hash verification.** The deploy records SHA-256, size and last-write time
   before touching anything and re-checks them afterwards. If anything moved it
   restores from a pre-deploy copy, recycles the pool, and fails the run. It also
   fails if the string ever comes back mentioning LocalDB.

Layer 3 runs **after** the app pool restarts, on purpose. Finding a problem is not
a reason to leave the site down, so it repairs first and reports second.

`App_Data` and `Uploads` are excluded with `/XD` for the same reason — they only
exist on the server and `/MIR` would delete them.

If `Web.config` is missing from the server the deploy **stops** rather than
inventing one. Seed it from `Web.config.template` in the artifact, set the real
connection string, then re-run. The key must stay named `con`: `SqlHelper.cs`
reads `ConnectionStrings["con"]` and every page goes through it.

## Build command

Taken from DEPLOYMENT.md section 6, unchanged:

```
/t:WebPublish /p:WebPublishMethod=FileSystem /p:publishUrl=<artifact>
/p:DeleteExistingFiles=true /p:DebugSymbols=false /p:DebugType=none
```

`/t:WebPublish` — **not** `/t:Build /p:DeployOnBuild=true`, which exits 0 and
writes nothing. `.pdb` files are stripped afterwards because `ClosedXML.pdb` comes
from the NuGet package rather than the compiler and survives `DebugSymbols=false`.

Restore is `nuget restore`, not `dotnet restore` — this project uses
`packages.config`, not `PackageReference`.

## What the deploy checks

- Site path is read from IIS, never hardcoded; a repointed site fails loudly.
- The app pool is stopped before the copy so `bin\` DLLs are not locked, and
  started again before verification.
- `login.aspx` must return 200 **and contain `__VIEWSTATE`** — a Web Forms error
  page is also a 200, so status alone proves nothing. It also fails if the page
  contains `Server Error in` or `Stack Trace`.
- `dashboard.aspx` must return 302 when signed out, which proves authorisation
  still works after the deploy.

## Rollback

Every run backs the site up first, keeping the last five:

```
C:\deploy-backups\vcheck.dsucceedlearners.com\<build-number>\
```

Restore with robocopy `/MIR` from a backup folder and recycle the pool — and pass
`/XF Web.config` there too, for the same reason.

## Not automated

The database. `Database/` migrations are **not** run by this pipeline and should
not be: DEPLOYMENT.md section 2 lists scripts that delete every voucher row, and
the correct order is not the numeric folder order. Use
`Tools/Deploy-VoucherModule.ps1` deliberately, by hand.
