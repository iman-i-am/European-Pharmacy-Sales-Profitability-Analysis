-- ============================================================
-- European Pharmacy Sales & Profitability Analytics
-- Script 04: Product Analysis (SQL Server)
-- ============================================================
-- PURPOSE:
--   Analyses revenue and margin performance across product
--   categories, brands, and generic vs branded products.
--   Identifies high-volume/low-margin and hidden gem products.
--   Results validate the Product Category Performance,
--   Branded vs Generic, and High-Volume/Low-Margin tables
--   in the project README.
--
-- README SECTIONS VALIDATED:
--   - Product Category Performance table
--   - Branded vs Generic table
--   - High-Volume / Low-Margin Products table
--
-- RUN ORDER: Run after 03_geo_analysis.sql
-- ============================================================

USE PharmacyAnalysis;
GO

-- ============================================================
-- SECTION 1: README VALIDATION — PRODUCT CATEGORY PERFORMANCE
-- ============================================================
-- Produces the exact figures shown in the Product Category
-- Performance table in the README.
--
-- Expected output:
--   Prescription   = 2,797,016 | 32.4% | 21.9%
--   OTC            = 1,797,330 | 20.8% | 29.4%
--   Wellness       = 1,712,457 | 19.8% | 33.6%
--   Personal Care  = 1,454,603 | 16.8% | 33.5%
--   Medical Dev    =   872,572 | 10.1% | 25.0%
-- ============================================================

SELECT
    pr.Category,
    COUNT(DISTINCT pr.ProductID)                                        AS ProductCount,
    SUM(f.UnitsSold)                                                    AS UnitsSold,
    ROUND(SUM(f.RevenueEUR), 0)                                         AS RevenueEUR,
    ROUND(SUM(f.MarginEUR),  0)                                         AS MarginEUR,
    ROUND(SUM(f.RevenueEUR) / NULLIF(
        (SELECT SUM(RevenueEUR) FROM dbo.FactSales), 0) * 100, 1)       AS RevenueSharePct,
    ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)   AS GrossMarginPct
FROM dbo.FactSales f
JOIN dbo.DimProduct pr ON f.ProductID = pr.ProductID
GROUP BY pr.Category
ORDER BY RevenueEUR DESC;
GO

-- ============================================================
-- SECTION 2: README VALIDATION — BRANDED VS GENERIC
-- ============================================================
-- Produces the exact figures shown in the Branded vs Generic
-- table in the README.
--
-- Expected output:
--   Branded = 7,373,586 | 371,106 units | 28.5%
--   Generic = 1,260,391 |  74,687 units | 25.5%
-- ============================================================

SELECT
    CASE pr.IsGeneric
        WHEN 'Yes' THEN 'Generic'
        ELSE            'Branded'
    END                                                                 AS ProductType,
    COUNT(DISTINCT pr.ProductID)                                        AS ProductCount,
    SUM(f.UnitsSold)                                                    AS UnitsSold,
    ROUND(SUM(f.RevenueEUR), 0)                                         AS RevenueEUR,
    ROUND(SUM(f.MarginEUR),  0)                                         AS MarginEUR,
    ROUND(SUM(f.RevenueEUR) / NULLIF(
        (SELECT SUM(RevenueEUR) FROM dbo.FactSales), 0) * 100, 1)       AS RevenueSharePct,
    ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)   AS GrossMarginPct
FROM dbo.FactSales f
JOIN dbo.DimProduct pr ON f.ProductID = pr.ProductID
GROUP BY pr.IsGeneric
ORDER BY RevenueEUR DESC;
GO

-- ============================================================
-- SECTION 3: README VALIDATION — HIGH VOLUME / LOW MARGIN
-- ============================================================
-- Produces the exact figures shown in the High-Volume /
-- Low-Margin Products table in the README.
-- Definition:
--   High volume  = top 25% by units sold (above P75)
--   Low margin   = bottom 25% by gross margin % (below P25)
--
-- Expected output:
--   Medica Cough Syrup 400mg     = 3,266 units | 24.6%
--   VitaCare Allergy Tabs 400mg  = 3,169 units | 24.0%
--   AllerFree Cough Syrup 400mg  = 3,055 units | 23.8%
-- ============================================================

