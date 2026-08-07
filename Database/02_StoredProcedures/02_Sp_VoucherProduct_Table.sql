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
    @Search       NVARCHAR(150) = NULL
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
            pr.Status,
            pr.AddedDate,
            VoucherCount = (SELECT COUNT(*) FROM dbo.VoucherStock_Table v WHERE v.ProductId = pr.Id)
        FROM dbo.VoucherProduct_Table pr
        INNER JOIN dbo.VoucherProvider_Table p ON p.Id = pr.ProviderId
        WHERE (@ProviderInt IS NULL OR pr.ProviderId = @ProviderInt)
          AND (@Status      IS NULL OR pr.Status     = @Status)
          AND (@Search      IS NULL OR pr.Name LIKE '%' + @Search + '%'
                                    OR p.Name  LIKE '%' + @Search + '%')
        ORDER BY p.Name, pr.Name;
    END

    /* ---- Dropdown (product by provider) ---- */
    ELSE IF @Action = 'SelectDropdown'
    BEGIN
        SELECT Id, Name
        FROM dbo.VoucherProduct_Table
        WHERE Status = 'A'
          AND (@ProviderInt IS NULL OR ProviderId = @ProviderInt)
        ORDER BY Name;
    END

    ELSE IF @Action = 'SelectId'
    BEGIN
        SELECT Id, ProviderId, Name, ValidityDays, Status
        FROM dbo.VoucherProduct_Table
        WHERE Id = @IdInt;
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
