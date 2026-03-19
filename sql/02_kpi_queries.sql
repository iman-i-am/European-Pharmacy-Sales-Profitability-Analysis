-- ============================================================
-- European Pharmacy Sales & Profitability Analytics
-- Script 02: Core KPI Queries (SQL Server)
-- ============================================================
-- PURPOSE:
--   Calculates the headline KPIs for the entire network.
--   Results validate the Overall Network Performance table
--   in the project README.
--
-- DASHBOARD KPIs COVERED:
--   Total Revenue | Total Margin | Total Cost
--   Total Quantity Sold | Margin % | ASP (Avg Selling Price)
--
-- RUN ORDER: Run after 01_schema_setup.sql
-- ============================================================

USE PharmacyAnalysis;
GO

-- ============================================================
-- SECTION 1: README VALIDATION
-- ============================================================
-- Produces the exact figures shown in the Overall Network
-- Performance table in the README. Run this first to confirm
-- your data matches the documented findings.
--
-- Expected output:
--   TotalRevenueEUR    = 8,633,977
--   TotalMarginEUR     = 2,421,141
--   TotalCostEUR       = 6,212,836
--   TotalUnitsSold     = 445,793
--   TotalTransactions  = 62,139
--   GrossMarginPct     = 28.0
--   ASP                = 19.37
-- ============================================================

SELECT
    ROUND(SUM(f.RevenueEUR), 0)                                        AS TotalRevenueEUR,
    ROUND(SUM(f.MarginEUR),  0)                                        AS TotalMarginEUR,
    ROUND(SUM(f.CostEUR),    0)                                        AS TotalCostEUR,
    SUM(f.UnitsSold)                                                   AS TotalUnitsSold,
    COUNT(*)                                                           AS TotalTransactions,
    ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1) AS GrossMarginPct,
    ROUND(SUM(f.RevenueEUR) / NULLIF(SUM(f.UnitsSold),  0), 2)       AS ASP
FROM dbo.FactSales f;
GO

-- ============================================================
-- SECTION 2: YEAR-ON-YEAR PERFORMANCE
-- ============================================================
-- Business Question: Is the business growing year over year?
-- Is margin holding as revenue grows?
--
-- Expected output:
--   2024: Revenue=4,223,414 | Margin=1,181,466 | GM%=28.0
--   2025: Revenue=4,410,563 | Margin=1,239,676 | GM%=28.1
-- ============================================================

SELECT
    d.Year,
    COUNT(*)                                                           AS Transactions,
    SUM(f.UnitsSold)                                                   AS UnitsSold,
    ROUND(SUM(f.RevenueEUR), 0)                                        AS RevenueEUR,
    ROUND(SUM(f.CostEUR),    0)                                        AS CostEUR,
    ROUND(SUM(f.MarginEUR),  0)                                        AS MarginEUR,
    ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1) AS GrossMarginPct,
    ROUND(SUM(f.RevenueEUR) / NULLIF(SUM(f.UnitsSold),  0), 2)       AS ASP
FROM dbo.FactSales f
JOIN dbo.DimDate d ON f.DateKey = d.DateKey
GROUP BY d.Year
ORDER BY d.Year;
GO

-- ============================================================
-- SECTION 3: YoY REVENUE GROWTH %
-- ============================================================
-- Business Question: What is the exact revenue growth rate
-- between 2024 and 2025?
--
-- Expected output:
--   2025 YoY Growth = +4.4%
-- ============================================================

WITH YearlyRevenue AS (
    SELECT
        d.Year,
        SUM(f.RevenueEUR) AS RevenueEUR
    FROM dbo.FactSales f
    JOIN dbo.DimDate d ON f.DateKey = d.DateKey
    GROUP BY d.Year
)
SELECT
    y.Year,
    ROUND(y.RevenueEUR, 0)                                      AS RevenueEUR,
    ROUND(LAG(y.RevenueEUR) OVER (ORDER BY y.Year), 0)          AS PriorYearRevenue,
    ROUND(
        (y.RevenueEUR - LAG(y.RevenueEUR) OVER (ORDER BY y.Year))
        / NULLIF(LAG(y.RevenueEUR) OVER (ORDER BY y.Year), 0) * 100
    , 1)                                                        AS YoYGrowthPct
FROM YearlyRevenue y
ORDER BY y.Year;
GO

-- ============================================================
-- SECTION 4: QUARTERLY TREND
-- ============================================================
-- Business Question: Which quarter drives peak performance?
-- Are margins consistent across quarters?
-- ============================================================