WITH ProductPerformance AS (
    SELECT
        pr.ProductID,
        pr.ProductName,
        pr.Category,
        pr.Brand,
        pr.IsGeneric,
        SUM(f.UnitsSold)                                                AS UnitsSold,
        ROUND(SUM(f.RevenueEUR), 0)                                     AS RevenueEUR,
        ROUND(SUM(f.MarginEUR),  0)                                     AS MarginEUR,
        ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)
                                                                        AS GrossMarginPct
    FROM dbo.FactSales f
    JOIN dbo.DimProduct pr ON f.ProductID = pr.ProductID
    GROUP BY
        pr.ProductID, pr.ProductName,
        pr.Category, pr.Brand, pr.IsGeneric
),
Thresholds AS (
    SELECT
        DISTINCT
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY UnitsSold)
            OVER() AS P75_Units,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY GrossMarginPct)
            OVER() AS P25_Margin
    FROM ProductPerformance
)
SELECT
    pp.ProductName,
    pp.Category,
    pp.Brand,
    pp.IsGeneric,
    pp.UnitsSold,
    pp.RevenueEUR,
    pp.GrossMarginPct,
    'High Vol / Low Margin' AS Flag
FROM ProductPerformance pp
CROSS JOIN Thresholds t
WHERE pp.UnitsSold      >= t.P75_Units
  AND pp.GrossMarginPct <= t.P25_Margin
ORDER BY pp.UnitsSold DESC;
GO

-- ============================================================
-- SECTION 4: CATEGORY MARGIN GAP VS NETWORK AVERAGE
-- ============================================================
-- Business Question: Which categories drag the blended network
-- margin down and by exactly how many percentage points?
-- ============================================================

WITH NetworkAvg AS (
    SELECT
        ROUND(SUM(MarginEUR) / NULLIF(SUM(RevenueEUR), 0) * 100, 2)
                                AS AvgMarginPct
    FROM dbo.FactSales
),
CategoryMargin AS (
    SELECT
        pr.Category,
        ROUND(SUM(f.MarginEUR) / NULLIF(SUM(f.RevenueEUR), 0) * 100, 2)
                                AS CategoryMarginPct
    FROM dbo.FactSales f
    JOIN dbo.DimProduct pr ON f.ProductID = pr.ProductID
    GROUP BY pr.Category
)
SELECT
    cm.Category,
    cm.CategoryMarginPct,
    na.AvgMarginPct             AS NetworkAvgMarginPct,
    ROUND(cm.CategoryMarginPct
        - na.AvgMarginPct, 2)   AS MarginGapVsNetwork,
    CASE
        WHEN cm.CategoryMarginPct > na.AvgMarginPct THEN 'Above Average'
        WHEN cm.CategoryMarginPct < na.AvgMarginPct THEN 'Below Average'
        ELSE 'At Average'
    END                         AS PerformanceFlag
FROM CategoryMargin cm
CROSS JOIN NetworkAvg na
ORDER BY MarginGapVsNetwork DESC;
GO

-- ============================================================
-- SECTION 5: CATEGORY PERFORMANCE BY YEAR
-- ============================================================
-- Business Question: Is any category growing or declining
-- in revenue and margin contribution year over year?
-- ============================================================

SELECT
    pr.Category,
    d.Year,
    SUM(f.UnitsSold)                                                    AS UnitsSold,
    ROUND(SUM(f.RevenueEUR), 0)                                         AS RevenueEUR,
    ROUND(SUM(f.MarginEUR),  0)                                         AS MarginEUR,
    ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)   AS GrossMarginPct,
    ROUND(SUM(f.RevenueEUR) / NULLIF(SUM(f.UnitsSold),  0), 2)         AS ASP
FROM dbo.FactSales f
JOIN dbo.DimProduct  pr ON f.ProductID = pr.ProductID
JOIN dbo.DimDate      d ON f.DateKey   = d.DateKey
GROUP BY pr.Category, d.Year
ORDER BY pr.Category, d.Year;
GO

-- ============================================================
-- SECTION 6: TOP 10 BRANDS BY REVENUE
-- ============================================================
-- Business Question: Which brands generate the most revenue
-- and are they also the most profitable?
-- ============================================================

SELECT TOP 10
    pr.Brand,
    COUNT(DISTINCT pr.ProductID)                                        AS ProductCount,
    SUM(f.UnitsSold)                                                    AS UnitsSold,
    ROUND(SUM(f.RevenueEUR), 0)                                         AS RevenueEUR,
    ROUND(SUM(f.MarginEUR),  0)                                         AS MarginEUR,
    ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)   AS GrossMarginPct,
    ROUND(SUM(f.RevenueEUR) / NULLIF(SUM(f.UnitsSold),  0), 2)         AS ASP
