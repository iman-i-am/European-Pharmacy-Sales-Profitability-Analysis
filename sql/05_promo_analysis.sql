-- ============================================================
-- European Pharmacy Sales & Profitability Analytics
-- Script 05: Promotional Impact Analysis (SQL Server)
-- ============================================================
-- PURPOSE:
--   Analyses the impact of promotions on revenue, margin,
--   and volume across the network. Quantifies the exact
--   margin penalty of running promotions and identifies
--   which segments rely on promotions most heavily.
--   Results validate the Promotional Impact table in the
--   project README.
--
-- README SECTIONS VALIDATED:
--   - Promotional Impact table
--
-- RUN ORDER: Run after 04_product_analysis.sql
-- ============================================================

USE PharmacyAnalysis;
GO

-- ============================================================
-- SECTION 1: README VALIDATION — PROMOTIONAL IMPACT
-- ============================================================
-- Produces the exact figures shown in the Promotional Impact
-- table in the README.
--
-- Expected output:
--   Non-Promotional = 7,722,676 | 89.4% | 393,608 | 29.0%
--   Promotional     =   911,301 | 10.6% |  52,185 | 19.9%
-- ============================================================

SELECT
    f.PromoFlag                                                         AS SalesType,
    COUNT(*)                                                            AS Transactions,
    SUM(f.UnitsSold)                                                    AS UnitsSold,
    ROUND(SUM(f.RevenueEUR), 0)                                         AS RevenueEUR,
    ROUND(SUM(f.MarginEUR),  0)                                         AS MarginEUR,
    ROUND(SUM(f.RevenueEUR) / NULLIF(
        (SELECT SUM(RevenueEUR) FROM dbo.FactSales), 0) * 100, 1)       AS RevenueSharePct,
    ROUND(SUM(f.UnitsSold) / NULLIF(
        CAST((SELECT SUM(UnitsSold) FROM dbo.FactSales) AS FLOAT),0) * 100, 1)
                                                                        AS UnitSharePct,
    ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)   AS GrossMarginPct
FROM dbo.FactSales f
GROUP BY f.PromoFlag
ORDER BY f.PromoFlag DESC;
GO

-- ============================================================
-- SECTION 2: MARGIN PENALTY CALCULATION
-- ============================================================
-- Business Question: Exactly how much margin is lost by
-- running promotions vs selling at standard price?
--
-- Expected output:
--   NonPromoMarginPct    = 29.0%
--   PromoMarginPct       = 19.9%
--   MarginPenaltyPct     =  9.1pp
--   EstimatedMarginLoss  = ~83,000 EUR
-- ============================================================

WITH PromoSummary AS (
    SELECT
        PromoFlag,
        ROUND(SUM(MarginEUR)  / NULLIF(SUM(RevenueEUR), 0) * 100, 2)   AS MarginPct,
        ROUND(SUM(RevenueEUR), 0)                                       AS RevenueEUR
    FROM dbo.FactSales
    GROUP BY PromoFlag
)
SELECT
    MAX(CASE WHEN PromoFlag = 'No'  THEN MarginPct  END)                AS NonPromoMarginPct,
    MAX(CASE WHEN PromoFlag = 'Yes' THEN MarginPct  END)                AS PromoMarginPct,
    MAX(CASE WHEN PromoFlag = 'No'  THEN MarginPct  END)
  - MAX(CASE WHEN PromoFlag = 'Yes' THEN MarginPct  END)                AS MarginPenaltyPct,
    ROUND(
        MAX(CASE WHEN PromoFlag = 'Yes' THEN RevenueEUR END)
      * (MAX(CASE WHEN PromoFlag = 'No'  THEN MarginPct  END)
       - MAX(CASE WHEN PromoFlag = 'Yes' THEN MarginPct  END)) / 100
    , 0)                                                                AS EstimatedMarginLossEUR
FROM PromoSummary;
GO

-- ============================================================
-- SECTION 3: PROMO IMPACT BY CATEGORY
-- ============================================================
-- Business Question: Which product categories absorb the
-- biggest margin penalty when sold under promotion?
-- ============================================================

SELECT
    pr.Category,
    f.PromoFlag,
    COUNT(*)                                                            AS Transactions,
    SUM(f.UnitsSold)                                                    AS UnitsSold,
    ROUND(SUM(f.RevenueEUR), 0)                                         AS RevenueEUR,
    ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)   AS GrossMarginPct
FROM dbo.FactSales f
JOIN dbo.DimProduct pr ON f.ProductID = pr.ProductID
GROUP BY pr.Category, f.PromoFlag
ORDER BY pr.Category, f.PromoFlag DESC;
GO

-- ============================================================
-- SECTION 4: PROMO MARGIN PENALTY BY CATEGORY
-- ============================================================
-- Business Question: Which category has the steepest margin
-- drop when sold on promotion vs standard price?
-- ============================================================

