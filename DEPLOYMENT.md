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

### Use the script

```powershell
Tools\Deploy-VoucherModule.ps1 -Server SQLPROD -Database DSL_New `
    -User dbadmin -Password *** -MasterKeyPassword '<pick one, write it down>'
```

It runs exactly the list below, in the order below, skipping everything in
*Never run on production*. `-ListOnly` prints the order without connecting;
`-WithTestUsers` adds the accounts in section 3, and should stay off.

It also repoints `USE DSL_New` at `-Database`, so a database with a different
name — or with dots in it — works without editing thirty files.

### Run, in this order

Numeric folder order is **not** the working order. Two of these are out of
sequence and both have to be.

| # | Script | Notes |
|---|---|---|
| 1–3 | `01_Tables/` | all three |
| 4–6 | `02_StoredProcedures/` | all three |
| — | `03_SeedData/01_Seed_Voucher.sql` | **skip.** Seeds `Pearson VUE`, `Prometric`, `IELTS - IDP`… — not the real catalogue, and not what `07_Revision3/01` expects |
| 7 | `04_Updates/01_VoucherStatus_Screen.sql` | schema + procs |
| 8 | `04_Updates/04_Rename_Expiry_To_Expired.sql` | schema + procs |
| 9 | `05_ViewData/01_VoucherStock_Columns.sql` | schema, **and the four `TypeId = 4` roles** |
| 10 | `05_ViewData/03_Sp_VoucherStock_ViewData.sql` | procs — this is where `Sp_VoucherUser_Table` lives |
| 11 | `05_ViewData/04_Fix_BulkInsert_Count.sql` | procs |
| 12 | `06_Revision2/01_Schema.sql` | schema |
| 13 | `06_Revision2/02_Sp_VoucherProvider.sql` | superseded by 07, harmless |
| 14 | `09_Staging/01_Providers_Seed.sql` | **the five providers — must come before 15** |
| 15 | `07_Revision3/01_Products.sql` | the real product lists |
| 16 | `09_Staging/02_LanguageCERT_Products.sql` | 15 deliberately skips LanguageCERT |
| 17 | `09_Staging/03_Product_Validity.sql` | cosmetic; keeps environments diffing clean |
| 18 | `07_Revision3/02_Sp_VoucherProvider.sql` | procs |
| 19 | `07_Revision3/05_AutoMove_Schema.sql` | **adds `AutoMoveAfter` — must come before 21** |
| 20 | `08_Encryption/01_Encrypt_Voucher_Columns.sql` | **adds `VoucherCodeHash` — must come before 21** |
| 21 | `07_Revision3/03_Sp_VoucherStock.sql` | reads both of the above |
| 22 | `07_Revision3/04_Sp_VoucherPerformance.sql` | procs |

#### Why 03 runs after 05 and 08, and not with its own folder

`07_Revision3/03_Sp_VoucherStock.sql` reads `AutoMoveAfter`, which
`07_Revision3/05` adds, and `VoucherCodeHash`, which `08_Encryption` adds.
SQL Server defers name resolution for a **table** that does not exist yet, but
not for a **column** that does not exist on a table that does — so creating the
procedure any earlier fails outright:

```
Msg 207, Level 16, State 1, Procedure Sp_VoucherStock_Table
Invalid column name 'AutoMoveAfter'.
Invalid column name 'VoucherCodeHash'.
```

On a database that grew a column at a time this never showed, because the
procedure was always recreated after the columns already existed. On a new one
it stops the run. Putting `03` last also means it is created **once**, already
knowing the columns are `varbinary` — which is what the old "run 08 last, then
re-run `07_Revision3/03`" instruction was reaching for.

#### Why the providers need their own script

Nothing in the safe list creates the five providers. The only script that does
is `04_Updates/02_Reseed_VoucherStatus_Demo.sql`, which opens by emptying all
three voucher tables and is on the never-run list. Follow the old list exactly
and you get **no providers at all** — and `07_Revision3/01_Products.sql`, which
attaches products to providers **by name**, then attaches none and says
`Products added: 0` without failing.

The ids in `09_Staging/01` are pinned on purpose. `Helpers/ProviderBrand.cs`
colours each tile with `Palette[(id - 1) % 8]`, so the id *is* the colour:
1 AWS orange, 2 Microsoft blue, 3 PTE violet, 4 ETS red, 5 LanguageCERT green.
Let the identities fall where they may and every environment draws the same
providers in different colours. Logo files match on the **name** instead —
`assets/img/providers/aws.svg` and so on — so the names must stay exact too.

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

Skip `03_EarlyExpiry_Toggle.sql` and `05_ToBeExpired.sql` **entirely** — an
earlier version of this page said to run everything above the "Demo data only"
comment and stop, which was contradictory advice on a never-run list and is not
needed either way. The only thing above that comment in either file is another
copy of `Sp_VoucherProvider_Table`, and `07_Revision3/02` supersedes it. Nothing
is lost by leaving both alone.

### Authoritative proc copies

`Sp_VoucherStock_Table` is defined in **three** places. `07_Revision3/03_Sp_VoucherStock.sql`
runs last and wins; the two copies in `06_Revision2/` are dead. Edit the 07 one.

### Encryption — three things that must not be skipped

`08_Encryption/01_Encrypt_Voucher_Columns.sql` converts voucher codes,
candidate names, remarks and dealer names to AES-256 ciphertext and creates
the key material. It is re-runnable and guarded on column type, so running it
twice does not double-encrypt.

**1. Run it before, not after, the data matters.** It encrypts whatever is in
the table at the time. Rows written afterwards go through the proc and are
encrypted on the way in.

**2. Back up the certificate the moment it is created.** Without
`VoucherDataCert`'s private key the data is gone — rows intact, every voucher
code NULL. The `BACKUP CERTIFICATE` and restore commands are in section 8 of
the migration. Keep the files off the database server and keep the master key
password with them.

**3. Grant the application login rights on the key.** LocalDB under integrated
security runs as `dbo` and needs nothing. A production SQL login does:

```sql
GRANT VIEW DEFINITION ON SYMMETRIC KEY::VoucherDataKey TO [your_app_login];
GRANT VIEW DEFINITION ON CERTIFICATE::VoucherDataCert  TO [your_app_login];
```

Without these the proc raises `VoucherDataKey could not be opened` on every
call. That is deliberate — the alternative is a screen full of blank voucher
codes and no indication anything is wrong.

Nothing changes in the application code or `Web.config`. The procs do the
encrypting and decrypting, so the pages receive the same columns they always did.

### Run these with `sqlcmd -I`

`sqlcmd` defaults `QUOTED_IDENTIFIER` **off**, and a proc keeps whatever was in
force when it was created. `VoucherStock_Table` carries a filtered index, so a
proc created with it off fails at runtime on every `UPDATE` — Move, Reassign,
AutoMove, BulkInsert — with msg 1934, while the `SELECT`s carry on working. The
screen loads, the grid fills, and only the writes are dead.

`07_Revision3/03_Sp_VoucherStock.sql` and `05_AutoMove_Schema.sql` now set it
themselves, so they are safe either way. Pass `-I` anyway when running the rest;
SSMS and Visual Studio already have it on.

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

`DSL_CMS/Web.Release.config.example` is the transform to copy. It sets the
connection string, turns `compilation debug` off and `customErrors` to
`RemoteOnly`, and leaves `validateRequest="false"` alone. Copy it to
`Web.Release.config` and fill in the password; git ignores the copy, not the
template.

> **The transform only runs on Publish, not on Build.** MSBuild applies it from
> the `TransformWebConfig` target during a Release publish or package. Copying
> `bin\` and the `.aspx` files to the server by hand transforms **nothing** —
> the site goes up still pointing at LocalDB and fails on the first query.
> Either publish properly, or edit `Web.config` on the server and skip the
> transform.

Whichever login it is, it has to be able to open `VoucherDataKey`. `db_owner`
gets that implicitly; anything narrower needs the two `GRANT VIEW DEFINITION`
statements above, or `Sp_VoucherStock_Table` refuses to run at all.

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

### The command

```powershell
MSBuild DSL_CMS\DSL_CMS.csproj /t:WebPublish /p:Configuration=Release `
    /p:WebPublishMethod=FileSystem /p:publishUrl="E:\DSL_CMS_OSS_Publish" `
    /p:DeleteExistingFiles=true /p:DebugSymbols=false /p:DebugType=none
