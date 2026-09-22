# Data Engineering Practice 3

## Dimensional Modeling and Star Schema

This README contains everything completed so far, from environment setup
through Exercise A and Exercise B.

The goal is that a partner can follow this file step by step, copy the
commands and SQL, and reproduce the same results without needing to
figure out what to do.

------------------------------------------------------------------------

# 1. What are we building?

We are building a small sales data warehouse in PostgreSQL using a
**Star Schema**.

The warehouse has four dimensions:

1.  `DimDate`
2.  `DimStore`
3.  `DimProduct`
4.  `DimCustomer`

And one fact table:

5.  `FactSales`

The basic idea is:

``` text
                 DimDate
                    |
                    |
DimStore ---- FactSales ---- DimProduct
                    |
                    |
              DimCustomer
```

`FactSales` stores individual sales lines.

The dimension tables give descriptive information about those sales.

------------------------------------------------------------------------

# 2. Tools used

We used:

-   PostgreSQL
-   Docker
-   Docker Compose
-   pgAdmin
-   VS Code

Our Docker setup uses:

``` text
PostgreSQL port: 5434
pgAdmin port: 5052
Database: star_schema
Username: data_engineer
```

------------------------------------------------------------------------

# 3. Project structure

The project structure is:

``` text
DataEngineeringPractice/
│
├── compose.yml
├── .env
│
└── sql/
    ├── 01_create_tables.sql
    ├── 02_load_data.sql
    ├── 03_analysis.sql
    └── 04_validate.sql
```

------------------------------------------------------------------------

# 4. Environment file

Create `.env`:

``` env
POSTGRES_USER=data_engineer
POSTGRES_PASSWORD=local_practice_password
POSTGRES_DB=star_schema
POSTGRES_PORT=5434
PGADMIN_DEFAULT_EMAIL=admin@example.com
PGADMIN_DEFAULT_PASSWORD=local_admin_password
PGADMIN_PORT=5052
```

------------------------------------------------------------------------

# 5. Docker Compose

Create `compose.yml`:

``` yaml
name: star-schema-practice

services:
  db:
    image: postgres:16.4
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
      PGUSER: ${POSTGRES_USER}
      PGPASSWORD: ${POSTGRES_PASSWORD}
      PGDATABASE: ${POSTGRES_DB}
    ports:
      - "127.0.0.1:${POSTGRES_PORT:-5434}:5432"
    volumes:
      - ./pgdata:/var/lib/postgresql/data
      - ./sql:/sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \"$${POSTGRES_USER}\" -d \"$${POSTGRES_DB}\""]
      interval: 5s
      timeout: 5s
      retries: 10

  pgadmin:
    image: elestio/pgadmin:REL-8_10
    environment:
      PGADMIN_DEFAULT_EMAIL: ${PGADMIN_DEFAULT_EMAIL}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_DEFAULT_PASSWORD}
    ports:
      - "127.0.0.1:${PGADMIN_PORT:-5052}:80"
    depends_on:
      db:
        condition: service_healthy
```

------------------------------------------------------------------------

# 6. Start Docker

Open the VS Code terminal.

Go to the folder containing `compose.yml`:

``` powershell
cd D:\UT\DataEngineeringPractice\DataEngineeringPractice
```

Start the containers:

``` powershell
docker compose up -d
```

Check the containers:

``` powershell
docker compose ps
```

Expected result:

``` text
star-schema-practice-db-1       postgres:16.4    Up ... (healthy)
star-schema-practice-pgadmin-1  pgAdmin          Up ...
```

PostgreSQL should be available at:

``` text
localhost:5434
```

------------------------------------------------------------------------

# 7. Connect using pgAdmin

Open the native Windows pgAdmin.

Create or use a PostgreSQL server connection with:

``` text
Host: localhost
Port: 5434
Maintenance database: star_schema
Username: data_engineer
Password: local_practice_password
```

Important:

The PostgreSQL login and pgAdmin web login are different things.

If using Docker pgAdmin at:

``` text
http://localhost:5052
```

use:

``` text
Email: admin@example.com
Password: local_admin_password
```

