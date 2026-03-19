-- ============================================================
-- European Pharmacy Sales & Profitability Analytics
-- Script 06: Data Quality Checks (SQL Server)
-- ============================================================
-- PURPOSE:
--   Validates the integrity of all 4 tables before analysis.
--   Checks for nulls, duplicates, orphaned foreign keys,
--   negative values, date coverage gaps, and logical
--   inconsistencies in the data.
--
--   A clean pass on all checks confirms the dataset is
--   reliable and the README findings are trustworthy.
--
-- NOTE:
--   This script does NOT modify any data.
--   All queries are read-only diagnostic checks.
--
-- RUN ORDER: Can be run at any point after data is imported.
--            Recommended to run before scripts 02-05.
-- ============================================================

USE PharmacyAnalysis;
GO

-- ============================================================
-- SECTION 1: ROW COUNT SUMMARY
-- ============================================================
-- Quick overview of all table sizes.
-- Expected: FactSales=62,139 | DimDate=731 |
--           DimPharmacy=120  | DimProduct=220
-- ============================================================

SELECT
    'FactSales'                                 AS TableName,
    COUNT(*)                                    AS [Rows]
FROM dbo.FactSales
UNION ALL
SELECT 'DimDate',   COUNT(*) FROM dbo.DimDate
UNION ALL
SELECT 'DimPharmacy', COUNT(*) FROM dbo.DimPharmacy
UNION ALL
SELECT 'DimProduct',  COUNT(*) FROM dbo.DimProduct;
GO

-- ============================================================
-- SECTION 2: NULL CHECKS — FACT TABLE
-- ============================================================
-- Business Rule: No nulls allowed in any FactSales column.
-- Expected: All counts = 0
-- ============================================================

SELECT
    SUM(CASE WHEN SalesID    IS NULL THEN 1 ELSE 0 END) AS NullSalesID,
    SUM(CASE WHEN DateKey    IS NULL THEN 1 ELSE 0 END) AS NullDateKey,
    SUM(CASE WHEN PharmacyID IS NULL THEN 1 ELSE 0 END) AS NullPharmacyID,
    SUM(CASE WHEN ProductID  IS NULL THEN 1 ELSE 0 END) AS NullProductID,
    SUM(CASE WHEN UnitsSold  IS NULL THEN 1 ELSE 0 END) AS NullUnitsSold,
    SUM(CASE WHEN RevenueEUR IS NULL THEN 1 ELSE 0 END) AS NullRevenueEUR,
    SUM(CASE WHEN CostEUR    IS NULL THEN 1 ELSE 0 END) AS NullCostEUR,
    SUM(CASE WHEN MarginEUR  IS NULL THEN 1 ELSE 0 END) AS NullMarginEUR,
    SUM(CASE WHEN PromoFlag  IS NULL THEN 1 ELSE 0 END) AS NullPromoFlag
FROM dbo.FactSales;
GO

-- ============================================================
-- SECTION 3: NULL CHECKS — DIMENSION TABLES
-- ============================================================
-- Business Rule: Key identifiers and critical attributes
-- must not be null in dimension tables.
-- Expected: All counts = 0
-- ============================================================

-- DimPharmacy
SELECT
    'DimPharmacy'                                           AS TableName,
    SUM(CASE WHEN PharmacyID   IS NULL THEN 1 ELSE 0 END)  AS NullPharmacyID,
    SUM(CASE WHEN PharmacyName IS NULL THEN 1 ELSE 0 END)  AS NullPharmacyName,
    SUM(CASE WHEN Country      IS NULL THEN 1 ELSE 0 END)  AS NullCountry,
    SUM(CASE WHEN PharmacyType IS NULL THEN 1 ELSE 0 END)  AS NullPharmacyType,
    SUM(CASE WHEN StoreSizeBand IS NULL THEN 1 ELSE 0 END) AS NullStoreSizeBand
FROM dbo.DimPharmacy;