```

`/t:WebPublish`, not `/t:Build /p:DeployOnBuild=true` — the second one exits 0
and writes **nothing**, which is easy to mistake for success.

`DebugSymbols=false /p:DebugType=none` keeps the `.pdb` files out. They are not
needed to run and they carry the build machine's source paths, which is the same
thing `compilation debug="false"` is there to avoid. `ClosedXML.pdb` comes from
the NuGet package rather than the compiler and survives both flags — delete it
from the output.

That lands 38 files, about 11 MB. Check the result before copying it anywhere:

```powershell
([xml](Get-Content "E:\DSL_CMS_OSS_Publish\Web.config")).configuration.connectionStrings.add.connectionString
```

If that still says `(localdb)\MSSQLLocalDB`, the transform did not run and the
site will fail on its first query.

The connection string it carries names the server as `webserver-vm-00\SQLEXPRESS`,
which resolves **on the web server** and nowhere else. Publishing for any other
host means changing it in `Web.Release.config` first.

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
- **No `<authorization>` rules.** Access control is per-page code. Every page does
  check, but a new page that forgets to will be public to any signed-in user.
- **No cookie hardening.** No `<httpCookies requireSSL="true" httpOnlyCookies="true">`,
  and the session id is not regenerated on login.

### Unmapped users no longer fall back to admin

This used to be on the list above: seven screens each decided for themselves what
to do about a user with no voucher role, and all seven treated them as **Voucher
Admin**. It was deliberate, for testing, but it meant every account that could
sign into the site at all had the run of the voucher module — Upload Entry and
Add Provider included. On the staging database that was 43 accounts, none of them
mapped.

The rule now lives in one place, `Helpers/VoucherAccess.cs`, and refuses by
default. The old behaviour is opt-in, and development is where it opts in:

```xml
<add key="VoucherUnmappedIsAdmin" value="true" />
```

`Web.config` sets it, `Web.Release.config` does not — so a server that never
sets the key is closed rather than open. The setting has to be **added** to
weaken the rule, not remembered to keep it strong. The role-preview dropdown on
View Data is part of the same switch: it only appears when the fallback is on,
which is what it was always for.

Verified on the running application, all four screens, both ways round: with the
key on, an unmapped user gets the admin view and the preview note exactly as
before; with it off, all four refuse, while a mapped Voucher Admin is unaffected
either way.

Two more things found this way have already been fixed: Manage Product had no
authorisation at all (a student could create products), and a student could edit
another student's voucher by changing a hidden field. Both were demonstrated
working, then closed, and both are now refused in the stored procedure rather
than only in the page.
