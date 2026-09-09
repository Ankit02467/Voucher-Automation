/* ============================================================
   Proc  : Sp_VoucherProduct_Table
   Screen: manage-product.aspx
   Called: VoucherDAL.GetProductDetail / GetProductById /
           InsertProductDetail / UpdateProductDetail
   ============================================================ */
USE DSL_New;
GO

IF OBJECT_ID('dbo.Sp_VoucherProduct_Table', 'P') IS NOT NULL
    DROP PROCEDURE dbo.Sp_VoucherProduct_Table;
GO

CREATE PROCEDURE dbo.Sp_VoucherProduct_Table
(
    @Action       NVARCHAR(50),
    @Id           NVARCHAR(50)  = NULL,
    @ProviderId   NVARCHAR(50)  = NULL,
    @Name         NVARCHAR(150) = NULL,
    @ValidityDays NVARCHAR(50)  = NULL,
    @Status       NVARCHAR(20)  = NULL,
    @Search       NVARCHAR(150) = NULL,
    /* Reorder: "id:place~id:place~..." - see that branch. */
    @Order        NVARCHAR(MAX) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdInt       INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@Id)), ''));
    DECLARE @ProviderInt INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@ProviderId)), ''));
    DECLARE @ValidInt    INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@ValidityDays)), ''));

    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), '');
    SET @Status = NULLIF(LTRIM(RTRIM(@Status)), '');

    /* ---- Grid / list ---- */
    IF @Action IN ('Select', 'SelectAll', 'SelectFilter')
    BEGIN
        SELECT
            pr.Id,
            pr.ProviderId,
            ProviderName = p.Name,
            pr.Name,
            pr.ValidityDays,
            pr.SortOrder,
            pr.Status,
            pr.AddedDate,
            VoucherCount = (SELECT COUNT(*) FROM dbo.VoucherStock_Table v WHERE v.ProductId = pr.Id)
        FROM dbo.VoucherProduct_Table pr
        INNER JOIN dbo.VoucherProvider_Table p ON p.Id = pr.ProviderId
        WHERE (@ProviderInt IS NULL OR pr.ProviderId = @ProviderInt)
          AND (@Status      IS NULL OR pr.Status     = @Status)
          AND (@Search      IS NULL OR pr.Name LIKE '%' + @Search + '%'
                                    OR p.Name  LIKE '%' + @Search + '%')
        /* The provider's own order where somebody has set one, and the old
           alphabetical where nobody has. Kept in step with the product lists
           Sp_VoucherProvider_Table builds, or Manage Product and the screen
           the drag happens on would disagree about the same list. */
        ORDER BY p.Name, ISNULL(pr.SortOrder, 2147483647), pr.Name;
    END

    /* ---- Dropdown (product by provider) ---- */
    ELSE IF @Action = 'SelectDropdown'
    BEGIN
        SELECT Id, Name
        FROM dbo.VoucherProduct_Table
        WHERE Status = 'A'
          AND (@ProviderInt IS NULL OR ProviderId = @ProviderInt)
        ORDER BY ISNULL(SortOrder, 2147483647), Name;
    END

    ELSE IF @Action = 'SelectId'
    BEGIN
        SELECT Id, ProviderId, Name, ValidityDays, SortOrder, Status
        FROM dbo.VoucherProduct_Table
        WHERE Id = @IdInt;
    END

    /* ---- The order somebody dragged the list into ----

       @Order is "id:place~id:place~...". The place travels with the id rather
       than being counted from the position in the string, because STRING_SPLIT
       does not promise to return rows in order and its ordinal argument needs a
       server newer than this one has to run on.

       Scoped to @ProviderId as well as matching on Id: a list dragged under one
       provider can only ever renumber that provider's own products, whatever
       ids it was handed.

       Products left out keep the SortOrder they had - a NULL among them still
       sorts last, which is where an untouched product belongs. */
    ELSE IF @Action = 'Reorder'
    BEGIN
        IF NULLIF(LTRIM(RTRIM(@Order)), '') IS NULL
        BEGIN
            SELECT 0;
            RETURN;
        END

        /* NULLIF, not a WHERE. A CTE's filter is not a barrier - the optimiser
           may project before it restricts, so a token with no colon at all
           reaches LEFT(value, -1) and raises 537 rather than being skipped, and
           the whole reorder dies over one piece of rubbish in the string. This
           way a bad token simply yields NULL, and the UPDATE below drops it. */
        ;WITH Placed AS
        (
            SELECT Id    = TRY_CONVERT(INT, LEFT(value, NULLIF(CHARINDEX(':', value), 0) - 1)),
                   Place = TRY_CONVERT(INT, SUBSTRING(value, CHARINDEX(':', value) + 1, 20))
            FROM STRING_SPLIT(@Order, '~')
        )
        UPDATE pr
           SET pr.SortOrder    = w.Place,
               pr.ModifiedDate = GETDATE()
        FROM dbo.VoucherProduct_Table pr
        INNER JOIN Placed w ON w.Id = pr.Id
        WHERE w.Id IS NOT NULL AND w.Place IS NOT NULL
          AND (@ProviderInt IS NULL OR pr.ProviderId = @ProviderInt);

        SELECT @@ROWCOUNT;
    END

    ELSE IF @Action = 'Insert'
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.VoucherProduct_Table
                    WHERE ProviderId = @ProviderInt AND Name = @Name)
        BEGIN
            SELECT -1;   -- duplicate
            RETURN;
        END

        INSERT INTO dbo.VoucherProduct_Table (ProviderId, Name, ValidityDays, Status)
        VALUES (@ProviderInt, @Name, @ValidInt, ISNULL(@Status, 'A'));

        SELECT CAST(SCOPE_IDENTITY() AS INT);
    END

    ELSE IF @Action = 'Update'
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.VoucherProduct_Table
                    WHERE ProviderId = @ProviderInt AND Name = @Name AND Id <> @IdInt)
        BEGIN
            SELECT -1;   -- duplicate
            RETURN;
        END

        UPDATE dbo.VoucherProduct_Table
           SET ProviderId   = @ProviderInt,
               Name         = @Name,
               ValidityDays = @ValidInt,
               Status       = ISNULL(@Status, Status),
               ModifiedDate = GETDATE()
         WHERE Id = @IdInt;

        SELECT @IdInt;
    END
END
GO

PRINT 'Created dbo.Sp_VoucherProduct_Table';
GO
