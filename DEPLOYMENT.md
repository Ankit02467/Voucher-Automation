# Deploying the Voucher module

Written against the code as it stands. Everything here was checked on the
running application, not assumed.

---

## 1. Read this first

`Database/README.md` says to run the migration folders in numeric order. **On a
live database that destroys data.** `04_Updates/02_Reseed_VoucherStatus_Demo.sql`
opens with:

```sql
DELETE FROM dbo.VoucherStock_Table;
DELETE FROM dbo.VoucherProduct_Table;
DELETE FROM dbo.VoucherProvider_Table;
```

Two more scripts overwrite `ExpiryDate` on **every** unused voucher — the field
the whole module exists to track. They are labelled "Demo data only" in a
comment partway down, which is easy to miss when you are running a folder.

Section 2 lists exactly what to run.

`DSL_New` is **shared with the public website**. `dbo.Voucher_Table` and
`dbo.sp_Voucher_Table` belong to that site and hold its live content. Nothing in
this module touches them, and nothing you add should either — SQL object names
are case-insensitive, so a stray `Sp_Voucher_Table` would overwrite the live proc.

---

## 2. Database

### Run, in this order

| Folder | Notes |
|---|---|
| `01_Tables/` | all three |
| `02_StoredProcedures/` | all three |
| `03_SeedData/01_Seed_Voucher.sql` | **only if** you want the sample providers; skip for a real catalogue |
| `04_Updates/01_VoucherStatus_Screen.sql` | schema + procs |
| `04_Updates/04_Rename_Expiry_To_Expired.sql` | schema + procs |
| `05_ViewData/01_VoucherStock_Columns.sql` | schema |
| `05_ViewData/03_Sp_VoucherStock_ViewData.sql` | procs |
| `05_ViewData/04_Fix_BulkInsert_Count.sql` | procs |
| `06_Revision2/01_Schema.sql` | schema |
| `06_Revision2/02_Sp_VoucherProvider.sql` | superseded by 07, harmless |
| `07_Revision3/` | **all five, last — these win** |

### Never run on production

| Script | Why |
|---|---|
| `04_Updates/02_Reseed_VoucherStatus_Demo.sql` | deletes all three voucher tables and reseeds the identities |
| `04_Updates/03_EarlyExpiry_Toggle.sql` | its schema half is fine; the block at the end rewrites `ExpiryDate` on every unused voucher |
| `04_Updates/05_ToBeExpired.sql` | same |
| `05_ViewData/02_Seed_Products.sql` | sample products |
| `05_ViewData/05_Seed_VoucherUsers.sql` | test logins — see below |
| `06_Revision2/04_Students_And_Products.sql` | first half seeds four test students |
| `99_DevSeed/` | 120 demo vouchers; deliberately numbered outside the chain |

For `03_EarlyExpiry_Toggle.sql` and `05_ToBeExpired.sql`, run everything **above**
the comment that reads "Demo data only" and stop there.

### Authoritative proc copies

`Sp_VoucherStock_Table` is defined in **three** places. `07_Revision3/03_Sp_VoucherStock.sql`
runs last and wins; the two copies in `06_Revision2/` are dead. Edit the 07 one.

---

## 3. Test logins must not reach production

`05_ViewData/05_Seed_VoucherUsers.sql` and `06_Revision2/04_Students_And_Products.sql`
create eight enabled accounts, all with the password `Voucher@123`, stored as the
Base64 string `Vm91Y2hlckAxMjM=`. One of them is a full **Voucher Admin**. The
password is written in the script comments, in `CLAUDE.md`, and in the git
history of this repo.

Do not run those scripts. If they have already been run, disable the accounts
(`Status = 0`) and rotate anything reused elsewhere.

Create real users through the existing site's own user administration, with the
same `Type` / `UserType` mapping the seed scripts use (`UserTypeMaster.TypeId = 4`).

---

## 4. Web.config

| Setting | Now | Production |
|---|---|---|
| `connectionString` | `(localdb)\MSSQLLocalDB`, Integrated Security | the real server; see below |
| `compilation debug` | `true` | **`false`** — `true` disables timeouts, bloats output and leaks source paths |
| `customErrors mode` | `Off` | **`RemoteOnly`** with a `defaultRedirect` — `Off` shows stack traces to visitors |
| `sessionState` | `InProc` | fine on one server; a web farm needs StateServer or SQL, and a `<machineKey>` |
| `validateRequest` | `false` | see the note below |

