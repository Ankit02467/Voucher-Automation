# DSL_CMS_OSS — Database

Target server : `(localdb)\MSSQLLocalDB`
Target database : `DSL_New` (existing — shared with the current site)

## ⚠ Do not run this folder in order on a live database

Some scripts here **delete data**. `04_Updates/02_Reseed_VoucherStatus_Demo.sql`
opens by emptying all three voucher tables, and two others overwrite `ExpiryDate`
on every unused voucher. They exist to build a demo dataset and are fine on a
development copy.

**Before touching a production database, follow
[DEPLOYMENT.md](../DEPLOYMENT.md)**, which lists exactly which scripts to run and
which to skip. The order below is the development order.

## Run order (development only)

Run the folders in numeric order. Every script is **re-runnable** (guarded by
`IF OBJECT_ID(...) IS NULL` / `DROP ... IF EXISTS` / `NOT EXISTS`) — but
re-running the demo scripts re-does their deletes.

```
01_Tables/
  01_VoucherProvider_Table.sql
  02_VoucherProduct_Table.sql     -- FK -> VoucherProvider_Table
  03_VoucherStock_Table.sql       -- FK -> Provider + Product
02_StoredProcedures/
  01_Sp_VoucherProvider_Table.sql
  02_Sp_VoucherProduct_Table.sql
  03_Sp_VoucherStock_Table.sql
03_SeedData/
  01_Seed_Voucher.sql             -- 5 providers, 7 products, 14 vouchers
```

## Naming convention

| Kind | Pattern | Example |
|---|---|---|
| Table | `<Entity>_Table` | `VoucherProvider_Table` |
| Proc | `Sp_<Entity>_Table` | `Sp_VoucherProvider_Table` |
| PK | `PK_<Table>` | `PK_VoucherStock_Table` |
| FK | `FK_<Table>_<Ref>` | `FK_VoucherStock_Provider` |
| Unique | `UQ_<Table>_<Cols>` | `UQ_VoucherStock_Code` |
| Check | `CK_<Table>_<Col>` | `CK_VoucherStock_Status` |
| Index | `IX_<Table>_<Cols>` | `IX_VoucherStock_Provider_Status` |
| Default | `DF_<Table>_<Col>` | `DF_VoucherStock_Status` |

One proc per entity, switched by `@Action` — matches the existing DSL codebase style.

## ⚠ Why `VoucherStock_Table` and not `Voucher_Table`

`DSL_New` **already has** `dbo.Voucher_Table` + `dbo.sp_Voucher_Table`. Those belong
to the public website's voucher *content* (`Name`, `Price1`, `Price2`, `ImageUrl`,
`Detail`) and hold 14 live rows. SQL Server object names are case-insensitive, so
creating `Sp_Voucher_Table` for this module would have **overwritten the live proc**.

The new module therefore uses:

| New object | Purpose |
|---|---|
| `VoucherProvider_Table` / `Sp_VoucherProvider_Table` | Providers + provider-wise summary |
| `VoucherProduct_Table` / `Sp_VoucherProduct_Table` | Products per provider |
| `VoucherStock_Table` / `Sp_VoucherStock_Table` | Individual voucher codes |

`VoucherDAL.cs` was updated to call `Sp_VoucherStock_Table`. **Nothing existing was
modified or dropped.**

## Proc parameters

All SP parameters are `NVARCHAR` with `DEFAULT NULL`, converted internally with
`TRY_CONVERT`. Reason: `VoucherDAL` passes every value as a `string`, including ids
and dates, and passes empty strings for "no filter". This makes blank filters and
bad dates safe instead of throwing a conversion error.

### `@Action` values

| Proc | Actions |
|---|---|
| `Sp_VoucherProvider_Table` | `SelectSummary`, `SelectDropdown`, `SelectId`, `SelectCategory`, `Insert`, `Update` |
| `Sp_VoucherProduct_Table` | `Select`, `SelectDropdown`, `SelectId`, `Insert`, `Update` |
| `Sp_VoucherStock_Table` | `Select`, `SelectId`, `SelectCheckedBy`, `SelectCount`, `Insert`, `Update`, `UpdateCheck` |

`Insert` / `Update` return `-1` when a duplicate would be created
(duplicate `VoucherCode`, or duplicate product name within a provider).

## Status values

- `VoucherProvider_Table.Status`, `VoucherProduct_Table.Status` → `A` / `I`
- `VoucherStock_Table.Status` → `Used` / `Unused` / `Expired`

## Connection string

`DSL_CMS\Web.config` — the key **must** stay `con`, because
`DSL_CMS.DAL\SqlHelper.cs` reads `ConfigurationManager.ConnectionStrings["con"]`.

```xml
<add name="con"
     connectionString="Server=(localdb)\MSSQLLocalDB;Database=DSL_New;Integrated Security=True;MultipleActiveResultSets=True;"
     providerName="System.Data.SqlClient" />
```
