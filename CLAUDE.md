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

### 8. Assigning a voucher must clear `AutoMoveAfter`

A sub-admin can set a status on a voucher **nobody holds**. That stamps
`AutoMoveAfter` with the coming midnight, and the sweep leaves it alone —
`AutoMove` only moves vouchers with a student on them. `Assign` then put a
student on it *without clearing the stamp*, so the next View Data page load
carried it straight to the done list. The student never saw the voucher, and on
their own screen it counted as work somebody else had done.

`Reassign` and `ReassignMany` always cleared it. `Assign` does now too. Anything
new that hands a voucher to a student has to, or it inherits the same bug — and
it is silent: nothing errors, a row simply is not there any more.

[Database/11_AssignStamp/01_Clear_Stale_AutoMove.sql](Database/11_AssignStamp/01_Clear_Stale_AutoMove.sql)
clears the ones already stamped. It only touches held vouchers whose stamp is no
later than the moment they were assigned — a stamp made *during* a hold is always
later than the assignment, so it cannot take away a check somebody really did.

### 9. Voucher codes and names are ciphertext, and duplicates hang off a hash

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

**Counts in the sidebar are white and heavy**, not the muted grey around them.
The count is the reason the row is there — a provider holding seventeen read
like one holding none when it was set in `--sb-mut`, and the product names below
had already been corrected for exactly this. Nothing in the tree is muted now.

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
| Edit (row action) | ✓ | ✓ | ✓ | |
| Edit status in the cell | | | | ✓ |
| Dealer name / sale date columns | ✓ | | ✓ | |
| Added By / Checked By columns | ✓ | ✓ | ✓ | |
| Student-wise performance | ✓ | ✓ | | |

The Edit modal differs by role — that is the whole point of `CanEdit` covering
three of them. `OpenEditor` picks the panel: the team gets the dealer
pairs and nothing else, the sub-admin gets the status entry, the admin gets the
lot. The student has no modal at all any more — the status is the only thing
they set and they set it in the cell that shows it. Admin sees voucher
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

**A student sees only what they are holding.** Their Voucher Status screen shows
their own table instead of the provider summary, and both that table and the
sidebar list the providers — and the products under them — where they hold a
voucher that has not moved on. One rule in two places: `BuildStudentTable` on
`voucher-status.aspx.cs` counts the student's own voucher rows, and `OnlyHeld` /
the count check in `NavProducts` on `MasterPage.master.cs` read the held count
`Sp_VoucherProvider_Table` returns when `@AssignedTo` is set.

The two are kept identical on purpose. They are read side by side, and a
provider in one and not the other is worse than either being a row shorter; it
also keeps every link on that screen pointing at rows that exist, since the
student's grid is scoped the same way. The cost is that a provider whose
vouchers have all moved on to the sub-admin drops off, figures and all — the
history rows still stand, and Student-wise Performance still counts them.

Only the student. For every other role the tree is the catalogue, and a
provider holding no stock is still a provider.

**Five figures, and they are two different questions.** `All` / `Checked` /
`Pending` are what is in the student's hands right now; `Weekly` / `Monthly` are
how much work they have done, over the last 7 and 30 days. A voucher checked
yesterday is gone from the first three and still counted in the last two, which
is the whole reason for having both on a row.

The first three come from the student's own voucher rows — the same fetch, under
the same filters, that their View Data grid lists, so a figure here cannot
promise rows that screen will not show. `Checked` is `AutoMoveAfter IS NOT NULL`:
the stamp goes on when a status is saved and comes off again on an assign or a
reassign, so it is the one field that says "done, and leaving tonight" without
asking who did it. It is also what the sweep reads, so `Checked` is exactly the
set that will move. `All = Checked + Pending` therefore holds always — it is a
fact about the rows, not a subtraction the page performs and hopes about.

`Weekly` and `Monthly` still come from `Sp_VoucherPerformance_Table`, which
counts the history log per **provider**. Product sub-rows show a dash for those
two rather than a number: splitting them per product needs a proc that does not
exist, and a figure that looked right and was not would be worse than a dash.

**The student's table has no Actions column.** The provider name is the link to
its vouchers and the chevron beside it opens the products, each product name
linking to its own slice — two targets, and neither is a button in a column at
the far end of the row. The other roles keep their Actions column because they
have somewhere else to go from it (Manage Product), which this role has not.

**Student-wise Performance is the same table, seen from above.** One row per
student *and provider* — a student holding two providers is two rows, because
those are two piles of work — with the same `All` / `Checked` / `Pending` /
`Weekly` / `Monthly` and the same products behind a chevron.

**"Today Assign Data" is a band above the table, not a row of it.** It was the
first row and read as one more student until the eye stopped on it. Out on its
own — dark, so it cannot be mistaken for the list — it is the headline the
screen is opened for and the table under it is a list again. It carries no line
of explanation under its name: that was describing the table, which describes
itself.

**It totals all five count columns, and each figure stands in the column it
totals.** Adding a column up is safe in both halves — a row is one student and
one provider, and the history counts behind Weekly and Monthly are already
`DISTINCT` per voucher inside that pair, so no voucher is counted twice however
many times it was touched. `.sp-sum-figs` still carries the `padding-right` that
steps back over any count column the band does not fill; it is nought now, and
one column's width for each figure ever taken off again — miss that and the
figures left slide right by a column each.

Standing in the column is four numbers agreeing, and nothing in the code makes
them agree:

