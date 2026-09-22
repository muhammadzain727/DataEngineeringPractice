SET search_path TO star, public;


SELECT
    d.CalendarYear,
    d.MonthNumber,
    s.StoreID,
    s.StoreName,
    SUM(f.SalesAmount) AS RevenueEUR
FROM FactSales AS f
JOIN DimDate AS d
    ON d.DateKey = f.DateKey
JOIN DimStore AS s
    ON s.StoreKey = f.StoreKey
GROUP BY
    d.CalendarYear,
    d.MonthNumber,
    s.StoreID,
    s.StoreName
ORDER BY
    d.CalendarYear,
    d.MonthNumber,
    s.StoreID;


SELECT
    d.FullDate,
    s.StoreID,
    s.StoreName,
    SUM(f.SalesAmount) AS RevenueEUR
FROM FactSales AS f
JOIN DimDate AS d
    ON d.DateKey = f.DateKey
JOIN DimStore AS s
    ON s.StoreKey = f.StoreKey
GROUP BY
    d.FullDate,
    s.StoreID,
    s.StoreName
ORDER BY
    d.FullDate,
    s.StoreID;


SELECT
    p.Category,
    SUM(f.SalesAmount) AS RevenueEUR
FROM FactSales AS f
JOIN DimProduct AS p
    ON p.ProductKey = f.ProductKey
GROUP BY
    p.Category
ORDER BY
    RevenueEUR DESC;


SELECT
    p.ProductID,
    p.ProductName,
    SUM(f.SalesAmount) AS RevenueEUR
FROM FactSales AS f
JOIN DimProduct AS p
    ON p.ProductKey = f.ProductKey
GROUP BY
    p.ProductID,
    p.ProductName
ORDER BY
    RevenueEUR DESC,
    p.ProductID ASC
LIMIT 3;


WITH BasketTotals AS (
    SELECT
        PurchaseID,
        SUM(Quantity) AS TotalUnits
    FROM FactSales
    GROUP BY PurchaseID
)
SELECT
    PurchaseID,
    TotalUnits
FROM BasketTotals
ORDER BY PurchaseID;


WITH BasketTotals AS (
    SELECT
        PurchaseID,
        SUM(Quantity) AS TotalUnits
    FROM FactSales
    GROUP BY PurchaseID
)
SELECT
    ROUND(AVG(TotalUnits), 4) AS AverageBasketSize
FROM BasketTotals;


SELECT
    p.ProductID,
    p.ProductName,
    SUM(f.Quantity) AS TotalUnits,
    SUM(f.SalesAmount) AS RevenueEUR,
    ROUND(
        SUM(f.SalesAmount) / SUM(f.Quantity),
        4
    ) AS AveragePricePaidPerUnit,
    ROUND(
        AVG(f.UnitPrice),
        4
    ) AS AverageLineUnitPrice
FROM FactSales AS f
JOIN DimProduct AS p
    ON p.ProductKey = f.ProductKey
GROUP BY
    p.ProductID,
    p.ProductName
ORDER BY
    p.ProductID;