------------------------------------------------------------------------

# 8. Create the Star Schema tables

File:

``` text
sql/01_create_tables.sql
```

Use this SQL:

``` sql
BEGIN;

DROP SCHEMA IF EXISTS star CASCADE;

CREATE SCHEMA star;

SET search_path TO star, public;

CREATE TABLE DimDate (
    DateKey INTEGER PRIMARY KEY,
    FullDate DATE NOT NULL UNIQUE,
    CalendarYear SMALLINT NOT NULL,
    MonthNumber SMALLINT NOT NULL,
    QuarterNumber SMALLINT NOT NULL,
    DayOfMonth SMALLINT NOT NULL,
    ISOWeekday SMALLINT NOT NULL
);

CREATE TABLE DimStore (
    StoreKey INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    StoreID INTEGER NOT NULL UNIQUE,
    StoreName TEXT NOT NULL,
    City TEXT NOT NULL
);

CREATE TABLE DimProduct (
    ProductKey INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ProductID INTEGER NOT NULL UNIQUE,
    ProductName TEXT NOT NULL,
    Category TEXT NOT NULL
);

CREATE TABLE DimCustomer (
    CustomerKey INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    CustomerID INTEGER NOT NULL UNIQUE,
    CustomerName TEXT NOT NULL,
    City TEXT NOT NULL
);

CREATE TABLE FactSales (
    SaleKey INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    PurchaseID INTEGER NOT NULL,
    LineNumber INTEGER NOT NULL CHECK (LineNumber > 0),
    DateKey INTEGER NOT NULL REFERENCES DimDate(DateKey),
    StoreKey INTEGER NOT NULL REFERENCES DimStore(StoreKey),
    ProductKey INTEGER NOT NULL REFERENCES DimProduct(ProductKey),
    CustomerKey INTEGER NOT NULL REFERENCES DimCustomer(CustomerKey),
    Quantity INTEGER NOT NULL CHECK (Quantity > 0),
    UnitPrice NUMERIC(10,2) NOT NULL CHECK (UnitPrice >= 0),
    SalesAmount NUMERIC(12,2) NOT NULL,

    CONSTRAINT purchase_line_unique
        UNIQUE (PurchaseID, LineNumber),

    CONSTRAINT sales_amount_matches_line
        CHECK (SalesAmount = Quantity * UnitPrice)
);

COMMIT;
```

Run it from the VS Code terminal:

``` powershell
docker compose exec db psql -v ON_ERROR_STOP=1 -f /sql/01_create_tables.sql
```

Expected:

``` text
BEGIN
DROP SCHEMA
CREATE SCHEMA
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
COMMIT
```

The five tables are now created.

------------------------------------------------------------------------

# 9. Load the sample data

File:

``` text
sql/02_load_data.sql
```

Use this SQL:

