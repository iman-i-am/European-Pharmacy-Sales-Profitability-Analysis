-- ============================================================
-- European Pharmacy Sales & Profitability Analytics
-- Script 01: Schema Design & Verification (SQL Server)
-- ============================================================
-- PURPOSE:
--   Documents the star schema design for the PharmacyAnalysis
--   database. Includes table definitions, constraints, foreign
--   keys, and indexes for reference.
--
-- HOW TO USE THIS SCRIPT:
--
--   IF SETTING UP FROM SCRATCH:
--     1. Run Section A — creates database, tables, and indexes
--     2. Import pharma_data.xlsx via SSMS Import Wizard
--        (Tasks > Import Data — map each sheet to its table)
--     3. Run Section C — verify row counts
--
--   IF DATABASE ALREADY EXISTS:
--     Skip to Section C and run the verify block only.
--     Sections A and B are schema reference documentation.
-- ============================================================

/*

Database Creation

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'PharmacyAnalysis')
BEGIN
    CREATE DATABASE PharmacyAnalysis;
    PRINT '>> Database PharmacyAnalysis created.';
END
ELSE
    PRINT '>> Database PharmacyAnalysis already exists. Skipping creation.';
GO 
*/

---------------------------------------------------------------

USE PharmacyAnalysis;
GO

-- ============================================================
-- SECTION A: SCHEMA REFERENCE (run only on fresh setup)
-- ============================================================
-- NOTE: Do NOT run this section if your tables already exist
--       and contain data — it will drop and recreate them.
-- ============================================================

/*

-- ── DROP TABLES (fact first to avoid FK conflicts) ──────────
IF OBJECT_ID('dbo.FactSales',   'U') IS NOT NULL DROP TABLE dbo.FactSales;
IF OBJECT_ID('dbo.DimDate',     'U') IS NOT NULL DROP TABLE dbo.DimDate;
IF OBJECT_ID('dbo.DimPharmacy', 'U') IS NOT NULL DROP TABLE dbo.DimPharmacy;
IF OBJECT_ID('dbo.DimProduct',  'U') IS NOT NULL DROP TABLE dbo.DimProduct;

-- ── DimDate ─────────────────────────────────────────────────
CREATE TABLE dbo.DimDate (
    DateKey     INT          NOT NULL,   -- YYYYMMDD e.g. 20240101
    Date        DATE         NOT NULL,
    Year        SMALLINT     NOT NULL,
    Quarter     TINYINT      NOT NULL,
    MonthNumber TINYINT      NOT NULL,
    MonthName   NVARCHAR(20) NOT NULL,
    YearMonth   NCHAR(7)     NOT NULL,   -- e.g. '2024-01'
    CONSTRAINT PK_DimDate PRIMARY KEY (DateKey)
);

-- ── DimPharmacy ─────────────────────────────────────────────
CREATE TABLE dbo.DimPharmacy (
    PharmacyID    NCHAR(6)      NOT NULL,
    PharmacyName  NVARCHAR(100) NOT NULL,
    Country       NVARCHAR(50)  NOT NULL,
    Region        NVARCHAR(100) NOT NULL,
    City          NVARCHAR(100) NOT NULL,
    PharmacyType  NVARCHAR(20)  NOT NULL,  -- Urban / Suburban / Rural
    OpenDate      DATE          NULL,
    StoreSizeBand NCHAR(1)      NOT NULL,  -- S / M / L
    Latitude      DECIMAL(10,6) NULL,
    Longitude     DECIMAL(10,6) NULL,
    CONSTRAINT PK_DimPharmacy   PRIMARY KEY (PharmacyID),
    CONSTRAINT CK_PharmacyType  CHECK (PharmacyType  IN ('Urban','Suburban','Rural')),
    CONSTRAINT CK_StoreSizeBand CHECK (StoreSizeBand IN ('S','M','L'))
);

-- ── DimProduct ──────────────────────────────────────────────
CREATE TABLE dbo.DimProduct (
    ProductID        NCHAR(6)      NOT NULL,
    ProductName      NVARCHAR(200) NOT NULL,
    Category         NVARCHAR(50)  NOT NULL,
    Brand            NVARCHAR(100) NOT NULL,
    IsGeneric        NCHAR(3)      NOT NULL,
    PackSize         NVARCHAR(50)  NULL,
    ListPriceEUR     DECIMAL(10,2) NOT NULL,
    StandardCostEUR  DECIMAL(10,2) NOT NULL,
    LaunchDate       DATE          NULL,
    IsDiscontinued   NCHAR(3)      NOT NULL DEFAULT 'No',
    DiscontinuedDate DATE          NULL,
    CONSTRAINT PK_DimProduct     PRIMARY KEY (ProductID),
    CONSTRAINT CK_Category       CHECK (Category IN (
                                    'Prescription','OTC','Wellness',
                                    'Personal Care','Medical Devices')),
    CONSTRAINT CK_IsGeneric      CHECK (IsGeneric      IN ('Yes','No')),
    CONSTRAINT CK_IsDiscontinued CHECK (IsDiscontinued IN ('Yes','No'))
);

-- ── FactSales ───────────────────────────────────────────────
CREATE TABLE dbo.FactSales (
    SalesID    NCHAR(8)      NOT NULL,
    DateKey    INT           NOT NULL,
    PharmacyID NCHAR(6)      NOT NULL,
    ProductID  NCHAR(6)      NOT NULL,
    UnitsSold  INT           NOT NULL,
    RevenueEUR DECIMAL(12,2) NOT NULL,
    CostEUR    DECIMAL(12,2) NOT NULL,
    MarginEUR  DECIMAL(12,2) NOT NULL,
    PromoFlag  NCHAR(3)      NOT NULL,
    CONSTRAINT PK_FactSales   PRIMARY KEY (SalesID),
    CONSTRAINT FK_Sales_Date  FOREIGN KEY (DateKey)
        REFERENCES dbo.DimDate(DateKey),
    CONSTRAINT FK_Sales_Pharm FOREIGN KEY (PharmacyID)
        REFERENCES dbo.DimPharmacy(PharmacyID),
    CONSTRAINT FK_Sales_Prod  FOREIGN KEY (ProductID)
        REFERENCES dbo.DimProduct(ProductID),
    CONSTRAINT CK_PromoFlag   CHECK (PromoFlag  IN ('Yes','No')),
    CONSTRAINT CK_UnitsSold   CHECK (UnitsSold  >  0),
    CONSTRAINT CK_RevenueEUR  CHECK (RevenueEUR >= 0),
    CONSTRAINT CK_CostEUR     CHECK (CostEUR    >= 0)
);

*/

