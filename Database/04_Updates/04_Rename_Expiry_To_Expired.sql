/* ============================================================
   Status rename: 'Expiry' -> 'Expired'  (label + stored value)
   Column aliases go back to ExpiredVoucher, which is also what
   dashboard.aspx.cs reads - that page was broken by the earlier
   ExpiryVoucher rename.
   ============================================================ */
USE DSL_New;
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_VoucherStock_Status')
    ALTER TABLE dbo.VoucherStock_Table DROP CONSTRAINT CK_VoucherStock_Status;
GO

UPDATE dbo.VoucherStock_Table SET Status = 'Expired' WHERE Status = 'Expiry';
GO

ALTER TABLE dbo.VoucherStock_Table WITH CHECK
    ADD CONSTRAINT CK_VoucherStock_Status
    CHECK (Status IN ('Used','Unused','Expired','Invalid'));
GO

CREATE OR ALTER PROCEDURE dbo.Sp_VoucherProvider_Table
(
    @Action   NVARCHAR(50),
    @Id       NVARCHAR(50)  = NULL,
    @Name     NVARCHAR(150) = NULL,
    @Category NVARCHAR(100) = NULL,
    @Status   NVARCHAR(20)  = NULL,
    @FromDate NVARCHAR(30)  = NULL,
    @ToDate   NVARCHAR(30)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdInt INT  = TRY_CONVERT(INT,  NULLIF(LTRIM(RTRIM(@Id)), ''));
    DECLARE @From  DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@FromDate)), ''));
    DECLARE @To    DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@ToDate)),   ''));
    DECLARE @Today DATE = CAST(GETDATE() AS DATE);
    DECLARE @EEEnd DATE = DATEADD(DAY, 30, CAST(GETDATE() AS DATE));

    SET @Category = NULLIF(LTRIM(RTRIM(@Category)), '');
    SET @Status   = NULLIF(LTRIM(RTRIM(@Status)),   '');

    IF @Action = 'SelectSummary'
    BEGIN
        SELECT
            p.Id, p.Name, p.Category, p.Status,
            TotalVoucher   = COUNT(v.Id),
            UsedVoucher    = SUM(CASE WHEN v.Status = 'Used'    THEN 1 ELSE 0 END),
            UnusedVoucher  = SUM(CASE WHEN v.Status = 'Unused'  THEN 1 ELSE 0 END),
            ExpiredVoucher = SUM(CASE WHEN v.Status = 'Expired' THEN 1 ELSE 0 END),
            InvalidVoucher = SUM(CASE WHEN v.Status = 'Invalid' THEN 1 ELSE 0 END)
        FROM dbo.VoucherProvider_Table p
        LEFT JOIN dbo.VoucherStock_Table v
               ON v.ProviderId = p.Id
              AND (@From IS NULL OR v.SaleDate >= @From)
              AND (@To   IS NULL OR v.SaleDate <= @To)
        WHERE (@Category IS NULL OR p.Category = @Category)
          AND (@Status IS NULL OR EXISTS (
                  SELECT 1 FROM dbo.VoucherStock_Table s
                  WHERE s.ProviderId = p.Id AND s.Status = @Status))
        GROUP BY p.Id, p.Name, p.Category, p.Status
        ORDER BY p.Id;
    END

    /* Used stays unfiltered on purpose - only Unused switches to the EE figure */
    ELSE IF @Action = 'SelectEarlyExpiry'
    BEGIN
        SELECT
            p.Id, p.Name, p.Category, p.Status,
            TotalVoucher   = COUNT(v.Id),
            UsedVoucher    = SUM(CASE WHEN v.Status = 'Used' THEN 1 ELSE 0 END),
            UnusedVoucher  = SUM(CASE WHEN v.Status = 'Unused'
                                       AND v.ExpiryDate IS NOT NULL
                                       AND v.ExpiryDate BETWEEN @Today AND @EEEnd
                                      THEN 1 ELSE 0 END),
            ExpiredVoucher = SUM(CASE WHEN v.Status = 'Expired' THEN 1 ELSE 0 END),
            InvalidVoucher = SUM(CASE WHEN v.Status = 'Invalid' THEN 1 ELSE 0 END)
        FROM dbo.VoucherProvider_Table p
        LEFT JOIN dbo.VoucherStock_Table v
               ON v.ProviderId = p.Id
              AND (@From IS NULL OR v.SaleDate >= @From)
              AND (@To   IS NULL OR v.SaleDate <= @To)
        WHERE (@Category IS NULL OR p.Category = @Category)
          AND (@Status IS NULL OR EXISTS (
                  SELECT 1 FROM dbo.VoucherStock_Table s
                  WHERE s.ProviderId = p.Id AND s.Status = @Status))
        GROUP BY p.Id, p.Name, p.Category, p.Status
        ORDER BY p.Id;
    END

    ELSE IF @Action = 'SelectDropdown'
        SELECT Id, Name FROM dbo.VoucherProvider_Table WHERE Status = 'A' ORDER BY Id;

    ELSE IF @Action = 'SelectCategory'
        SELECT DISTINCT Category FROM dbo.VoucherProvider_Table
        WHERE Category IS NOT NULL AND Category <> '' ORDER BY Category;

    ELSE IF @Action = 'SelectId'
        SELECT Id, Name, Category, ContactPerson, ContactEmail, ContactNo, Status
        FROM dbo.VoucherProvider_Table WHERE Id = @IdInt;

    ELSE IF @Action = 'Insert'
    BEGIN
        INSERT INTO dbo.VoucherProvider_Table (Name, Category, Status)
        VALUES (@Name, @Category, ISNULL(@Status, 'A'));
        SELECT CAST(SCOPE_IDENTITY() AS INT);
    END

    ELSE IF @Action = 'Update'
        UPDATE dbo.VoucherProvider_Table
           SET Name = @Name, Category = @Category,
               Status = ISNULL(@Status, Status), ModifiedDate = GETDATE()
         WHERE Id = @IdInt;