``` sql
BEGIN;

SET search_path TO star, public;

TRUNCATE FactSales, DimDate, DimStore, DimProduct, DimCustomer
RESTART IDENTITY;

INSERT INTO DimDate
    (
        DateKey,
        FullDate,
        CalendarYear,
        MonthNumber,
        QuarterNumber,
        DayOfMonth,
        ISOWeekday
    )
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INTEGER,
    d::DATE,
    EXTRACT(YEAR FROM d),
    EXTRACT(MONTH FROM d),
    EXTRACT(QUARTER FROM d),
    EXTRACT(DAY FROM d),
    EXTRACT(ISODOW FROM d)
FROM generate_series(
    TIMESTAMP '2026-09-01',
    TIMESTAMP '2026-10-31',
    INTERVAL '1 day'
) AS dates(d);

INSERT INTO DimStore
    (StoreID, StoreName, City)
VALUES
    (10, 'Tallinn Central', 'Tallinn'),
    (20, 'Tartu Centre', 'Tartu');

INSERT INTO DimProduct
    (ProductID, ProductName, Category)
VALUES
    (101, 'Apple', 'Fruit'),
    (102, 'Banana', 'Fruit'),
    (103, 'Milk', 'Dairy'),
    (104, 'Bread', 'Bakery');

INSERT INTO DimCustomer
    (CustomerID, CustomerName, City)
VALUES
    (0, 'Unknown customer', 'Unknown'),
    (1001, 'Alice Smith', 'Tallinn'),
    (1002, 'Bob Jones', 'Tartu'),
    (1003, 'Carol Kask', 'Parnu');

CREATE TEMP TABLE SourceSales (
    PurchaseID INTEGER,
    LineNumber INTEGER,
    SaleDate DATE,
    StoreID INTEGER,
    ProductID INTEGER,
    CustomerID INTEGER,
    Quantity INTEGER,
    UnitPrice NUMERIC(10,2)
) ON COMMIT DROP;

INSERT INTO SourceSales
VALUES
    (1001, 1, '2026-09-30', 10, 101, 1001,  2, 1.00),
    (1001, 2, '2026-09-30', 10, 103, 1001,  1, 2.00),
    (1002, 1, '2026-09-30', 10, 101, 1001,  5, 1.20),
    (1002, 2, '2026-09-30', 10, 104, 1001,  2, 1.50),
    (1003, 1, '2026-09-30', 20, 102, 1002,  3, 0.80),
    (1003, 2, '2026-09-30', 20, 103, 1002,  2, 2.50),
    (1004, 1, '2026-10-01', 10, 101, 1002, 10, 1.00),
    (1004, 2, '2026-10-01', 10, 104, 1002,  1, 2.00),
    (1005, 1, '2026-10-01', 20, 103, 1003,  4, 2.00),
    (1005, 2, '2026-10-01', 20, 104, 1003,  3, 1.50),
    (1006, 1, '2026-10-02', 20, 102,    0,  1, 1.00),
    (1006, 2, '2026-10-02', 20, 101,    0,  2, 1.50),
    (1006, 3, '2026-10-02', 20, 101,    0,  1, 1.50),
    (1007, 1, '2026-10-02', 10, 104, 1001,  4, 1.25),
    (1007, 2, '2026-10-02', 10, 102, 1001,  2, 0.75);

INSERT INTO FactSales
    (
        PurchaseID,
        LineNumber,
        DateKey,
        StoreKey,
        ProductKey,
        CustomerKey,
        Quantity,
        UnitPrice,
        SalesAmount
    )
SELECT
    s.PurchaseID,
    s.LineNumber,
    (
        SELECT DateKey
        FROM DimDate
        WHERE FullDate = s.SaleDate
    ),
    (
        SELECT StoreKey
        FROM DimStore
        WHERE StoreID = s.StoreID
    ),
    (
        SELECT ProductKey
        FROM DimProduct
        WHERE ProductID = s.ProductID
    ),
    (
        SELECT CustomerKey
        FROM DimCustomer
        WHERE CustomerID = s.CustomerID
    ),
    s.Quantity,
    s.UnitPrice,
    s.Quantity * s.UnitPrice
FROM SourceSales AS s;

COMMIT;
```

Run:

``` powershell
docker compose exec db psql -v ON_ERROR_STOP=1 -f /sql/02_load_data.sql
```

Expected important result:

``` text
INSERT 0 15
INSERT 0 15
COMMIT
```

There should be **15 rows in FactSales**.

------------------------------------------------------------------------

# 10. Validate the loaded warehouse

Before doing the exercises, run:

``` powershell
docker compose exec db psql -v ON_ERROR_STOP=1 -f /sql/04_validate.sql
```

The validation should pass.

Important expected values:

``` text
FactSales rows: 15
Total units: 43
Total revenue: 56.90 EUR
Calendar dates: 61
Completed purchases: 7
Average basket size: 6.1429
```

Other important checks should also be true:

``` text
All four dimension joins preserve the fact count
All four dimension joins preserve revenue
Every fact row matches all four dimensions
Daily revenue reconciles with monthly revenue
Purchase lines are unique
Unknown customer is retained correctly
```

If these checks pass, the warehouse is ready for the exercises.

------------------------------------------------------------------------

# 11. Exercise A: Revenue by store and month