-- DimProduct
SELECT
    'DimProduct'                                            AS TableName,
    SUM(CASE WHEN ProductID   IS NULL THEN 1 ELSE 0 END)   AS NullProductID,
    SUM(CASE WHEN ProductName IS NULL THEN 1 ELSE 0 END)   AS NullProductName,
    SUM(CASE WHEN Category    IS NULL THEN 1 ELSE 0 END)   AS NullCategory,
    SUM(CASE WHEN Brand       IS NULL THEN 1 ELSE 0 END)   AS NullBrand,
    SUM(CASE WHEN IsGeneric   IS NULL THEN 1 ELSE 0 END)   AS NullIsGeneric
FROM dbo.DimProduct;

-- DimDate
SELECT
    'DimDate'                                               AS TableName,
    SUM(CASE WHEN DateKey     IS NULL THEN 1 ELSE 0 END)   AS NullDateKey,
    SUM(CASE WHEN Date        IS NULL THEN 1 ELSE 0 END)   AS NullDate,
    SUM(CASE WHEN Year        IS NULL THEN 1 ELSE 0 END)   AS NullYear,
    SUM(CASE WHEN MonthNumber IS NULL THEN 1 ELSE 0 END)   AS NullMonthNumber
FROM dbo.DimDate;
GO

-- ============================================================
-- SECTION 4: DUPLICATE CHECKS
-- ============================================================
-- Business Rule: Primary keys must be unique across all tables.
-- Expected: All counts = 0 (no duplicates)
-- ============================================================

-- Duplicate SalesIDs in FactSales
SELECT
    'FactSales — Duplicate SalesID'             AS CheckName,
    COUNT(*)                                    AS DuplicateCount
FROM (
    SELECT SalesID
    FROM dbo.FactSales
    GROUP BY SalesID
    HAVING COUNT(*) > 1
) duplicates;

-- Duplicate PharmacyIDs in DimPharmacy
SELECT
    'DimPharmacy — Duplicate PharmacyID'        AS CheckName,
    COUNT(*)                                    AS DuplicateCount
FROM (
    SELECT PharmacyID
    FROM dbo.DimPharmacy
    GROUP BY PharmacyID
    HAVING COUNT(*) > 1
) duplicates;

-- Duplicate ProductIDs in DimProduct
SELECT
    'DimProduct — Duplicate ProductID'          AS CheckName,
    COUNT(*)                                    AS DuplicateCount
FROM (
    SELECT ProductID
    FROM dbo.DimProduct
    GROUP BY ProductID
    HAVING COUNT(*) > 1
) duplicates;

-- Duplicate DateKeys in DimDate
SELECT
    'DimDate — Duplicate DateKey'               AS CheckName,
    COUNT(*)                                    AS DuplicateCount
FROM (
    SELECT DateKey
    FROM dbo.DimDate
    GROUP BY DateKey
    HAVING COUNT(*) > 1
) duplicates;
GO

-- ============================================================
-- SECTION 5: ORPHANED FOREIGN KEY CHECKS
-- ============================================================
-- Business Rule: Every key in FactSales must have a matching
-- record in its dimension table.
-- Expected: All counts = 0
-- ============================================================

-- DateKeys in FactSales with no match in DimDate
SELECT
    'Orphaned DateKey'                          AS CheckName,
    COUNT(*)                                    AS OrphanCount
FROM dbo.FactSales f
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.DimDate d
    WHERE d.DateKey = f.DateKey
);

-- PharmacyIDs in FactSales with no match in DimPharmacy
SELECT
    'Orphaned PharmacyID'                       AS CheckName,
    COUNT(*)                                    AS OrphanCount
FROM dbo.FactSales f
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.DimPharmacy p
    WHERE p.PharmacyID = f.PharmacyID
);

-- ProductIDs in FactSales with no match in DimProduct
SELECT
    'Orphaned ProductID'                        AS CheckName,
    COUNT(*)                                    AS OrphanCount