-- ============================================================
-- SECTION B: INDEXES REFERENCE (run only on fresh setup)
-- ============================================================

/*

CREATE NONCLUSTERED INDEX IX_FactSales_DateKey    ON dbo.FactSales (DateKey);
CREATE NONCLUSTERED INDEX IX_FactSales_PharmacyID ON dbo.FactSales (PharmacyID);
CREATE NONCLUSTERED INDEX IX_FactSales_ProductID  ON dbo.FactSales (ProductID);
CREATE NONCLUSTERED INDEX IX_FactSales_PromoFlag  ON dbo.FactSales (PromoFlag);
CREATE NONCLUSTERED INDEX IX_DimPharmacy_Country  ON dbo.DimPharmacy (Country);
CREATE NONCLUSTERED INDEX IX_DimPharmacy_Type     ON dbo.DimPharmacy (PharmacyType);
CREATE NONCLUSTERED INDEX IX_DimProduct_Category  ON dbo.DimProduct (Category);
CREATE NONCLUSTERED INDEX IX_DimProduct_Brand     ON dbo.DimProduct (Brand);

*/

-- ============================================================
-- SECTION C: VERIFY — run this to confirm data is loaded
-- ============================================================
-- Expected: FactSales=62,139 | DimPharmacy=120 | DimProduct=220 | DimDate=731

SELECT
    t.name  AS TableName,
    p.rows  AS [Rows],
    CASE t.name
        WHEN 'FactSales'   THEN 62139
        WHEN 'DimPharmacy' THEN 120
        WHEN 'DimProduct'  THEN 220
        WHEN 'DimDate'     THEN 731
    END     AS ExpectedRows,
    CASE
        WHEN p.rows = CASE t.name
            WHEN 'FactSales'   THEN 62139
            WHEN 'DimPharmacy' THEN 120
            WHEN 'DimProduct'  THEN 220
            WHEN 'DimDate'     THEN 731
        END THEN 'PASS'
        ELSE 'FAIL - check import'
    END     AS Status
FROM sys.tables t
JOIN sys.partitions p
    ON  t.object_id = p.object_id
    AND p.index_id IN (0,1)
WHERE t.schema_id = SCHEMA_ID('dbo')
ORDER BY t.name;
GO

-- ── Quick sanity check — preview first 3 rows of each table ─
SELECT TOP 3 * FROM dbo.DimDate     ORDER BY DateKey;
SELECT TOP 3 * FROM dbo.DimPharmacy ORDER BY PharmacyID;
SELECT TOP 3 * FROM dbo.DimProduct  ORDER BY ProductID;
SELECT TOP 3 * FROM dbo.FactSales   ORDER BY SalesID;
GO