WITH CategoryPromo AS (
    SELECT
        pr.Category,
        f.PromoFlag,
        ROUND(SUM(f.MarginEUR) / NULLIF(SUM(f.RevenueEUR), 0) * 100, 2)
                                                                        AS MarginPct
    FROM dbo.FactSales f
    JOIN dbo.DimProduct pr ON f.ProductID = pr.ProductID
    GROUP BY pr.Category, f.PromoFlag
)
SELECT
    Category,
    MAX(CASE WHEN PromoFlag = 'No'  THEN MarginPct END)                 AS NonPromoMarginPct,
    MAX(CASE WHEN PromoFlag = 'Yes' THEN MarginPct END)                 AS PromoMarginPct,
    MAX(CASE WHEN PromoFlag = 'No'  THEN MarginPct END)
  - MAX(CASE WHEN PromoFlag = 'Yes' THEN MarginPct END)                 AS MarginPenaltyPct
FROM CategoryPromo
GROUP BY Category
ORDER BY MarginPenaltyPct DESC;
GO

-- ============================================================
-- SECTION 5: PROMO RELIANCE BY COUNTRY
-- ============================================================
-- Business Question: Which countries use promotions most
-- aggressively as a share of their total revenue?
-- ============================================================

SELECT
    p.Country,
    ROUND(SUM(CASE WHEN f.PromoFlag = 'Yes' THEN f.RevenueEUR ELSE 0 END) /
          NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)                        AS PromoRevenueSharePct,
    ROUND(SUM(CASE WHEN f.PromoFlag = 'Yes' THEN f.UnitsSold  ELSE 0 END) /
          NULLIF(CAST(SUM(f.UnitsSold) AS FLOAT), 0) * 100, 1)          AS PromoUnitSharePct,
    ROUND(SUM(CASE WHEN f.PromoFlag = 'Yes' THEN f.MarginEUR  ELSE 0 END) /
          NULLIF(SUM(CASE WHEN f.PromoFlag = 'Yes'
                          THEN f.RevenueEUR ELSE 0 END), 0) * 100, 1)   AS PromoGrossMarginPct,
    ROUND(SUM(CASE WHEN f.PromoFlag = 'No'  THEN f.MarginEUR  ELSE 0 END) /
          NULLIF(SUM(CASE WHEN f.PromoFlag = 'No'
                          THEN f.RevenueEUR ELSE 0 END), 0) * 100, 1)   AS NonPromoGrossMarginPct
FROM dbo.FactSales f
JOIN dbo.DimPharmacy p ON f.PharmacyID = p.PharmacyID
GROUP BY p.Country
ORDER BY PromoRevenueSharePct DESC;
GO

-- ============================================================
-- SECTION 6: PROMO RELIANCE BY PHARMACY TYPE
-- ============================================================
-- Business Question: Are Rural pharmacies more dependent on
-- promotions to drive traffic than Urban ones?
-- ============================================================

SELECT
    p.PharmacyType,
    ROUND(SUM(CASE WHEN f.PromoFlag = 'Yes' THEN f.RevenueEUR ELSE 0 END) /
          NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)                        AS PromoRevenueSharePct,
    ROUND(SUM(CASE WHEN f.PromoFlag = 'Yes' THEN f.UnitsSold  ELSE 0 END) /
          NULLIF(CAST(SUM(f.UnitsSold) AS FLOAT), 0) * 100, 1)          AS PromoUnitSharePct,
    ROUND(SUM(CASE WHEN f.PromoFlag = 'Yes' THEN f.MarginEUR  ELSE 0 END) /
          NULLIF(SUM(CASE WHEN f.PromoFlag = 'Yes'
                          THEN f.RevenueEUR ELSE 0 END), 0) * 100, 1)   AS PromoGrossMarginPct,
    ROUND(SUM(CASE WHEN f.PromoFlag = 'No'  THEN f.MarginEUR  ELSE 0 END) /
          NULLIF(SUM(CASE WHEN f.PromoFlag = 'No'
                          THEN f.RevenueEUR ELSE 0 END), 0) * 100, 1)   AS NonPromoGrossMarginPct
FROM dbo.FactSales f
JOIN dbo.DimPharmacy p ON f.PharmacyID = p.PharmacyID
GROUP BY p.PharmacyType
ORDER BY PromoRevenueSharePct DESC;
GO

-- ============================================================
-- SECTION 7: MONTHLY PROMO TREND
-- ============================================================
-- Business Question: Are promotions increasing as a share of
-- revenue over time — or is the business reducing reliance?
-- ============================================================