FROM dbo.FactSales f
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.DimProduct pr
    WHERE pr.ProductID = f.ProductID
);
GO

-- ============================================================
-- SECTION 6: NEGATIVE VALUE CHECKS
-- ============================================================
-- Business Rule: Revenue, Cost, and Units Sold must never
-- be negative. Margin can be negative (loss-making sales)
-- but flag for review if found.
-- Expected: All counts = 0
-- ============================================================

SELECT
    SUM(CASE WHEN RevenueEUR < 0 THEN 1 ELSE 0 END)    AS NegativeRevenue,
    SUM(CASE WHEN CostEUR    < 0 THEN 1 ELSE 0 END)    AS NegativeCost,
    SUM(CASE WHEN UnitsSold  < 0 THEN 1 ELSE 0 END)    AS NegativeUnits,
    SUM(CASE WHEN MarginEUR  < 0 THEN 1 ELSE 0 END)    AS NegativeMargin,
    SUM(CASE WHEN UnitsSold  = 0 THEN 1 ELSE 0 END)    AS ZeroUnits
FROM dbo.FactSales;
GO

-- ============================================================
-- SECTION 7: MARGIN CALCULATION VALIDATION
-- ============================================================
-- Business Rule: MarginEUR should equal RevenueEUR - CostEUR.
-- Flags any rows where the stored margin differs from the
-- calculated margin by more than 0.01 EUR (rounding tolerance).
-- Expected: Count = 0
-- ============================================================

SELECT
    COUNT(*)                                            AS MarginMismatchCount
FROM dbo.FactSales
WHERE ABS(MarginEUR - (RevenueEUR - CostEUR)) > 0.01;
GO

-- ============================================================
-- SECTION 8: DATE COVERAGE CHECK
-- ============================================================
-- Business Rule: Data should cover exactly 2024-01-01
-- to 2025-12-31 with no gaps in the date dimension.
--
-- Expected:
--   EarliestDate = 2024-01-01
--   LatestDate   = 2025-12-31
--   TotalDays    = 731
--   MissingDays  = 0
-- ============================================================

-- Date range and count
SELECT
    MIN(Date)                                           AS EarliestDate,
    MAX(Date)                                           AS LatestDate,
    COUNT(*)                                            AS TotalDaysInDimDate,
    DATEDIFF(DAY, MIN(Date), MAX(Date)) + 1             AS ExpectedDays,
    DATEDIFF(DAY, MIN(Date), MAX(Date)) + 1 - COUNT(*)  AS MissingDays
FROM dbo.DimDate;
GO

-- Check for any sales dates outside the expected range
SELECT
    COUNT(*)                                            AS SalesOutsideDateRange
FROM dbo.FactSales f
JOIN dbo.DimDate d ON f.DateKey = d.DateKey
WHERE d.Date < '2024-01-01'
   OR d.Date > '2025-12-31';
GO

-- ============================================================
-- SECTION 9: PROMO FLAG VALIDATION
-- ============================================================
-- Business Rule: PromoFlag must only contain 'Yes' or 'No'.
-- Expected: Only 2 distinct values, no unexpected entries.
-- ============================================================

SELECT
    PromoFlag,
    COUNT(*)                                            AS TransactionCount
FROM dbo.FactSales
GROUP BY PromoFlag
ORDER BY PromoFlag;
GO

-- ============================================================
-- SECTION 10: CATEGORY & PHARMACY TYPE VALIDATION
-- ============================================================
-- Business Rule: Category and PharmacyType must only contain
-- the defined values — no misspellings or unexpected entries.
-- ============================================================

-- Valid categories
SELECT
    Category,
    COUNT(*)                                            AS ProductCount
FROM dbo.DimProduct
GROUP BY Category
ORDER BY Category;

-- Valid pharmacy types
SELECT
    PharmacyType,
    COUNT(*)                                            AS PharmacyCount
FROM dbo.DimPharmacy
GROUP BY PharmacyType
ORDER BY PharmacyType;