FROM dbo.FactSales f
JOIN dbo.DimProduct pr ON f.ProductID = pr.ProductID
GROUP BY pr.Brand
ORDER BY RevenueEUR DESC;
GO

-- ============================================================
-- SECTION 7: LOW VOLUME / HIGH MARGIN — HIDDEN GEMS
-- ============================================================
-- Business Question: Which niche products have excellent
-- margins worth growing — despite low current volume?
-- Definition:
--   Low volume   = bottom 25% by units sold (below P25)
--   High margin  = top 25% by gross margin % (above P75)
-- ============================================================

WITH ProductPerformance AS (
    SELECT
        pr.ProductID,
        pr.ProductName,
        pr.Category,
        pr.Brand,
        SUM(f.UnitsSold)                                                AS UnitsSold,
        ROUND(SUM(f.RevenueEUR), 0)                                     AS RevenueEUR,
        ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)
                                                                        AS GrossMarginPct
    FROM dbo.FactSales f
    JOIN dbo.DimProduct pr ON f.ProductID = pr.ProductID
    GROUP BY
        pr.ProductID, pr.ProductName,
        pr.Category, pr.Brand
),
Thresholds AS (
    SELECT
        DISTINCT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY UnitsSold)
            OVER() AS P25_Units,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY GrossMarginPct)
            OVER() AS P75_Margin
    FROM ProductPerformance
)
SELECT
    pp.ProductName,
    pp.Category,
    pp.Brand,
    pp.UnitsSold,
    pp.RevenueEUR,
    pp.GrossMarginPct,
    'Low Vol / High Margin' AS Flag
FROM ProductPerformance pp
CROSS JOIN Thresholds t
WHERE pp.UnitsSold      <= t.P25_Units
  AND pp.GrossMarginPct >= t.P75_Margin
ORDER BY pp.GrossMarginPct DESC;
GO

-- ============================================================
-- SECTION 8: CATEGORY x PHARMACY TYPE
-- ============================================================
-- Business Question: Does the product category mix differ
-- across Urban, Suburban, and Rural pharmacies?
-- ============================================================

SELECT
    p.PharmacyType,
    pr.Category,
    SUM(f.UnitsSold)                                                    AS UnitsSold,
    ROUND(SUM(f.RevenueEUR), 0)                                         AS RevenueEUR,
    ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)   AS GrossMarginPct,
    ROUND(SUM(f.RevenueEUR) / NULLIF(SUM(f.UnitsSold),  0), 2)         AS ASP
FROM dbo.FactSales f
JOIN dbo.DimPharmacy p  ON f.PharmacyID = p.PharmacyID
JOIN dbo.DimProduct  pr ON f.ProductID  = pr.ProductID
GROUP BY p.PharmacyType, pr.Category
ORDER BY p.PharmacyType, RevenueEUR DESC;
GO

-- ============================================================
-- SECTION 9: TOP PRODUCTS BY REVENUE WITHIN EACH CATEGORY
-- ============================================================
-- Business Question: Within each category, which individual
-- products are driving the most revenue?
-- ============================================================

WITH ProductRank AS (
    SELECT
        pr.Category,
        pr.ProductName,
        pr.Brand,
        pr.IsGeneric,
        ROUND(SUM(f.RevenueEUR), 0)                                     AS RevenueEUR,
        ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)
                                                                        AS GrossMarginPct,
        SUM(f.UnitsSold)                                                AS UnitsSold,
        ROW_NUMBER() OVER (
            PARTITION BY pr.Category
            ORDER BY SUM(f.RevenueEUR) DESC
        )                                                               AS RankInCategory
    FROM dbo.FactSales f
    JOIN dbo.DimProduct pr ON f.ProductID = pr.ProductID
    GROUP BY pr.Category, pr.ProductName, pr.Brand, pr.IsGeneric
)
SELECT
    Category,
    RankInCategory,
    ProductName,
    Brand,
    IsGeneric,
    UnitsSold,
    RevenueEUR,
    GrossMarginPct
FROM ProductRank
WHERE RankInCategory <= 3
ORDER BY Category, RankInCategory;
GO
