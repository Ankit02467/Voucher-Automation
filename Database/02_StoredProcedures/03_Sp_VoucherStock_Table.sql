/* ============================================================
   Proc  : Sp_VoucherStock_Table
   Screen: voucher-data.aspx
   Called: VoucherDAL.GetVoucherDetail / GetData / InsertVoucherDetail /
           UpdateVoucherDetail / UpdateVoucherCheck / GetCheckedByList /
           GetVoucherCount

   Deliberately NOT named Sp_Voucher_Table - that name is already
   taken by the live website CMS proc in DSL_New.
   ============================================================ */
USE DSL_New;
GO

IF OBJECT_ID('dbo.Sp_VoucherStock_Table', 'P') IS NOT NULL
    DROP PROCEDURE dbo.Sp_VoucherStock_Table;
GO

CREATE PROCEDURE dbo.Sp_VoucherStock_Table
(
    @Action           NVARCHAR(50),
    @Id               NVARCHAR(50)  = NULL,
    @ProviderId       NVARCHAR(50)  = NULL,
    @ProductId        NVARCHAR(50)  = NULL,
    @VoucherCode      NVARCHAR(100) = NULL,
    @ExpiryDate       NVARCHAR(30)  = NULL,
    @DealerName       NVARCHAR(150) = NULL,
    @SaleDate         NVARCHAR(30)  = NULL,
    @Status           NVARCHAR(20)  = NULL,
    @VoucherCheckDate NVARCHAR(30)  = NULL,
    @CheckedBy        NVARCHAR(100) = NULL,
    @AddedBy          NVARCHAR(50)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdInt       INT  = TRY_CONVERT(INT,  NULLIF(LTRIM(RTRIM(@Id)), ''));
    DECLARE @ProviderInt INT  = TRY_CONVERT(INT,  NULLIF(LTRIM(RTRIM(@ProviderId)), ''));
    DECLARE @ProductInt  INT  = TRY_CONVERT(INT,  NULLIF(LTRIM(RTRIM(@ProductId)), ''));
    DECLARE @UserInt     INT  = TRY_CONVERT(INT,  NULLIF(LTRIM(RTRIM(@AddedBy)), ''));
    DECLARE @Expiry      DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@ExpiryDate)), ''));
    DECLARE @Sale        DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@SaleDate)), ''));
    DECLARE @CheckDt     DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@VoucherCheckDate)), ''));

    SET @VoucherCode = NULLIF(LTRIM(RTRIM(@VoucherCode)), '');
    SET @DealerName  = NULLIF(LTRIM(RTRIM(@DealerName)),  '');
    SET @CheckedBy   = NULLIF(LTRIM(RTRIM(@CheckedBy)),   '');
    SET @Status      = NULLIF(LTRIM(RTRIM(@Status)),      '');

    /* ---- Grid with all filters ---- */
    IF @Action IN ('Select', 'SelectAll', 'SelectFilter', 'SelectExport')
    BEGIN
        SELECT
            v.Id,
            v.ProviderId,
            ProviderName = p.Name,
            v.ProductId,
            ProductName  = pr.Name,
            v.VoucherCode,
            v.ExpiryDate,
            v.DealerName,
            v.SaleDate,
            v.Status,
            v.VoucherCheckDate,
            v.CheckedBy,
            v.Remarks,
            v.AddedDate
        FROM dbo.VoucherStock_Table v
        INNER JOIN dbo.VoucherProvider_Table p  ON p.Id  = v.ProviderId
        INNER JOIN dbo.VoucherProduct_Table  pr ON pr.Id = v.ProductId
        WHERE (@ProviderInt IS NULL OR v.ProviderId  = @ProviderInt)
          AND (@ProductInt  IS NULL OR v.ProductId   = @ProductInt)
          AND (@VoucherCode IS NULL OR v.VoucherCode LIKE '%' + @VoucherCode + '%')
          AND (@DealerName  IS NULL OR v.DealerName  LIKE '%' + @DealerName  + '%')
          AND (@CheckedBy   IS NULL OR v.CheckedBy   = @CheckedBy)
          AND (@Status      IS NULL OR v.Status      = @Status)
          AND (@CheckDt     IS NULL OR CAST(v.VoucherCheckDate AS DATE) = @CheckDt)
        ORDER BY v.Id DESC;
    END

    ELSE IF @Action = 'SelectId'
    BEGIN
        SELECT Id, ProviderId, ProductId, VoucherCode, ExpiryDate,
               DealerName, SaleDate, Status, VoucherCheckDate, CheckedBy, Remarks
        FROM dbo.VoucherStock_Table
        WHERE Id = @IdInt;
    END

    /* ---- "Checked By" filter dropdown ---- */
    ELSE IF @Action = 'SelectCheckedBy'
    BEGIN
        SELECT DISTINCT CheckedBy
        FROM dbo.VoucherStock_Table
        WHERE CheckedBy IS NOT NULL AND CheckedBy <> ''
        ORDER BY CheckedBy;
    END

    /* ---- Tile counts for a provider (or overall) ---- */
    ELSE IF @Action = 'SelectCount'
    BEGIN
        SELECT
            TotalVoucher   = COUNT(*),
            UsedVoucher    = SUM(CASE WHEN Status = 'Used'    THEN 1 ELSE 0 END),
            UnusedVoucher  = SUM(CASE WHEN Status = 'Unused'  THEN 1 ELSE 0 END),
            ExpiredVoucher = SUM(CASE WHEN Status = 'Expired' THEN 1 ELSE 0 END),
            CheckedVoucher = SUM(CASE WHEN VoucherCheckDate IS NOT NULL THEN 1 ELSE 0 END)
        FROM dbo.VoucherStock_Table
        WHERE (@ProviderInt IS NULL OR ProviderId = @ProviderInt);
    END

    ELSE IF @Action = 'Insert'
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.VoucherStock_Table WHERE VoucherCode = @VoucherCode)
        BEGIN
            SELECT -1;   -- duplicate voucher code
            RETURN;
        END

        INSERT INTO dbo.VoucherStock_Table
            (ProviderId, ProductId, VoucherCode, ExpiryDate, DealerName, SaleDate, Status, AddedBy)
        VALUES
            (@ProviderInt, @ProductInt, @VoucherCode, @Expiry, @DealerName, @Sale,
             ISNULL(@Status, 'Unused'), @UserInt);

        SELECT CAST(SCOPE_IDENTITY() AS INT);
    END

    ELSE IF @Action = 'Update'
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.VoucherStock_Table
                    WHERE VoucherCode = @VoucherCode AND Id <> @IdInt)
        BEGIN
            SELECT -1;   -- duplicate voucher code
            RETURN;
        END

        UPDATE dbo.VoucherStock_Table
           SET ProviderId   = @ProviderInt,
               ProductId    = @ProductInt,
               VoucherCode  = @VoucherCode,
               ExpiryDate   = @Expiry,
               DealerName   = @DealerName,
               SaleDate     = @Sale,
               Status       = ISNULL(@Status, Status),
               ModifiedBy   = @UserInt,
               ModifiedDate = GETDATE()
         WHERE Id = @IdInt;

        SELECT @IdInt;
    END

    /* ---- Mark voucher as checked ---- */
    ELSE IF @Action = 'UpdateCheck'
    BEGIN
        UPDATE dbo.VoucherStock_Table
           SET VoucherCheckDate = GETDATE(),
               CheckedBy        = @CheckedBy,
               ModifiedDate     = GETDATE()
         WHERE Id = @IdInt;
    END
END
GO

PRINT 'Created dbo.Sp_VoucherStock_Table';
GO
