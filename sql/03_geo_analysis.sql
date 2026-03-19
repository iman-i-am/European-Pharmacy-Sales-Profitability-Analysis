-- ============================================================
-- European Pharmacy Sales & Profitability Analytics
-- Script 03: Geographic Analysis (SQL Server)
-- ============================================================
-- PURPOSE:
--   Analyses revenue and margin performance across countries,
--   pharmacy types, regions, and individual pharmacies.
--   Results validate the Geographic Performance and Pharmacy
--   Type Analysis tables in the project README.
--
-- README SECTIONS VALIDATED:
--   - Geographic Performance table
--   - Pharmacy Type Analysis table
--
-- RUN ORDER: Run after 02_kpi_queries.sql
-- ============================================================

USE PharmacyAnalysis;
GO

-- ============================================================
-- SECTION 1: GEOGRAPHIC PERFORMANCE
-- ============================================================
-- Produces the exact figures shown in the Geographic
-- Performance table in the README.
--
-- Expected output:
--   Germany     = 1,567,634 | 18.2% | 28.0%
--   France      = 1,406,812 | 16.3% | 28.0%
--   Italy       = 1,332,156 | 15.4% | 28.1%
--   Belgium     = 1,246,511 | 14.4% | 28.2%
--   Netherlands =   947,748 | 11.0% | 28.0%
--   Spain       =   735,600 |  8.5% | 27.8%
--   Poland      =   714,236 |  8.3% | 28.1%
--   Austria     =   683,281 |  7.9% | 28.2%
-- ============================================================

SELECT
    p.Country,
    ROUND(SUM(f.RevenueEUR), 0)                                         AS RevenueEUR,
    ROUND(SUM(f.RevenueEUR) / NULLIF(
        (SELECT SUM(RevenueEUR) FROM dbo.FactSales), 0) * 100, 1)       AS RevenueSharePct,
    ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)   AS GrossMarginPct
FROM dbo.FactSales f
JOIN dbo.DimPharmacy p ON f.PharmacyID = p.PharmacyID
GROUP BY p.Country
ORDER BY RevenueEUR DESC;
GO

-- ============================================================
-- SECTION 2: PHARMACY TYPE ANALYSIS
-- ============================================================
-- Produces the exact figures shown in the Pharmacy Type
-- Analysis table in the README.
--
-- Expected output:
--   Urban    = 4,125,299 | 47.8% | 28.0% | ~103,133
--   Suburban = 3,109,296 | 36.0% | 28.1% | ~77,732
--   Rural    = 1,399,382 | 16.2% | 28.1% | ~34,985
-- ============================================================

SELECT
    p.PharmacyType,
    COUNT(DISTINCT f.PharmacyID)                                        AS PharmacyCount,
    SUM(f.UnitsSold)                                                    AS UnitsSold,
    ROUND(SUM(f.RevenueEUR), 0)                                         AS RevenueEUR,
    ROUND(SUM(f.MarginEUR),  0)                                         AS MarginEUR,
    ROUND(SUM(f.RevenueEUR) / NULLIF(
        (SELECT SUM(RevenueEUR) FROM dbo.FactSales), 0) * 100, 1)       AS RevenueSharePct,
    ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)   AS GrossMarginPct,
    ROUND(SUM(f.RevenueEUR) / NULLIF(
        COUNT(DISTINCT f.PharmacyID), 0), 0)                            AS AvgRevenuePerPharmacy
FROM dbo.FactSales f
JOIN dbo.DimPharmacy p ON f.PharmacyID = p.PharmacyID
GROUP BY p.PharmacyType
ORDER BY RevenueEUR DESC;
GO

-- ============================================================
-- SECTION 3: COUNTRY PERFORMANCE BY YEAR
-- ============================================================
-- Business Question: Which countries are growing vs declining
-- between 2024 and 2025?
-- ============================================================

SELECT
    p.Country,
    d.Year,
    ROUND(SUM(f.RevenueEUR), 0)                                         AS RevenueEUR,
    ROUND(SUM(f.MarginEUR),  0)                                         AS MarginEUR,
    ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)   AS GrossMarginPct,
    ROUND(SUM(f.RevenueEUR) / NULLIF(SUM(f.UnitsSold),  0), 2)         AS ASP
