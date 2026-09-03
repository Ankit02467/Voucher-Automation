# DSL_CMS_OSS — Voucher module

ASP.NET **Web Forms**, .NET Framework **4.8**, three projects:

| Project | Role |
|---|---|
| [DSL_CMS.DAL](DSL_CMS.DAL/) | `SqlHelper.cs` (Data Access Block), `VoucherDAL.cs`, `LoginDAL.cs` |
| [DSL_CMS.BAL](DSL_CMS.BAL/) | Thin pass-through wrappers — no logic lives here |
| [DSL_CMS](DSL_CMS/) | Pages: login, dashboard, voucher-status, voucher-data, manage-product, add-provider, student-performance |
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

### 7. Re-run the stock proc with `sqlcmd -I`, or the writes die silently

`sqlcmd` defaults `QUOTED_IDENTIFIER` **off** and a proc keeps the setting it
was created under. `VoucherStock_Table` has a filtered index on `AutoMoveAfter`,
so a proc created with it off throws **msg 1934** on every `UPDATE` branch —
Move, Reassign, AutoMove, BulkInsert — while every `SELECT` keeps working. Pages
load, grids fill, nothing saves.

`07_Revision3/03_Sp_VoucherStock.sql` and `05_AutoMove_Schema.sql` set it
themselves now. To check a live one:

```sql
SELECT o.name, m.uses_quoted_identifier
FROM sys.sql_modules m JOIN sys.objects o ON o.object_id = m.object_id
WHERE o.name LIKE 'Sp_Voucher%';   -- all should read 1
```

### 8. Voucher codes and names are ciphertext, and duplicates hang off a hash

`VoucherCode`, `CandidateName`, `Remarks` and both `DealerName` columns are
`VARBINARY` under `VoucherDataKey` (AES-256, protected by `VoucherDataCert`).
`VoucherHistory_Table.VoucherCode` too. See
[Database/08_Encryption/01_Encrypt_Voucher_Columns.sql](Database/08_Encryption/01_Encrypt_Voucher_Columns.sql)
for what is encrypted and what is deliberately not.

Three things follow:

`Sp_VoucherStock_Table` opens the key itself and **refuses to run if it
cannot**. Do not remove that guard — `DECRYPTBYKEY` returns NULL rather than
raising when the key is shut, so without it the grid quietly fills with blank
voucher codes and uploads store rows nobody can read. Same failure shape as
trap 2.

`ENCRYPTBYKEY` is randomised, so the same code encrypts differently every
time and no comparison on the ciphertext can find a duplicate.
`VoucherCodeHash` (SHA2_256 of the plain code) carries `UQ_VoucherStock_CodeHash`
and both duplicate checks. **Anything new that inserts a voucher must write
the hash as well as the code**, or it will be invisible to every later
duplicate check.

The history inserts copy `v.VoucherCode` across untouched. That is right —
both columns hold ciphertext under one key, so the bytes carry over.

Back up the certificate. Restoring `DSL_New` somewhere else without it leaves
every voucher code unreadable; the rows survive and `DECRYPTBYKEY` just
returns NULL. The commands are at the bottom of the migration.

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

**The "Expired" filter does not read that column.** It asks
`ExpiryDate < today` — a used, unused, invalid or untriaged voucher past its
date is expired all the same, and reading the column instead left the count at
nought beside providers holding a dozen lapsed ones. `Status = 'Expired'` still
exists and still shows in the grid's badge; nothing sets the filter from it.

Both procs and `voucher-data.aspx.cs` say this, and all three have to agree or
a card and the list under it stop matching. "Expiring soon" is the same
question the other way round: unused or untriaged, expiring **within** the
chosen window.

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
| Add provider | ✓ | | | |
| Assign / Reassign | | ✓ | | |
| Edit | ✓ | ✓ | ✓ | ✓ |
| Dealer name / sale date columns | ✓ | | ✓ | |
| Added By / Checked By columns | ✓ | ✓ | ✓ | |
| Student-wise performance | ✓ | ✓ | | |

The Edit modal differs by role — that is the whole point of `CanEdit` being
true for everyone. `OpenEditor` picks the panel: the team gets the dealer
pairs and nothing else, the student gets the three status buttons, the
sub-admin gets the status entry, the admin gets the lot. Admin sees voucher
code and added by **greyed out** — and `UpdateAdminEntry` does not write them
either. A disabled input is a hint to the browser, not a rule; the proc is
where it is enforced. Candidate name, exam date and exam mode used to be in
that list and are now the admin's to edit, so `UpdateAdminEntry` writes all
three — plainly, not `ISNULL`'d onto what is there, because an admin who
clears a field means to clear it.

**Nothing is required of the admin's or the sub-admin's editor.** A status on
its own saves. The used date is not demanded even under "Used": either of them
setting a status on somebody else's voucher may not know the date, and refusing
the save over it left them unable to record the status at all. The proc drops
the used date whenever the status is not "Used", so a blank one cannot leave a
stale date.

The `*` beside "Voucher Used Date" is the student's alone now — `pnlUsedDate`
is shared between their editor and the sub-admin's, so `ShowStatusFields` sets
the star rather than the markup carrying it. Marking a field required on an
editor that refuses nothing is a promise the save does not keep.

**Setting a status stamps the check date**, in all four editors. Three of them
always did — `UpdateCheck`, `UpdateStatusEntry`, `UpdateStatusOnly` all write
`GETDATE()`. `UpdateAdminEntry` did not, because it was written before the
admin had a status field at all, so an admin could set a status and leave the
Voucher Check Date column empty. It stamps now, with two rules: a date already
in the box wins (the editor loads the one the voucher has, so this fills the
first check rather than overwriting one), and no status means no stamp.
`CheckedBy` is written with it, or the column reads blank beside a date that
came from nowhere.