`validateRequest="false"` is off because voucher codes and pasted uploads contain
characters ASP.NET's request validation rejects. Turning it back on breaks the
Upload Entry screen. Leaving it off means nothing filters markup out of input on
the way in, so anywhere user text is written to a page it must be encoded. The
code does encode — `Server.HtmlEncode` throughout — but any new screen has to
keep doing it.

### Connection string

`Integrated Security=True` will not work as-is: under IIS the app runs as the
application pool identity, not as you. Either

- grant the app pool identity access and keep integrated security:
  `Server=SQLPROD;Database=DSL_New;Integrated Security=True;MultipleActiveResultSets=True;`
  then in SQL Server create a login for `IIS APPPOOL\<pool name>` (or the domain
  service account the pool runs as) and give it `db_datareader`, `db_datawriter`
  and `EXECUTE` on the module's procs; **or**

- use a SQL login and keep the password out of the file, via a
  `Web.Release.config` transform or an environment-specific config that is not
  committed. `.gitignore` already excludes `Web.*.config`.

The key **must** stay named `con` — `SqlHelper.cs` reads
`ConnectionStrings["con"]` and every page goes through it.

---

## 5. The overnight auto-move

A voucher checked by a student becomes the sub-admin's at midnight. Two things
do this and they are meant to coexist:

1. **The page-load sweep.** `voucher-data.aspx` runs
   `Sp_VoucherStock_Table @Action='AutoMove'` on every load. It is idempotent and
   normally moves nothing. **Keep it** — it is the safety net.
2. **A scheduled run**, so the move happens at midnight rather than on the first
   visit of the day.

Which scheduler depends on the edition:

- **SQL Server Standard or above** — a SQL Agent job, one step:
  `EXEC dbo.Sp_VoucherStock_Table @Action='AutoMove';` daily at 00:05.
- **SQL Server Express** — Agent is not included. Use Windows Task Scheduler with
  `Tools/Run-AutoMove.ps1`:
  ```
  powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass ^
    -File "C:\path\to\Tools\Run-AutoMove.ps1" -Server "SQLPROD" -Database "DSL_New"
  ```
  The script logs beside itself and exits non-zero on failure, so Task Scheduler
  records the result.

The development machine runs LocalDB, which reports **Express Edition** and has
no Agent — hence the script.

---

## 6. Build and publish

- .NET Framework **4.8** must be installed on the server.
- Build `Release`, not Debug.
- Publish the site folder: the `.aspx`/`.master` files, `bin\`, `assets\`,
  `Web.config`. Not `packages\`, not `obj\`, not the `Database\` or `Tools\`
  folders — those are for you, not the server.
- A clean build is **0 warnings**. If reference warnings come back, check
  `SpecificVersion` on the packaged assemblies; the identities in the `.csproj`
  do not match the DLLs on disk and rely on that flag.
- The app pool must be **.NET CLR v4.0, Integrated**.

---

## 7. After deploying

- Sign in as each of the four roles and open every screen.
- Upload one voucher with a date in `dd-MM-yyyy` and confirm the expiry saved —
  this is the format that used to vanish silently.
- Check `Tools\automove.log` (or the Agent job history) the morning after.
- Confirm a wrong password is refused and that an error page shows no stack trace.

---

## 8. Known gaps, not fixed

Honest list. None of these block a launch behind a company firewall; all of them
matter if the site is reachable from the internet.

- **Passwords are Base64, not hashed.** `login.aspx.cs` encodes the entered
  password and compares strings. Base64 is encoding, not encryption — anyone with
  the table can read every password. This matches the existing site, so changing
  it means changing that too.
- **A user with no voucher role mapped is treated as Voucher Admin.** Deliberate,
  for testing. `voucher-data.aspx.cs`, `voucher-status.aspx.cs` and
  `student-performance.aspx.cs` all do this. On production it should deny instead.
- **The role preview dropdown** on View Data appears for unmapped users and lets
  them switch roles freely. It follows from the point above and disappears with it.
- **No `<authorization>` rules.** Access control is per-page code. Every page does
  check, but a new page that forgets to will be public to any signed-in user.
- **No cookie hardening.** No `<httpCookies requireSSL="true" httpOnlyCookies="true">`,
  and the session id is not regenerated on login.

Two things found this way have already been fixed: Manage Product had no
authorisation at all (a student could create products), and a student could edit
another student's voucher by changing a hidden field. Both were demonstrated
working, then closed, and both are now refused in the stored procedure rather
than only in the page.