## Concept

The question is:

> How much revenue did each store generate in each calendar month?

We use:

``` text
FactSales
    |
    +---- DimDate
    |
    +---- DimStore
```

`FactSales` contains the revenue.

`DimDate` tells us the year and month.

`DimStore` tells us the store.

------------------------------------------------------------------------

## Exercise A, Query 1: Monthly revenue

Run:

``` sql
SELECT
    d.CalendarYear,
    d.MonthNumber,
    s.StoreID,
    s.StoreName,
    SUM(f.SalesAmount) AS RevenueEUR
FROM star.FactSales AS f
JOIN star.DimDate AS d
    ON d.DateKey = f.DateKey
JOIN star.DimStore AS s
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
```

Expected result:

``` text
CalendarYear | MonthNumber | StoreID | StoreName        | RevenueEUR
-------------+-------------+---------+------------------+----------
2026         | 9           | 10      | Tallinn Central  | 13.00
2026         | 9           | 20      | Tartu Centre     | 7.40
2026         | 10          | 10      | Tallinn Central  | 18.50
2026         | 10          | 20      | Tartu Centre     | 18.00
```

### What the query does

This part:

``` sql
SUM(f.SalesAmount)
```

adds the sales.

This part:

``` sql
GROUP BY
    d.CalendarYear,
    d.MonthNumber,
    s.StoreID,
    s.StoreName
```

means:

> Give me one row for each store in each month.

------------------------------------------------------------------------

## Exercise A, Query 2: Daily revenue

Run:

``` sql
SELECT
    d.FullDate,
    s.StoreID,
    s.StoreName,
    SUM(f.SalesAmount) AS RevenueEUR
FROM star.FactSales AS f
JOIN star.DimDate AS d
    ON d.DateKey = f.DateKey
JOIN star.DimStore AS s
    ON s.StoreKey = f.StoreKey
GROUP BY
    d.FullDate,
    s.StoreID,
    s.StoreName
ORDER BY
    d.FullDate,
    s.StoreID;
```

Expected result:

``` text
FullDate   | StoreID | StoreName        | RevenueEUR
-----------+---------+------------------+----------
2026-09-30 | 10      | Tallinn Central  | 13.00
2026-09-30 | 20      | Tartu Centre     | 7.40
2026-10-01 | 10      | Tallinn Central  | 12.00
2026-10-01 | 20      | Tartu Centre     | 12.50
2026-10-02 | 10      | Tallinn Central  | 6.50
2026-10-02 | 20      | Tartu Centre     | 5.50
```

### Important concept

The fact table has a detailed grain:

``` text
One row = one purchase line
```

But our query can group those rows at different levels.

For example:

``` text
Purchase line
      ↓
Daily store revenue
      ↓
Monthly store revenue
```

The fact grain stays the same. Only the query grouping changes.

------------------------------------------------------------------------

# 12. Exercise B: Product and category revenue

Exercise B asks:

1.  Which product categories generate the most revenue?
2.  Which 3 products generate the most revenue?

------------------------------------------------------------------------

## Exercise B, Query 1: Revenue by category

Run:

``` sql
SELECT
    p.Category,
    SUM(f.SalesAmount) AS RevenueEUR
FROM star.FactSales AS f
JOIN star.DimProduct AS p
    ON p.ProductKey = f.ProductKey
GROUP BY
    p.Category
ORDER BY
    RevenueEUR DESC;
```

Expected result:

``` text
Category | RevenueEUR
---------+----------
Fruit    | 27.40
Dairy    | 15.00
Bakery   | 14.50
```

### What the query does

We join `FactSales` with `DimProduct`.

`DimProduct` contains:

``` text
ProductID
ProductName
Category
```

Then we group by:

``` sql
p.Category
```

So all sales belonging to the same category are added together.

------------------------------------------------------------------------

# 13. Exercise B, Query 2: Top 3 products

Run:

