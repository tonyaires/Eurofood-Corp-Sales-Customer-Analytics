
/* =====================================================
   SQL ANALYSIS
   =====================================================
   - Data from CSV files was first cleaned and prepared using Python.
   - An initial exploratory analysis and several KPIs were also performed
   in the notebook.
   - This section continues the analysis using SQL in order to manipulate
   tables directly within the database and demonstrate the use of JOINs,
   aggregations, and data segmentation.
*/

/*
   BUSINESS OBJECTIVES:

   - Analyze customer behavior and transaction patterns
   - Evaluate product performance and pricing structure
   - Segment customers based on value and activity level
   - Ensure data quality and consistency

   KEY QUESTIONS:

   - How can customer segmentation be performed using RFM analysis?
   - Which products generate the highest revenue?
   - How can high-margin vs low-margin transactions be identified?
   - How can customer activity be measured and categorized?
*/

CREATE DATABASE eurofood;

USE eurofood;


/* =====================================================
   DATA PREPARATION & VALIDATION
   ===================================================== */
   
   
/* 
   1. How can the sales, customers, and products tables
      be combined to create an enriched dataset containing
      transaction, customer, and product information?
*/
SELECT 
    s.TransactionID,
    s.TransactionDate,
    c.CustomerID,
    c.CustomerName,
    c.CustomerStatus,
    c.Gender,
    p.ProductID,
    p.ProductName,
    p.Category,
    p.Price,
    s.Revenue,
    s.Profit
FROM sales_clean s
INNER JOIN customers_clean c 
    ON s.CustomerID = c.CustomerID
INNER JOIN products_clean p 
    ON s.ProductID = p.ProductID;
    
    
/* 
   2. How can all transactions be checked to detect
      potential sales without an associated customer?
*/
SELECT 
    s.TransactionID,
    s.TransactionDate,
    s.CustomerID,
    c.CustomerName,
    c.CustomerStatus,
    c.Gender,
    s.Revenue,
    s.Profit
FROM sales_clean s
LEFT JOIN customers_clean c
    ON s.CustomerID = c.CustomerID
ORDER BY s.TransactionDate;


/* 
   3. How can the full product inventory be retrieved
      and identify products that have never been sold?
*/
SELECT 
    s.TransactionID,
    s.ProductID,
    p.ProductName,
    p.Category,
    s.Revenue,
    s.Profit
FROM sales_clean s
RIGHT JOIN products_clean p
    ON s.ProductID = p.ProductID
ORDER BY p.Category, p.ProductName;


/* =====================================================
   DESCRIPTIVE ANALYSIS
   ===================================================== */


/*
   4. Which customers have made the highest number
      of transactions?
*/
SELECT 
    c.CustomerID,
    c.CustomerName,
    COUNT(s.TransactionID) AS Total_Transactions
FROM customers_clean c
INNER JOIN sales_clean s
    ON c.CustomerID = s.CustomerID
GROUP BY c.CustomerID, c.CustomerName
ORDER BY Total_Transactions DESC;


/*
   5. What is the date of the first purchase made
      by each customer?
*/
SELECT 
    c.CustomerID,
    c.CustomerName,
    MIN(s.TransactionDate) AS First_Purchase_Date
FROM customers_clean c
INNER JOIN sales_clean s
    ON c.CustomerID = s.CustomerID
GROUP BY c.CustomerID, c.CustomerName
ORDER BY First_Purchase_Date;


/*
   6. What is the average transaction value for each product?
*/
SELECT 
    p.ProductID,
    p.ProductName,
    ROUND(AVG(s.Revenue), 2) AS Avg_Revenue
FROM products_clean p
INNER JOIN sales_clean s
    ON p.ProductID = s.ProductID
GROUP BY p.ProductID, p.ProductName
ORDER BY Avg_Revenue DESC;


/*
   7. What are the top 3 best-selling products in each category?
*/
WITH ProductRevenue AS (
    SELECT 
        p.Category,
        p.ProductName,
        ROUND(SUM(s.Revenue), 2) AS TotalRevenue  
    FROM sales_clean s
    INNER JOIN products_clean p
        ON s.ProductID = p.ProductID
    GROUP BY p.Category, p.ProductName
)
SELECT *
FROM (
    SELECT 
        Category,
        ProductName,
        TotalRevenue,
        ROW_NUMBER() OVER (PARTITION BY Category ORDER BY TotalRevenue DESC) AS RankByCategory
    FROM ProductRevenue
) AS Ranked
WHERE RankByCategory <= 3
ORDER BY Category, RankByCategory;


/*
   8. Which customers have made more than 10 transactions and can be
      considered frequent customers?
*/
SELECT 
    c.CustomerID,
    c.CustomerName,
    COUNT(s.TransactionID) AS Total_Transactions
FROM customers_clean c
INNER JOIN sales_clean s
    ON c.CustomerID = s.CustomerID
GROUP BY c.CustomerID, c.CustomerName
HAVING COUNT(s.TransactionID) > 10
ORDER BY Total_Transactions DESC;


/* =====================================================
   ADVANCED ANALYSIS & SEGMENTATION
   ===================================================== */
   
   
/*
   9. How can transactions be segmented into low, medium, and high
      revenue value?
*/
SELECT 
    TransactionID,
    CustomerID,
    ProductID,
    Revenue,
    CASE
        WHEN Revenue < 50 THEN 'Low Revenue'
        WHEN Revenue BETWEEN 50 AND 200 THEN 'Medium Revenue'
        ELSE 'High Revenue'
    END AS Revenue_Segment