Note the admin's branch still does **not** set `AutoMoveAfter` — the other
three do. An admin's stamp therefore records the check without handing the
voucher to the sub-admin overnight. Deliberate for now: an admin edits other
people's vouchers, and moving one out from under a student because the admin
corrected a field would be a surprise.

**The tick box in the grid is the student's, not the sub-admin's.** `CanCheck`
is `RoleStudent` only. It stamped the check date and a name on a voucher nobody
had opened, so the column could read "checked by Anju Rani" beside a status
nobody had set; the sub-admin's editor stamps both the moment they save a
status, which is the check actually happening. One way in, and it is the one
that means something. The box still renders — disabled — because it is how the
column shows what a voucher carries. `chkCheckDate_CheckedChanged` re-checks
`CanCheck`, so a forged postback stamps nothing either; a disabled input is a
hint to the browser, not a rule.

The student keeps it: their editor is three status buttons, and the tick is how
they record a look that changed nothing.

**Remarks are a log, and belong to two roles.** `VoucherRemark_Table`
([Database/10_Remarks/01_VoucherRemark_Table.sql](Database/10_Remarks/01_VoucherRemark_Table.sql))
holds every remark anybody leaves on a voucher, encrypted like the code beside
it. `VoucherStock_Table.Remarks` — the single encrypted column that has never
been written to — is untouched and still is nothing's source; one column cannot
hold a conversation.

`RoleName` is stored with each remark and the name is joined live: the role is
what the writer *was* when they wrote it, and relabelling old remarks the day
somebody changes role would be a lie, while a corrected spelling of a name
should show everywhere.

Only `Voucher Admin` and `Voucher Team` get the column, the "i", the log behind
it and the box in the editor — `ShowRemarks` decides, and both the row command
and the save check it again. It is a rule, not a hidden control.

The "i" is only rendered on a voucher somebody has written on (`HasRemark`), so
it is never the empty state — an untouched row is the same dash as the columns
either side of it, and a column of icons marks exactly the rows worth opening.
The column sorts on `LastRemark`, which is what the cell shows; blanks sort
first the way an empty date or name does, so one click gathers the untouched
rows and the second brings every remarked voucher to the top.

**View History is a row action, not a screen action.** It opens one voucher's
own history — assigned to a student, checked, reassigned, checked again —
grouped into rounds by `Sp_VoucherStock_Table @Action='SelectVoucherHistory'`,
which counts hand-offs with a running `SUM() OVER`. The old toolbar button
listed every change the whole provider had ever seen and answered nothing.

**Add Provider or Product** (`add-provider.aspx`, reached from the `+` beside
Voucher Status in the menu) saves the provider first, then opens a products
section against the new id. Two steps because a product needs a `ProviderId`;
holding products in memory until one final Save would lose them on any slip.
The product half calls the same `InsertProductDetail` Manage Product does, with
a blank validity — that field is only on Manage Product.

Step one has two halves, switched by the pair of buttons in its header:
**New provider** is the above, **Existing provider** is a dropdown that hands
step two an id the same way saving a new one does. Step two never cared where
the id came from, which is why adding a product to AWS needed no second screen
and no second copy of the product form. `?providerId=N` opens straight on the
picker, so any row can link to "add a product to this one".

Only the new-provider half locks itself after saving. The picker is a choice
you are meant to change, and changing it re-reads step two.

**Upload Entry takes dealer columns.** Paste order is voucher code, expiry
date, then any number of dealer name / sale date pairs; a line may carry none
and the next three. They travel to `BulkInsert` in a second parameter
(`@DealerData`, `code|seq|name|saledate~…`) rather than in `@Data`, which is one
record per voucher. `Seq` is in the record because it is the *column* the pair
was pasted into — a blank dealer 1 must leave dealer 2 in slot 2, not promote
it. The proc `OUTPUT`s the rows it inserted and attaches dealers only to those:
a code skipped as a duplicate already belongs to somebody.

The paste is split with `StringSplitOptions.None` for the same reason. Dropping
empties would shift every column left of a blank cell.

Assign and reassign are **one button and one modal**, not two features. On the
open list it reads "+ Assign" and offers `SelectForAssign` — vouchers nobody
holds. On the done list it reads "Reassign" and offers `SelectForReassign` —
`IsMoved = 1` — and saves through `ReassignMany`. `ReassignMode` on
`voucher-data.aspx.cs` is the switch. A row still has its own Reassign button
for the one-off case.

**The picker offers what the screen behind it is showing**, less whatever is
already held. The three things that narrow the grid narrow `BindAssign` too —
the product (`LockedProductId`), the status card (`StatusFilter`), and a code
searched from the topbar (`SearchCode`) — each applied with the very predicate
the grid uses, `FilterByStatus` and `FilterByCode` on the rows already fetched.
No proc change: `SelectForAssign` already returns `Status` and `ExpiryDate`.

Under a product lock the picker offers **only** that product and no
"-- All --", and `BindAssign` reads `LockedProductId` rather than the posted
`SelectedValue`, the same care `rptUploadProduct_ItemCommand` takes.

"Unassigned" still sits on top of all of it, so the count is the card's minus
what is out on loan — which is why the heading names the slice and an empty one
says which slice is empty rather than "No unassigned vouchers."

The picker's own **Voucher Code** box searches inside that, and no further: it
is the last `FilterByCode` in `BindAssign`, after the screen's scope, so it can
never turn up a voucher belonging to a slice the sub-admin is not looking at.
Read straight off the box — a `TextBox` posts its own value, so there is no
state to keep. `pnlAssignFilters` carries `DefaultButton="btnAssignSearch"`,
because Enter in that box would otherwise fire the first button on the form,
which in this dialog is Select — or Assign.

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
