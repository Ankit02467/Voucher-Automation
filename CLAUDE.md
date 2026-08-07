# DSL_CMS_OSS — Voucher module

ASP.NET **Web Forms**, .NET Framework **4.8**, three projects:

| Project | Role |
|---|---|
| [DSL_CMS.DAL](DSL_CMS.DAL/) | `SqlHelper.cs` (Data Access Block), `VoucherDAL.cs`, `LoginDAL.cs` |
| [DSL_CMS.BAL](DSL_CMS.BAL/) | Thin pass-through wrappers — no logic lives here |
| [DSL_CMS](DSL_CMS/) | Pages: login, dashboard, voucher-status, voucher-data, manage-product, student-performance |
| [Database](Database/) | Numbered, re-runnable SQL migration folders |

Database is `DSL_New` on `(localdb)\MSSQLLocalDB` — **shared with the public
website**, which is why several things below look odd.

---

## Traps — read before editing

These have each cost real debugging time.

### 1. `07_Revision3/03_Sp_VoucherStock.sql` is the only proc copy to edit

`06_Revision2/` contains **two complete copies** of `Sp_VoucherStock_Table`
(`03_Sp_VoucherStock.sql` and `05_Admin_Edit.sql`). Both are superseded.
Editing either changes nothing, because
[Database/07_Revision3/03_Sp_VoucherStock.sql](Database/07_Revision3/03_Sp_VoucherStock.sql)
runs last and wins. Edit that file, in place, and re-run it.

### 2. Dates must be converted to ISO in C# before reaching SQL

The connection runs under **`mdy`**. Handing SQL raw text means `14-08-2026`
is read as month 14 — invalid — and `TRY_CONVERT` returns **NULL without
raising**. The row saves with the date missing and the screen reports success.

`voucher-data.aspx.cs` has `NormaliseDate` / `DateFormats` for this: parse in
C# (day first), emit `yyyy-MM-dd`. Do the same for any new date input.

### 3. `VoucherStock_Table`, never `Voucher_Table`

`DSL_New` already has `dbo.Voucher_Table` + `dbo.sp_Voucher_Table` holding the
public site's live voucher *content*. SQL object names are case-insensitive, so
creating `Sp_Voucher_Table` here would **overwrite the live proc**.

### 4. The connection string key must stay `con`

`SqlHelper.cs` reads `ConnectionStrings["con"]`. Renaming it breaks every page.

### 5. Role names are string literals

`Voucher Admin`, `Voucher Sub Admin`, `Voucher Team`, `Voucher Student`.
They come from `UserTypeMaster.UserTypeName` where `TypeId = 4`. A user with
no voucher role mapped **falls back to admin** (deliberate, for testing).

### 6. The overnight auto-move is a sweep, not a job

LocalDB has no SQL Agent. Setting a status stamps `AutoMoveAfter` with that
night's midnight; `Sp_VoucherStock_Table @Action='AutoMove'` moves whatever is
due. It runs on every View Data page load — idempotent, normally a no-op.
On a full SQL Server, move it to an Agent job.

It only moves vouchers where `AssignedTo IS NOT NULL`. A move carries a voucher
*from a student to the sub-admin*; an unheld voucher has no such journey.

---

## Conventions

**One proc per entity, switched by `@Action`.** Add a branch, do not add a proc.

**Every proc parameter is `NVARCHAR ... = NULL`**, converted inside with
`TRY_CONVERT`. The DAL passes everything as `string`, including ids and dates,
and passes empty strings for "no filter". This makes blank filters and bad
input safe instead of throwing.

**Naming:** `<Entity>_Table`, `Sp_<Entity>_Table`, `PK_/FK_/UQ_/CK_/IX_/DF_<Table>_<Cols>`.

**Migrations are re-runnable** — guarded with `IF OBJECT_ID(...) IS NULL`,
`CREATE OR ALTER`, `IF NOT EXISTS`. Run folders in numeric order.

**Retire, never delete.** Products no longer wanted get `Status = 'I'`.
Existing vouchers still point at them; deleting breaks the FK and loses which
product those vouchers belonged to.

**Status values:** `VoucherStock_Table.Status` is `Used` / `Unused` / `Expired`
/ `Invalid` / **NULL**. NULL means a fresh upload nobody has triaged — the
"Not Set" pill. Providers and products use `A` / `I`.

---

## Running it

```powershell
sqllocaldb start MSSQLLocalDB          # it is often stopped

& "C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe" `
    DSL_CMS.sln /t:Rebuild /p:Configuration=Debug

& "C:\Program Files\IIS Express\iisexpress.exe" `
    /config:".vs\DSL_CMS\config\applicationhost.config" /site:DSL_CMS
```

Then <http://localhost:52000/login.aspx>. A clean build is **0 warnings**;
if reference warnings return, check `SpecificVersion` on the packaged
assemblies — the identities in the `.csproj` do not match the DLLs on disk.

### Test users — all password `Voucher@123`

| Email | Role |
|---|---|
| `voucher.admin@dsucceedlearners.com` | Voucher Admin |
| `voucher.subadmin@dsucceedlearners.com` | Voucher Sub Admin |
| `voucher.team@dsucceedlearners.com` | Voucher Team |
| `voucher.student@dsucceedlearners.com` | Voucher Student |
| `student1@…` … `student4@…` | Students (Aarav, Diya, Kabir, Meera) |

Passwords are stored **Base64, not hashed** — matching the existing site.
`login.aspx.cs` encodes and compares directly.

---

## Who can do what

| | Admin | Sub Admin | Team | Student |
|---|:--:|:--:|:--:|:--:|
| Upload Entry | ✓ | | ✓ | |
| View History | ✓ | | | |
| Assign / Reassign | | ✓ | | |
| Edit | ✓ | ✓ | | ✓ |
| Dealer name / sale date columns | ✓ | | ✓ | |
| Added By / Checked By columns | ✓ | ✓ | ✓ | |
| Student-wise performance | ✓ | ✓ | | |

The Edit modal differs by role. Admin sees voucher code, added by, candidate
name and exam details **greyed out** — and `UpdateAdminEntry` does not write
them either. A disabled input is a hint to the browser, not a rule; the proc
is where it is enforced.

A student's Voucher Status screen shows their own performance instead of the
provider summary.

---

## Watch out when changing

- `UpdateStatusEntry` **overwrites** `CandidateName` / `ExamDate` / `ExamMode`
  with whatever it is handed. Saving from an editor that does not show those
  fields blanks them. That is why `UpdateStatusOnly` exists for the student.
- Performance counts come from `VoucherHistory_Table`, not `VoucherStock_Table`
  — the stock row remembers only the *last* check. Any new action that counts
  as work must write a history row with `ChangedBy` set, or it counts for nobody.
- Windows are rolling and inclusive of today: Weekly = 7 days, Monthly = 30.
- Voucher codes **contain spaces** (`AWS CODE 246`). Never split input on space.