FROM sales_clean
ORDER BY Revenue DESC;


/*
   10. How can high-margin and low-margin transactions be identified?
*/
SELECT 
    TransactionID,
    ROUND(Revenue, 2) AS Revenue,
    ROUND(Profit, 2) AS Profit,
    ROUND((Revenue - Profit), 2) AS Cost,
    ROUND((Profit / Revenue) * 100, 2) AS MarginPercent,
    CASE
        WHEN Profit > 0 THEN 'Profitable'
        ELSE 'Low or Negative Margin'
    END AS Profitability_Status
FROM sales_clean;


/*
   11. How can customers be segmented based on their activity level
       (occasional, regular, frequent) according to the number of
       transactions?
*/
SELECT 
    CustomerID,
    COUNT(TransactionID) AS Total_Transactions,
    CASE
        WHEN COUNT(TransactionID) >= 10 THEN 'Frequent Customer'
        WHEN COUNT(TransactionID) BETWEEN 5 AND 9 THEN 'Regular Customer'
        ELSE 'Occasional Customer'
    END AS Customer_Segment
FROM sales_clean
GROUP BY CustomerID;


/*
   12. How can products be categorized based on their price level
       (low, mid-range, premium)?
*/
SELECT 
    ProductName,
    Price,
    CASE
        WHEN Price < 5 THEN 'Low Price'
        WHEN Price BETWEEN 5 AND 10 THEN 'Medium Price'
        ELSE 'Premium Product'
    END AS Price_Category
FROM products_clean;


/*
   13. How can cumulative revenue be calculated by month and by
       CustomerStatus to analyze sales trends?
*/
SELECT
    DATE_FORMAT(s.TransactionDate, '%Y-%m') AS Month,
    c.CustomerStatus,
    ROUND(SUM(s.Revenue), 2) AS MonthlyRevenue,
    ROUND(
        SUM(SUM(s.Revenue)) OVER (
            PARTITION BY c.CustomerStatus 
            ORDER BY DATE_FORMAT(s.TransactionDate, '%Y-%m')
        ), 2
    ) AS CumulativeRevenue
FROM sales_clean s
LEFT JOIN customers_clean c
    ON s.CustomerID = c.CustomerID
GROUP BY Month, c.CustomerStatus
ORDER BY Month, CustomerStatus;


/*
   14. How can customers who purchased the same product be identified
       in order to detect similar buying behaviors?
*/
SELECT 
    a.CustomerID AS CustomerA,
    b.CustomerID AS CustomerB,
    COUNT(*) AS CommonProducts
FROM sales_clean a
JOIN sales_clean b
    ON a.ProductID = b.ProductID AND a.CustomerID < b.CustomerID
GROUP BY CustomerA, CustomerB
HAVING COUNT(*) > 0
ORDER BY CommonProducts DESC
LIMIT 50;


/*
   15. How can customers be segmented using an RFM analysis
       (Recency, Frequency, Monetary)?
*/
WITH RFM AS (
    SELECT 
        CustomerID,
        DATEDIFF(CURDATE(), MAX(TransactionDate)) AS Recency,
        COUNT(TransactionID) AS Frequency,
        ROUND(SUM(Revenue), 2) AS Monetary
    FROM sales_clean
    GROUP BY CustomerID
)

SELECT *
FROM RFM
ORDER BY Monetary DESC;


/*
   16. How can top customers, loyal customers, and at-risk customers
       be identified?
*/
WITH RFM AS (
    SELECT 
        CustomerID,
        DATEDIFF(CURDATE(), MAX(TransactionDate)) AS Recency,
        COUNT(TransactionID) AS Frequency,
        ROUND(SUM(Revenue), 2) AS Monetary
    FROM sales_clean
    GROUP BY CustomerID
),

RFM_Score AS (
    SELECT 
        CustomerID,
        Recency,
        Frequency,
        Monetary,
        NTILE(5) OVER (ORDER BY Recency ASC) AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency DESC) AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary DESC) AS M_Score
    FROM RFM
)

SELECT 
    CustomerID,
    Recency,
    Frequency,
    Monetary,
    R_Score,
    F_Score,
    M_Score,
    CASE
        WHEN R_Score = 5 AND F_Score = 5 AND M_Score = 5 THEN 'Best Customers'
        WHEN R_Score >= 4 AND F_Score >= 4 THEN 'Loyal Customers'
        WHEN R_Score <= 2 AND F_Score <= 2 THEN 'At Risk'
        ELSE 'Potential Customers'
    END AS Customer_Segment
FROM RFM_Score
ORDER BY Customer_Segment, Monetary DESC;


/* =====================================================
   Key Business Insights
   =====================================================

   The SQL analysis shows that:

   - Members are the most active customers and generate higher revenue.
   - The best-performing products have been identified by category,
     with revenue heavily concentrated on a limited number of products.
   - Similar purchasing behaviors between customers have been detected,
     opening opportunities for recommendation strategies.

   - The RFM analysis enables advanced customer segmentation:
       * "Best Customers" generate a significant share of revenue and
         should be prioritized for retention.
       * "Loyal Customers" represent a strong base that should be
         maintained through loyalty programs.
       * "At Risk" customers require targeted marketing actions to
         prevent churn.

   These results confirm and extend the insights from the Python EDA,
   adding a stronger business decision-making perspective.

   These insights support data-driven decision making, particularly for
   customer retention, marketing targeting, and revenue optimization strategies.
*/
