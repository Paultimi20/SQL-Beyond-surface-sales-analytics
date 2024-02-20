-- Explore product lines
-- SELECT * FROM productlines;

-- select min(orderDate) from orders;


-- QUESTION 1A: Monthly Sales
WITH MonthlySales AS (
    SELECT
        DATE_FORMAT(o.orderDate, '%Y-%m') AS month_yr,
		YEAR(o.orderDate) AS years,
        MONTH(o.orderDate) AS months,
        SUM(od.priceEach * od.quantityOrdered) AS monthly_sales
    FROM
        orders o
    JOIN
        orderdetails od ON o.orderNumber = od.orderNumber
    GROUP BY
        years, months
    ORDER BY
        years, months
),

QuarterlyMovingAverage AS (
    SELECT
        month_yr,
        years, months,
        monthly_sales,
        ROUND(AVG(monthly_sales) OVER (ORDER BY month_yr ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2) AS quarterly_moving_avg
	FROM
        MonthlySales
)

SELECT
    month_yr,
    -- years, months
    monthly_sales,
    quarterly_moving_avg,
    SUM(monthly_sales) OVER (PARTITION BY years ORDER BY years, months) AS running_total_per_year
FROM
    QuarterlyMovingAverage
ORDER BY years, months;



SELECT
    DATE_FORMAT(orderDate, '%Y') AS year,
    DATE_FORMAT(orderDate, '%m') AS month,
    SUM(priceEach * quantityOrdered) AS monthly_sales,
    SUM(SUM(priceEach * quantityOrdered)) OVER (PARTITION BY DATE_FORMAT(orderDate, '%Y') ORDER BY DATE_FORMAT(orderDate, '%m')) AS running_total
FROM
    orderdetails od
JOIN orders o ON od.orderNumber = o.orderNumber
GROUP BY
    year, month
ORDER BY
    year, month;



-- QUESTION 1B: MOM revenue performance by product line
-- Step 1: Create a Common Table Expression (CTE) that calculates the monthly sales for each product line.
WITH MonthlyProductSales AS (
    SELECT
        pl.productLine AS product_line,
        EXTRACT(YEAR_MONTH FROM o.orderDate) AS order_month,
        SUM(od.quantityOrdered * od.priceEach) AS monthly_sales
    FROM
        products p
    JOIN
        orderdetails od ON p.productCode = od.productCode
    JOIN
        orders o ON od.orderNumber = o.orderNumber
    JOIN
        productlines pl ON p.productLine = pl.productLine
    GROUP BY
        product_line, order_month
),

-- Step 2: Create another CTE that calculates the previous month's sales for each product line.
PreviousMonthSales AS (
    SELECT
        product_line,
        order_month,
        LAG(monthly_sales) OVER (PARTITION BY product_line ORDER BY order_month) AS previous_month_sales
    FROM
        MonthlyProductSales
),

-- Step 3: Calculate the month-over-month sales growth for each product line.
SalesGrowth AS (
    SELECT
        mps.product_line,
        mps.order_month,
        pms.previous_month_sales,
        mps.monthly_sales,
        COALESCE(
            (mps.monthly_sales - pms.previous_month_sales) / pms.previous_month_sales,
            0
        ) AS month_over_month_growth
    FROM
        MonthlyProductSales mps
    LEFT JOIN
        PreviousMonthSales pms ON mps.product_line = pms.product_line
        AND mps.order_month = pms.order_month
)

-- Step 4: Retrieve the results with product lines and their month-over-month sales growth.
SELECT
    product_line,
    order_month,
    monthly_sales,
    previous_month_sales,
    month_over_month_growth
FROM
    SalesGrowth
ORDER BY
    product_line, order_month;


-- QUESTION 2: TOTAL SALES, PERCENTAGE OF SALES AND QUANTITY ORDERD FOR EACH PRODUCT LINE
-- Step 1: Start the SQL query with a Common Table Expression (CTE) to calculate total sales revenue for each product line.
WITH ProductSales AS (
    SELECT
        pl.productLine AS Product_Line,
       SUM(od.quantityOrdered * od.priceEach) AS Total_Sales_Revenue,
       SUM(od.quantityOrdered) AS quantityOrdered
    FROM
        productlines pl
    JOIN
        products p ON pl.productLine = p.productLine
    JOIN
        orderdetails od ON p.productCode = od.productCode
    GROUP BY
        pl.productLine
)

-- Step 2: Write the main SQL query to rank product lines by total sales revenue.
SELECT
    Product_Line,
    -- RANK() OVER (ORDER BY Total_Sales_Revenue DESC) AS Sales_Rank,
    Total_Sales_Revenue,
    ROUND(Total_Sales_Revenue/(SELECT SUM(Total_Sales_Revenue) FROM ProductSales)*100,2) AS Percentage_total,
    quantityOrdered
    
FROM
    ProductSales
ORDER BY 2 DESC;



-- QUESTION 3A: Average order values
-- Step1: Select the product line, and calculate the average order value for each product line.
-- We use a common table expression (CTE) to calculate the total order value for each product line first.
WITH ProductLineOrderTotal AS (
    SELECT
        p.productLine,
        o.orderNumber,
        SUM(od.quantityOrdered * od.priceEach) AS totalOrderValue
    FROM
        products p
    JOIN
        orderdetails od ON p.productCode = od.productCode
    JOIN
        orders o ON od.orderNumber = o.orderNumber
    GROUP BY
        p.productLine, o.orderNumber
)

-- Step2: Calculate the average order value for each product line by averaging the total order values.
-- AverageOrderValue AS (
    SELECT
        productLine,
        round(AVG(totalOrderValue),2) AS 'Average Order Value'
    FROM
        ProductLineOrderTotal
    GROUP BY
        productLine
ORDER BY 2 DESC;


-- QUESTION 3B: TOP AND LEAST 3 PERFORMING PRODUCT BY PRODUCT LINE
WITH ProductRevenueRank AS (
    SELECT
        p.productLine,
        p.productName,
        SUM(od.quantityOrdered * od.priceEach) AS totalRevenue,
        RANK() OVER (PARTITION BY p.productLine ORDER BY SUM(od.quantityOrdered * od.priceEach) DESC) AS revenueRank,
        RANK() OVER (PARTITION BY p.productLine ORDER BY SUM(od.quantityOrdered * od.priceEach)) AS reverseRevenueRank
    FROM
        products p
    JOIN
        orderdetails od ON p.productCode = od.productCode
    GROUP BY
        p.productLine, p.productName
),

topSales AS(
SELECT
	ROW_NUMBER() OVER () as row_id,
    productLine,
    productName,
    totalRevenue
FROM
    ProductRevenueRank
WHERE
    revenueRank <= 3
ORDER BY
    productLine, revenueRank
    ),

bottomSales AS(
SELECT
	ROW_NUMBER() OVER () as row_id,
    productLine,
    productName,
    totalRevenue
FROM
    ProductRevenueRank
WHERE
    reverseRevenueRank <= 3
ORDER BY
    productLine, revenueRank
    )
    
SELECT 
t.productLine,
t.productName AS top_3_product,
t.totalRevenue AS Revenue,
b.productName AS bottom_3_Product,
b.totalRevenue AS Revenue_
FROM topSales t
JOIN bottomSales b ON t.row_id = b.row_id;


-- QUESTION 4: Sales by region
SELECT
	c.country,
	-- coalesce(c.state, c.country) Region,
	Sum(od.quantityOrdered * od.priceEach) AS Revenue,
    Sum(od.quantityOrdered) AS quantityOrdered
FROM orderdetails od
JOIN orders o on o.orderNumber = od.orderNumber
JOIN customers c on c.customerNumber = o.customerNumber
GROUP BY 1
ORDER BY 3 Desc;