- the `<colgroup>` on `student-performance.aspx` pins the widths, and
  `.vs-page table.sp-table` is `table-layout: fixed` so the browser uses them
  rather than sharing the slack out by content — **both selectors**, because
  `.vs-page table` sets a `min-width` of its own and a bare `.sp-table` loses
  to it;
- `.sp-sum-figs .fig` is `flex: 0 0` that same column width, and
  `.sp-sum-figs` is measured from the right — the end the columns are fixed
  from — with `padding-right` stepping back over the count columns it does not
  fill;
- `.sp-sum` has no horizontal padding and a **transparent 1px border** in place
  of the panel's, so its inside is the table's box, and a `min-width` two
  pixels larger than the table's for the same reason (`box-sizing` is
  `border-box`);
- `.sp-sumwrap` gives the band its own `overflow-x`, so under the table's
  min-width the two scroll together instead of the band sitting still while
  its columns slide out from under it.

Change any one of those and the band drifts. `Test-PerfTable` asserts the
relationships between them — not the numbers themselves, so a deliberate change
still has to be a consistent one — and `Measure-Band.ps1` renders the page at
six widths in headless Chrome and measures chip centre against column centre,
which is the only thing that can say what the browser actually did.

The held figures come from the same call the student's own screen makes, with
the student left off: `GetVoucherDetail(… assignedTo: "", isMoved: "0",
"SelectAll")`, grouped in `BuildTable`. One query rather than one per student,
and — the point — a figure here and the same figure on that student's own
Voucher Status cannot disagree, because they are the same rows counted the same
way. `Test-PerfTable` reads both screens and compares them.

`Weekly` / `Monthly` come from `Sp_VoucherPerformance_Table @Action =
'SelectByStudent'`, which answers "every student, for one provider" — so
`HistoryCounts` asks it once per provider that actually appears. A handful of
calls, not one per student, and providers nobody holds anything of are never
asked about because they have no row to fill.

**Nothing on that screen is a link.** It answers "who has what" and is not a way
through to anywhere: the chevron is the only control on the table, and the row
commands are all it has. Deliberate — the admin's route to a provider's vouchers
is Voucher Status, and a second one here would be a second place to keep right.

It carries **no provider filter and no paragraph** either. The filter was a pill
row from when the table had no Provider column; now that every row names its
provider and the column sorts, it narrowed a list that can already be read. What
is left is a heading and the table, which is what the screen beside it is.

It is built out of the `vs-*` classes rather than the blue `table.data` family —
the same panel, head row, provider block and count badge the student's own
screen uses. The two are read against each other, an admin checking a figure a
student has queried, and two tables answering one question should not look like
two products. `.sp-table` exists only to pull the product indent back, because
the provider is the third column here and the second there.

The student's name is written **once per run of their own rows**, and so is the
number beside it. A student holding two providers is two rows because those are
two piles of work, but they are one person's piles — numbering them 2 and 3 said
there were two people, so `SerialCell` counts students and the rows under a name
carry no number. A sort that scatters those rows turns every run into one row, so
every run gets its number and its name back without the code having to know a
sort happened — `_lastStudent` is simply the last student asked about, and a
Repeater binds in order.

`SerialCell` is also where a run is *decided*, because it is the first cell in
the row; `StudentCell` only reads the answer. Move the number out of column one
and the name stops knowing where a run begins. The two text columns are also the tie-breakers on every numeric sort, so
a student's providers stay together underneath their name.

Every column of that table sorts, on its own key (`PerfSortKey`) rather than the
provider table's — the two are never on screen together, and neither should be
left ordered by a column the other owns. `ExpandedProviders` *is* shared with the
provider table, which costs nothing for the same reason.

**The student edits the status in the cell that shows it.** `CanEdit` no longer
includes them, so they have no row action at all and `ShowActions` drops the
whole Actions column rather than leaving an empty one. `CanInlineStatus` puts a
pencil in the Voucher Status cell instead; it opens a dropdown of Used / Unused
/ Invalid with a tick and a cross beside it. `StatusEditId` holds the one row
that is open — a grid of open dropdowns is a form, not a list.

The save is `UpdateStatusOnly`, the very call the dialog made, so the check
date, the name against it and the overnight move are stamped exactly as before,
and the proc still refuses (-3) a voucher that is not theirs. No used date is
asked for: the proc already defaults it to today under "Used", which is the same
answer the dialog's required field was collecting.

`rptVoucher_ItemCommand` re-checks `CanInlineStatus`, so another role firing the
command changes nothing — and ASP.NET's event validation refuses the postback
before that, since their page never rendered it.

---

## Watch out when changing

- `UpdateStatusEntry` **overwrites** `CandidateName` / `ExamDate` / `ExamMode`
  with whatever it is handed. Saving from an editor that does not show those
  fields blanks them. That is why `UpdateStatusOnly` exists for the student, and
  why the inline status cell calls that one and not the other — it shows a
  status and nothing else, so it must write a status and nothing else.
- Performance counts come from `VoucherHistory_Table`, not `VoucherStock_Table`
  — the stock row remembers only the *last* check. Any new action that counts
  as work must write a history row with `ChangedBy` set, or it counts for nobody.
- Windows are rolling and inclusive of today: Weekly = 7 days, Monthly = 30.
- Voucher codes **contain spaces** (`AWS CODE 246`). Never split input on space.