-- Valid store size bands
SELECT
    StoreSizeBand,
    COUNT(*)                                            AS PharmacyCount
FROM dbo.DimPharmacy
GROUP BY StoreSizeBand
ORDER BY StoreSizeBand;
GO

-- ============================================================
-- SECTION 11: DISCONTINUED PRODUCTS STILL SELLING
-- ============================================================
-- Business Rule: Products marked IsDiscontinued = 'Yes'
-- should not appear in FactSales after their DiscontinuedDate.
-- Flags any violations for review.
-- ============================================================

SELECT
    pr.ProductID,
    pr.ProductName,
    pr.Category,
    pr.DiscontinuedDate,
    COUNT(*)                                            AS SalesTransactions,
    SUM(f.UnitsSold)                                    AS UnitsSold,
    ROUND(SUM(f.RevenueEUR), 0)                         AS RevenueEUR,
    MIN(d.Date)                                         AS FirstSaleDate,
    MAX(d.Date)                                         AS LastSaleDate
FROM dbo.FactSales f
JOIN dbo.DimProduct pr ON f.ProductID  = pr.ProductID
JOIN dbo.DimDate    d  ON f.DateKey    = d.DateKey
WHERE pr.IsDiscontinued = 'Yes'
GROUP BY
    pr.ProductID, pr.ProductName,
    pr.Category, pr.DiscontinuedDate
ORDER BY RevenueEUR DESC;
GO

-- ============================================================
-- SECTION 12: DATA QUALITY SUMMARY SCORECARD
-- ============================================================
-- Single output summarising all critical checks.
-- Target: All checks show PASS.
-- ============================================================

SELECT
    'Null SalesID'          AS CheckName,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS Status,
    COUNT(*)                AS IssueCount
FROM dbo.FactSales WHERE SalesID IS NULL

UNION ALL SELECT
    'Null DateKey',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*)
FROM dbo.FactSales WHERE DateKey IS NULL

UNION ALL SELECT
    'Null PharmacyID',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*)
FROM dbo.FactSales WHERE PharmacyID IS NULL

UNION ALL SELECT
    'Null ProductID',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*)
FROM dbo.FactSales WHERE ProductID IS NULL

UNION ALL SELECT
    'Duplicate SalesID',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*)
FROM (
    SELECT SalesID FROM dbo.FactSales
    GROUP BY SalesID HAVING COUNT(*) > 1
) d

UNION ALL SELECT
    'Orphaned DateKey',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*)
FROM dbo.FactSales f
WHERE NOT EXISTS (SELECT 1 FROM dbo.DimDate d WHERE d.DateKey = f.DateKey)

UNION ALL SELECT
    'Orphaned PharmacyID',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*)
FROM dbo.FactSales f
WHERE NOT EXISTS (SELECT 1 FROM dbo.DimPharmacy p WHERE p.PharmacyID = f.PharmacyID)

UNION ALL SELECT
    'Orphaned ProductID',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*)
FROM dbo.FactSales f
WHERE NOT EXISTS (SELECT 1 FROM dbo.DimProduct pr WHERE pr.ProductID = f.ProductID)

UNION ALL SELECT
    'Negative Revenue',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*)
FROM dbo.FactSales WHERE RevenueEUR < 0

UNION ALL SELECT
    'Negative Units',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*)
FROM dbo.FactSales WHERE UnitsSold < 0

UNION ALL SELECT
    'Margin Calculation Mismatch',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*)
FROM dbo.FactSales
WHERE ABS(MarginEUR - (RevenueEUR - CostEUR)) > 0.01

UNION ALL SELECT
    'Missing Days in Date Dim',
    CASE WHEN (DATEDIFF(DAY, MIN(Date), MAX(Date)) + 1 - COUNT(*)) = 0
         THEN 'PASS' ELSE 'FAIL' END,
    DATEDIFF(DAY, MIN(Date), MAX(Date)) + 1 - COUNT(*)
FROM dbo.DimDate;
GO