``` sql
SELECT
    p.ProductID,
    p.ProductName,
    SUM(f.SalesAmount) AS RevenueEUR
FROM star.FactSales AS f
JOIN star.DimProduct AS p
    ON p.ProductKey = f.ProductKey
GROUP BY
    p.ProductID,
    p.ProductName
ORDER BY
    RevenueEUR DESC,
    p.ProductID ASC
LIMIT 3;
```

Expected result:

``` text
ProductID | ProductName | RevenueEUR
----------+-------------+----------
101       | Apple       | 22.50
103       | Milk        | 15.00
104       | Bread       | 14.50
```

### Why `LIMIT 3`?

There are four products:

``` text
Apple
Banana
Milk
Bread
```

We only need the three products with the highest revenue.

This part:

``` sql
ORDER BY RevenueEUR DESC
```

puts the highest revenue first.

Then:

``` sql
LIMIT 3
```

keeps only the first three rows.

------------------------------------------------------------------------

# 14. Results summary

At this point we have completed Exercise A and Exercise B.

## Exercise A

Monthly store revenue:

``` text
2026 September
Tallinn Central: €13.00
Tartu Centre: €7.40

2026 October
Tallinn Central: €18.50
Tartu Centre: €18.00
```

Daily store revenue:

``` text
2026-09-30
Tallinn Central: €13.00
Tartu Centre: €7.40

2026-10-01
Tallinn Central: €12.00
Tartu Centre: €12.50

2026-10-02
Tallinn Central: €6.50
Tartu Centre: €5.50
```

## Exercise B

Category revenue:

``` text
Fruit: €27.40
Dairy: €15.00
Bakery: €14.50
```

Top 3 products by revenue:

``` text
Apple: €22.50
Milk: €15.00
Bread: €14.50
```

------------------------------------------------------------------------

# 15. Quick copy and practice checklist

A partner can follow this exact order:

``` text
1. Open VS Code
2. Open the project folder
3. Create .env
4. Create compose.yml
5. Run docker compose up -d
6. Run docker compose ps
7. Open pgAdmin
8. Connect to localhost:5434
9. Run 01_create_tables.sql
10. Run 02_load_data.sql
11. Run 04_validate.sql
12. Open pgAdmin Query Tool
13. Run Exercise A monthly query
14. Run Exercise A daily query
15. Run Exercise B category query
16. Run Exercise B top 3 products query
```

If all expected results match this README, the setup and Exercises A and
B have been reproduced correctly.

------------------------------------------------------------------------

# 16. Main concepts learned so far

## Star schema

A star schema has one central fact table connected to several dimension
tables.

``` text
                 DimDate
                    |
                    |
DimStore ---- FactSales ---- DimProduct
                    |
                    |
              DimCustomer
```

## Fact table

`FactSales` contains measurable business events.

Examples:

``` text
Quantity
UnitPrice
SalesAmount
```

## Dimension tables

Dimensions describe the facts.

Examples:

``` text
Date
Store
Product
Customer
```

## Fact grain

Our `FactSales` grain is:

> One row represents one purchase line.

For example:

``` text
Purchase 1001
Line 1 = Apple
Line 2 = Milk
```

These are two fact rows.

## Revenue

Revenue is:

``` text
Quantity × UnitPrice
```

For a complete report:

``` sql
SUM(SalesAmount)
```

## Grouping

The same fact table can answer different questions by changing the
grouping.

For example:

``` text
GROUP BY Store, Month
```

gives monthly store revenue.

``` text
GROUP BY Store, Date
```

gives daily store revenue.

``` text
GROUP BY Category
```

gives category revenue.

``` text
GROUP BY Product
```

gives product revenue.

------------------------------------------------------------------------

# 17. Important note

Do not manually change the expected values just to make the result look
correct.

If the result is different, first check:

``` text
1. Is Docker running?
2. Are you connected to the correct database?
3. Are you using schema star?
4. Did 01_create_tables.sql run?
5. Did 02_load_data.sql run?
6. Did 04_validate.sql pass?
7. Did you copy the SQL correctly?
```

The expected warehouse totals are:

``` text
15 fact rows
43 units
€56.90 revenue
7 purchases
61 calendar dates
```

These values are useful for quickly checking whether the setup is
correct.