FROM dbo.FactSales f
JOIN dbo.DimPharmacy p ON f.PharmacyID = p.PharmacyID
JOIN dbo.DimDate     d ON f.DateKey    = d.DateKey
GROUP BY p.Country, d.Year
ORDER BY p.Country, d.Year;
GO

-- ============================================================
-- SECTION 4: YoY REVENUE GROWTH BY COUNTRY
-- ============================================================
-- Business Question: Which countries are the fastest growing
-- and which are declining?
-- ============================================================

WITH CountryYear AS (
    SELECT
        p.Country,
        d.Year,
        SUM(f.RevenueEUR) AS RevenueEUR
    FROM dbo.FactSales f
    JOIN dbo.DimPharmacy p ON f.PharmacyID = p.PharmacyID
    JOIN dbo.DimDate     d ON f.DateKey    = d.DateKey
    GROUP BY p.Country, d.Year
)
SELECT
    Country,
    Year,
    ROUND(RevenueEUR, 0) AS RevenueEUR,
    ROUND(LAG(RevenueEUR) OVER (PARTITION BY Country ORDER BY Year), 0)
                                                AS PriorYearRevenue,
    ROUND(
        (RevenueEUR - LAG(RevenueEUR) OVER (PARTITION BY Country ORDER BY Year))
        / NULLIF(LAG(RevenueEUR) OVER (PARTITION BY Country ORDER BY Year), 0) * 100
    , 1)                                        AS YoYGrowthPct
FROM CountryYear
ORDER BY Country, Year;
GO

-- ============================================================
-- SECTION 5: PHARMACY TYPE BY YEAR
-- ============================================================
-- Business Question: Is the Urban/Suburban/Rural revenue split
-- shifting over time?
-- ============================================================

SELECT
    p.PharmacyType,
    d.Year,
    ROUND(SUM(f.RevenueEUR), 0)                                         AS RevenueEUR,
    ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)   AS GrossMarginPct,
    ROUND(SUM(f.RevenueEUR) / NULLIF(SUM(f.UnitsSold),  0), 2)         AS ASP
FROM dbo.FactSales f
JOIN dbo.DimPharmacy p ON f.PharmacyID = p.PharmacyID
JOIN dbo.DimDate     d ON f.DateKey    = d.DateKey
GROUP BY p.PharmacyType, d.Year
ORDER BY p.PharmacyType, d.Year;
GO

-- ============================================================
-- SECTION 6: TOP 10 PHARMACIES BY REVENUE
-- ============================================================
-- Business Question: Which individual pharmacies are the
-- highest revenue contributors across the network?
-- ============================================================

SELECT TOP 10
    p.PharmacyName,
    p.Country,
    p.City,
    p.PharmacyType,
    p.StoreSizeBand,
    ROUND(SUM(f.RevenueEUR), 0)                                         AS RevenueEUR,
    ROUND(SUM(f.MarginEUR),  0)                                         AS MarginEUR,
    ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)   AS GrossMarginPct,
    SUM(f.UnitsSold)                                                    AS UnitsSold,
    ROUND(SUM(f.RevenueEUR) / NULLIF(SUM(f.UnitsSold),  0), 2)         AS ASP
FROM dbo.FactSales f
JOIN dbo.DimPharmacy p ON f.PharmacyID = p.PharmacyID
GROUP BY
    p.PharmacyID, p.PharmacyName, p.Country,
    p.City, p.PharmacyType, p.StoreSizeBand
ORDER BY RevenueEUR DESC;
GO

-- ============================================================
-- SECTION 7: BOTTOM 10 PHARMACIES BY REVENUE
-- ============================================================
-- Business Question: Which pharmacies are underperforming
-- and may need intervention or review?
-- ============================================================

SELECT TOP 10
    p.PharmacyName,
    p.Country,
    p.City,
    p.PharmacyType,
    p.StoreSizeBand,
    ROUND(SUM(f.RevenueEUR), 0)                                         AS RevenueEUR,
    ROUND(SUM(f.MarginEUR),  0)                                         AS MarginEUR,
    ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)   AS GrossMarginPct,
    SUM(f.UnitsSold)                                                    AS UnitsSold