SELECT
    d.Year,
    d.Quarter,
    CONCAT(d.Year, ' Q', d.Quarter)                                    AS YearQuarter,
    COUNT(*)                                                           AS Transactions,
    SUM(f.UnitsSold)                                                   AS UnitsSold,
    ROUND(SUM(f.RevenueEUR), 0)                                        AS RevenueEUR,
    ROUND(SUM(f.MarginEUR),  0)                                        AS MarginEUR,
    ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1) AS GrossMarginPct,
    ROUND(SUM(f.RevenueEUR) / NULLIF(SUM(f.UnitsSold),  0), 2)       AS ASP
FROM dbo.FactSales f
JOIN dbo.DimDate d ON f.DateKey = d.DateKey
GROUP BY d.Year, d.Quarter
ORDER BY d.Year, d.Quarter;
GO

-- ============================================================
-- SECTION 5: MONTHLY REVENUE TREND
-- ============================================================
-- Business Question: Are there seasonal patterns in revenue,
-- margin, and ASP across the 24-month period?
--
-- Expected insight:
--   Peak months  = May 2025 (€392,674) and July 2024 (€388,334)
--   Trough month = February 2024 (€327,319)
--   Margin range = 27.7% to 28.5% across all 24 months
--   ASP range    = €18.19 (Dec 2025) to €20.19 (Oct 2025)
--   Highest ASP  = October 2025 at €20.19
--   Lowest ASP   = December 2025 at €18.19
--   Note: December 2025 is highest margin month (28.5%)
--         despite lowest ASP — driven by higher unit volume
--         (21,087 units vs network avg ~18,580)
-- ============================================================

SELECT
    d.Year,
    d.MonthNumber,
    d.MonthName,
    d.YearMonth,
    COUNT(*)                                                           AS Transactions,
    SUM(f.UnitsSold)                                                   AS UnitsSold,
    ROUND(SUM(f.RevenueEUR), 0)                                        AS RevenueEUR,
    ROUND(SUM(f.CostEUR),    0)                                        AS CostEUR,
    ROUND(SUM(f.MarginEUR),  0)                                        AS MarginEUR,
    ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1) AS GrossMarginPct,
    ROUND(SUM(f.RevenueEUR) / NULLIF(SUM(f.UnitsSold),  0), 2)       AS ASP
FROM dbo.FactSales f
JOIN dbo.DimDate d ON f.DateKey = d.DateKey
GROUP BY d.Year, d.MonthNumber, d.MonthName, d.YearMonth
ORDER BY d.Year, d.MonthNumber;
GO

-- ============================================================
-- SECTION 6: PEAK AND TROUGH MONTHS
-- ============================================================
-- Business Question: Which specific months are the best and
-- worst performing across the full 2-year period?
-- ============================================================

WITH MonthlyRevenue AS (
    SELECT
        d.YearMonth,
        d.MonthName,
        d.Year,
        ROUND(SUM(f.RevenueEUR), 0)                                        AS RevenueEUR,
        ROUND(SUM(f.MarginEUR),  0)                                        AS MarginEUR,
        ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1) AS GrossMarginPct
    FROM dbo.FactSales f
    JOIN dbo.DimDate d ON f.DateKey = d.DateKey
    GROUP BY d.YearMonth, d.MonthName, d.Year
)
SELECT * FROM (
    SELECT TOP 3
        YearMonth, MonthName, Year, RevenueEUR, GrossMarginPct,
        'Peak' AS Label
    FROM MonthlyRevenue
    ORDER BY RevenueEUR DESC
) AS PeakMonths

UNION ALL

SELECT * FROM (
    SELECT TOP 3
        YearMonth, MonthName, Year, RevenueEUR, GrossMarginPct,
        'Trough' AS Label
    FROM MonthlyRevenue
    ORDER BY RevenueEUR ASC
) AS TroughMonths;
GO

-- ============================================================
-- SECTION 7: MARGIN STABILITY CHECK
-- ============================================================
-- Business Question: How stable is gross margin % month to
-- month? A tight range signals disciplined pricing.
--
-- Expected output:
--   Min GM% = 27.7  |  Max GM% = 28.5  |  Range = 0.8pp
-- ============================================================

WITH MonthlyMargin AS (
    SELECT
        d.YearMonth,
        ROUND(SUM(f.MarginEUR) / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1) AS GrossMarginPct
    FROM dbo.FactSales f
    JOIN dbo.DimDate d ON f.DateKey = d.DateKey
    GROUP BY d.YearMonth
)
SELECT
    MIN(GrossMarginPct)                    AS MinGrossMarginPct,
    MAX(GrossMarginPct)                    AS MaxGrossMarginPct,
    ROUND(MAX(GrossMarginPct)
        - MIN(GrossMarginPct), 1)          AS MarginRangePp,
    ROUND(AVG(GrossMarginPct), 2)          AS AvgGrossMarginPct
FROM MonthlyMargin;
GO