END
GO

CREATE OR ALTER PROCEDURE dbo.Sp_VoucherStock_Table
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

    IF @Action IN ('Select', 'SelectAll', 'SelectFilter', 'SelectExport')
        SELECT v.Id, v.ProviderId, ProviderName = p.Name, v.ProductId, ProductName = pr.Name,
               v.VoucherCode, v.ExpiryDate, v.DealerName, v.SaleDate, v.Status,
               v.VoucherCheckDate, v.CheckedBy, v.Remarks, v.AddedDate
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

    ELSE IF @Action = 'SelectId'
        SELECT Id, ProviderId, ProductId, VoucherCode, ExpiryDate, DealerName,
               SaleDate, Status, VoucherCheckDate, CheckedBy, Remarks
        FROM dbo.VoucherStock_Table WHERE Id = @IdInt;

    ELSE IF @Action = 'SelectCheckedBy'
        SELECT DISTINCT CheckedBy FROM dbo.VoucherStock_Table
        WHERE CheckedBy IS NOT NULL AND CheckedBy <> '' ORDER BY CheckedBy;

    ELSE IF @Action = 'SelectCount'
        SELECT TotalVoucher   = COUNT(*),
               UsedVoucher    = SUM(CASE WHEN Status = 'Used'    THEN 1 ELSE 0 END),
               UnusedVoucher  = SUM(CASE WHEN Status = 'Unused'  THEN 1 ELSE 0 END),
               ExpiredVoucher = SUM(CASE WHEN Status = 'Expired' THEN 1 ELSE 0 END),
               InvalidVoucher = SUM(CASE WHEN Status = 'Invalid' THEN 1 ELSE 0 END),
               CheckedVoucher = SUM(CASE WHEN VoucherCheckDate IS NOT NULL THEN 1 ELSE 0 END)
        FROM dbo.VoucherStock_Table
        WHERE (@ProviderInt IS NULL OR ProviderId = @ProviderInt);

    ELSE IF @Action = 'Insert'
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.VoucherStock_Table WHERE VoucherCode = @VoucherCode)
        BEGIN SELECT -1; RETURN; END
        INSERT INTO dbo.VoucherStock_Table
            (ProviderId, ProductId, VoucherCode, ExpiryDate, DealerName, SaleDate, Status, AddedBy)
        VALUES (@ProviderInt, @ProductInt, @VoucherCode, @Expiry, @DealerName, @Sale,
                ISNULL(@Status, 'Unused'), @UserInt);
        SELECT CAST(SCOPE_IDENTITY() AS INT);
    END

    ELSE IF @Action = 'Update'
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.VoucherStock_Table WHERE VoucherCode = @VoucherCode AND Id <> @IdInt)
        BEGIN SELECT -1; RETURN; END
        UPDATE dbo.VoucherStock_Table
           SET ProviderId = @ProviderInt, ProductId = @ProductInt, VoucherCode = @VoucherCode,
               ExpiryDate = @Expiry, DealerName = @DealerName, SaleDate = @Sale,
               Status = ISNULL(@Status, Status), ModifiedBy = @UserInt, ModifiedDate = GETDATE()
         WHERE Id = @IdInt;
        SELECT @IdInt;
    END

    ELSE IF @Action = 'UpdateCheck'
        UPDATE dbo.VoucherStock_Table
           SET VoucherCheckDate = GETDATE(), CheckedBy = @CheckedBy, ModifiedDate = GETDATE()
         WHERE Id = @IdInt;
END
GO

SELECT Status, Cnt = COUNT(*) FROM dbo.VoucherStock_Table GROUP BY Status ORDER BY Status;
GO