FROM dbo.FactSales f
JOIN dbo.DimPharmacy p ON f.PharmacyID = p.PharmacyID
GROUP BY
    p.PharmacyID, p.PharmacyName, p.Country,
    p.City, p.PharmacyType, p.StoreSizeBand
ORDER BY RevenueEUR ASC;
GO

-- ============================================================
-- SECTION 8: PHARMACIES BEATING THEIR REGIONAL AVERAGE
-- ============================================================
-- Business Question: Which pharmacies outperform peers in
-- the same region — and by how much?
-- ============================================================

WITH PharmacyTotals AS (
    SELECT
        f.PharmacyID,
        p.PharmacyName,
        p.Country,
        p.Region,
        p.PharmacyType,
        ROUND(SUM(f.RevenueEUR), 0)                                     AS RevenueEUR,
        ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)
                                                                        AS GrossMarginPct
    FROM dbo.FactSales f
    JOIN dbo.DimPharmacy p ON f.PharmacyID = p.PharmacyID
    GROUP BY
        f.PharmacyID, p.PharmacyName,
        p.Country, p.Region, p.PharmacyType
),
RegionAvg AS (
    SELECT
        Country,
        Region,
        ROUND(AVG(RevenueEUR), 0) AS AvgRegionRevenue
    FROM PharmacyTotals
    GROUP BY Country, Region
)
SELECT
    pt.PharmacyName,
    pt.Country,
    pt.Region,
    pt.PharmacyType,
    pt.RevenueEUR,
    ra.AvgRegionRevenue,
    ROUND(pt.RevenueEUR - ra.AvgRegionRevenue, 0)   AS VsRegionAvgEUR,
    pt.GrossMarginPct
FROM PharmacyTotals pt
JOIN RegionAvg ra
    ON  pt.Country = ra.Country
    AND pt.Region  = ra.Region
WHERE pt.RevenueEUR > ra.AvgRegionRevenue
ORDER BY VsRegionAvgEUR DESC;
GO

-- ============================================================
-- SECTION 9: STORE SIZE BAND ANALYSIS
-- ============================================================
-- Business Question: Do larger stores generate proportionately
-- more revenue per pharmacy than smaller ones?
-- ============================================================

SELECT
    p.StoreSizeBand,
    COUNT(DISTINCT f.PharmacyID)                                        AS PharmacyCount,
    ROUND(SUM(f.RevenueEUR), 0)                                         AS TotalRevenueEUR,
    ROUND(SUM(f.RevenueEUR) / NULLIF(
        COUNT(DISTINCT f.PharmacyID), 0), 0)                            AS AvgRevenuePerPharmacy,
    ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)   AS GrossMarginPct,
    ROUND(SUM(f.RevenueEUR) / NULLIF(SUM(f.UnitsSold),  0), 2)         AS ASP
FROM dbo.FactSales f
JOIN dbo.DimPharmacy p ON f.PharmacyID = p.PharmacyID
GROUP BY p.StoreSizeBand
ORDER BY p.StoreSizeBand;
GO

-- ============================================================
-- SECTION 10: COUNTRY x PHARMACY TYPE MATRIX
-- ============================================================
-- Business Question: In which countries do rural or suburban
-- pharmacies punch above their weight on margin?
-- ============================================================

SELECT
    p.Country,
    p.PharmacyType,
    COUNT(DISTINCT f.PharmacyID)                                        AS PharmacyCount,
    ROUND(SUM(f.RevenueEUR), 0)                                         AS RevenueEUR,
    ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)   AS GrossMarginPct,
    ROUND(SUM(f.RevenueEUR) / NULLIF(
        COUNT(DISTINCT f.PharmacyID), 0), 0)                            AS AvgRevenuePerPharmacy
FROM dbo.FactSales f
JOIN dbo.DimPharmacy p ON f.PharmacyID = p.PharmacyID
GROUP BY p.Country, p.PharmacyType
ORDER BY p.Country, p.PharmacyType;
GO