SELECT
    d.Year,
    d.MonthNumber,
    d.MonthName,
    d.YearMonth,
    ROUND(SUM(CASE WHEN f.PromoFlag = 'Yes' THEN f.RevenueEUR ELSE 0 END), 0)
                                                                        AS PromoRevenueEUR,
    ROUND(SUM(CASE WHEN f.PromoFlag = 'No'  THEN f.RevenueEUR ELSE 0 END), 0)
                                                                        AS NonPromoRevenueEUR,
    ROUND(SUM(CASE WHEN f.PromoFlag = 'Yes' THEN f.RevenueEUR ELSE 0 END) /
          NULLIF(SUM(f.RevenueEUR), 0) * 100, 1)                        AS PromoSharePct,
    ROUND(SUM(CASE WHEN f.PromoFlag = 'Yes' THEN f.MarginEUR  ELSE 0 END) /
          NULLIF(SUM(CASE WHEN f.PromoFlag = 'Yes'
                          THEN f.RevenueEUR ELSE 0 END), 0) * 100, 1)   AS PromoGrossMarginPct
FROM dbo.FactSales f
JOIN dbo.DimDate d ON f.DateKey = d.DateKey
GROUP BY d.Year, d.MonthNumber, d.MonthName, d.YearMonth
ORDER BY d.Year, d.MonthNumber;
GO

-- ============================================================
-- SECTION 8: TOP 15 MOST PROMOTED PRODUCTS
-- ============================================================
-- Business Question: Which products are most dependent on
-- promotions to sell — and what is their margin penalty?
-- ============================================================

SELECT TOP 15
    pr.ProductName,
    pr.Category,
    pr.Brand,
    SUM(CASE WHEN f.PromoFlag = 'Yes' THEN f.UnitsSold  ELSE 0 END)    AS PromoUnits,
    SUM(CASE WHEN f.PromoFlag = 'No'  THEN f.UnitsSold  ELSE 0 END)    AS NonPromoUnits,
    ROUND(SUM(CASE WHEN f.PromoFlag = 'Yes' THEN f.RevenueEUR ELSE 0 END), 0)
                                                                        AS PromoRevenueEUR,
    ROUND(SUM(CASE WHEN f.PromoFlag = 'Yes' THEN f.MarginEUR  ELSE 0 END) /
          NULLIF(SUM(CASE WHEN f.PromoFlag = 'Yes'
                          THEN f.RevenueEUR ELSE 0 END), 0) * 100, 1)  AS PromoMarginPct,
    ROUND(SUM(CASE WHEN f.PromoFlag = 'No'  THEN f.MarginEUR  ELSE 0 END) /
          NULLIF(SUM(CASE WHEN f.PromoFlag = 'No'
                          THEN f.RevenueEUR ELSE 0 END), 0) * 100, 1)  AS NonPromoMarginPct,
    ROUND(
        (SUM(CASE WHEN f.PromoFlag = 'No'  THEN f.MarginEUR  ELSE 0 END) /
         NULLIF(SUM(CASE WHEN f.PromoFlag = 'No'
                         THEN f.RevenueEUR ELSE 0 END), 0))
       -(SUM(CASE WHEN f.PromoFlag = 'Yes' THEN f.MarginEUR  ELSE 0 END) /
         NULLIF(SUM(CASE WHEN f.PromoFlag = 'Yes'
                         THEN f.RevenueEUR ELSE 0 END), 0))
    * 100, 1)                                                           AS MarginPenaltyPct
FROM dbo.FactSales f
JOIN dbo.DimProduct pr ON f.ProductID = pr.ProductID
GROUP BY pr.ProductName, pr.Category, pr.Brand
HAVING SUM(CASE WHEN f.PromoFlag = 'Yes' THEN f.UnitsSold ELSE 0 END) > 0
ORDER BY PromoRevenueEUR DESC;
GO

-- ============================================================
-- SECTION 9: PROMO IMPACT BY YEAR
-- ============================================================
-- Business Question: Is the margin penalty from promotions
-- getting better or worse between 2024 and 2025?
-- ============================================================

WITH YearPromo AS (
    SELECT
        d.Year,
        f.PromoFlag,
        ROUND(SUM(f.MarginEUR)  / NULLIF(SUM(f.RevenueEUR), 0) * 100, 2)
                                                                        AS MarginPct,
        ROUND(SUM(f.RevenueEUR), 0)                                     AS RevenueEUR
    FROM dbo.FactSales f
    JOIN dbo.DimDate d ON f.DateKey = d.DateKey
    GROUP BY d.Year, f.PromoFlag
)
SELECT
    Year,
    MAX(CASE WHEN PromoFlag = 'No'  THEN MarginPct END)                 AS NonPromoMarginPct,
    MAX(CASE WHEN PromoFlag = 'Yes' THEN MarginPct END)                 AS PromoMarginPct,
    MAX(CASE WHEN PromoFlag = 'No'  THEN MarginPct END)
  - MAX(CASE WHEN PromoFlag = 'Yes' THEN MarginPct END)                 AS MarginPenaltyPct,
    MAX(CASE WHEN PromoFlag = 'Yes' THEN RevenueEUR END)                AS PromoRevenueEUR
FROM YearPromo
GROUP BY Year
ORDER BY Year;
GO

