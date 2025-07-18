use StoreDB;
GO

-----------------------------------------

select *,
case
	when list_price < 300 then 'Economy'
	when list_price between 300 and 999 then 'Standard'
	when list_price between 1000 and 2499 then 'Premium'
	when list_price >= 2500 then 'Luxury'
end as price_category
from production.products;

-----------------------------------------

select *,
case order_status
	when 1 then 'Order Received'
	when 2 then 'In Preparation'
	when 3 then 'Order Cancelled'
	when 4 then 'Order Cancelled'
end as status_description,
case
	when order_status = 1 and DATEDIFF(day, order_date, GETDATE()) > 5 then 'URGENT'
	when order_status = 2 and DATEDIFF(day, order_date, GETDATE()) > 3 then 'HIGH'
	else 'NORMAL'
end as priority_level
from sales.orders;

--------------------------------------------

select s.staff_id, s.first_name, s.last_name, count(o.order_id) as total_orders,
case
	when count(o.order_id) = 0 then 'New Staff'
	when count(o.order_id) between 1 and 10 then 'Junior Staff'
	when count(o.order_id) between 11 and 25 then 'Senior Staff'
	else 'Expert Staff'
end as staff_level
from sales.staffs s
left join sales.orders o on s.staff_id = o.staff_id
group by s.staff_id, s.first_name, s.last_name;

-------------------------------------------

select customer_id, first_name, last_name,
	   isnull(phone, 'Phone Not Available'),
	   email,
	   COALESCE(phone, email, 'No Contact Method') as preferred_contact,
	   street, city, state, zip_code
from sales.customers;

--------------------------------------------

select p.product_id, p.product_name, p.list_price,
	   ISNULL(s.quantity, 0) AS quantity,
       ISNULL(p.list_price / NULLIF(s.quantity, 0), 0) AS price_per_unit,
       CASE
		  WHEN s.quantity IS NULL OR s.quantity = 0 THEN 'Out of Stock'
		  WHEN s.quantity < 10 THEN 'Low Stock'
		  ELSE 'In Stock'
      END AS stock_status
FROM production.products p
LEFT JOIN production.stocks s ON p.product_id = s.product_id AND s.store_id = 1
WHERE ISNULL(s.store_id, 1) = 1;

------------------------------------------------

SELECT customer_id,
  COALESCE(street, '') + ' ' +
  COALESCE(city, '') + ', ' +
  COALESCE(state, '') + ' ' +
  COALESCE(zip_code, 'No ZIP') AS formatted_address
FROM sales.customers;

---------------------------------------------------

WITH customer_spending AS (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        SUM(oi.quantity * oi.list_price) AS total_spent
    FROM sales.customers c
    JOIN sales.orders o ON c.customer_id = o.customer_id
    JOIN sales.order_items oi ON o.order_id = oi.order_id
    GROUP BY c.customer_id, c.first_name, c.last_name
)
SELECT *
FROM customer_spending
WHERE total_spent > 1500
ORDER BY total_spent DESC;

-------------------------------------------------

WITH category_revenue AS (
    SELECT 
        p.category_id,
        SUM(oi.quantity * oi.list_price) AS total_revenue
    FROM sales.order_items oi
    JOIN production.products p ON oi.product_id = p.product_id
    JOIN sales.orders o ON oi.order_id = o.order_id
    GROUP BY p.category_id
),

category_avg_order AS (
    SELECT 
        p.category_id,
        AVG(oi.quantity * oi.list_price) AS avg_order_value
    FROM sales.order_items oi
    JOIN production.products p ON oi.product_id = p.product_id
    JOIN sales.orders o ON oi.order_id = o.order_id
    GROUP BY p.category_id
)

SELECT 
    cr.category_id,
    cr.total_revenue,
    ca.avg_order_value,
    CASE 
        WHEN cr.total_revenue > 50000 THEN 'Excellent'
        WHEN cr.total_revenue > 20000 THEN 'Good'
        ELSE 'Needs Improvement'
    END AS performance_rating
FROM category_revenue cr
JOIN category_avg_order ca ON cr.category_id = ca.category_id
ORDER BY cr.total_revenue DESC;

------------------------------------------------

WITH MonthlySales AS (
    SELECT 
        YEAR(O.Order_Date) AS Sales_Year,
        MONTH(O.Order_Date) AS Sales_Month,
        SUM(OI.Quantity * OI.list_price) AS Monthly_Total
    FROM sales.orders O
    JOIN sales.order_items OI ON O.Order_ID = OI.Order_ID
    GROUP BY YEAR(O.Order_Date), MONTH(O.Order_Date)
),
WithPreviousMonth AS (
    SELECT 
        Sales_Year,
        Sales_Month,
        Monthly_Total,
        LAG(Monthly_Total) OVER (ORDER BY Sales_Year, Sales_Month) AS Previous_Month_Total
    FROM MonthlySales
)
SELECT 
    Sales_Year,
    Sales_Month,
    Monthly_Total,
    Previous_Month_Total,
    CASE 
        WHEN Previous_Month_Total IS NULL THEN NULL
        ELSE ROUND((Monthly_Total - Previous_Month_Total) * 100.0 / Previous_Month_Total, 2)
    END AS Growth_Percentage
FROM WithPreviousMonth;

------------------------------------------------
SELECT *
FROM (
    SELECT 
        Category_ID,
        Product_Name,
        List_Price,
        ROW_NUMBER() OVER (PARTITION BY Category_ID ORDER BY List_Price DESC) AS Rn,
        RANK() OVER (PARTITION BY Category_ID ORDER BY List_Price DESC) AS Rnk,
        DENSE_RANK() OVER (PARTITION BY Category_ID ORDER BY List_Price DESC) AS DenseRnk
    FROM production.products
) AS Ranked
WHERE Rn <= 3;

----------------------------------------------

WITH CustomerSpending AS (
    SELECT 
        C.Customer_ID,
        C.First_Name,
        C.Last_Name,
        SUM(OI.Quantity * OI.list_price) AS Total_Spent
    FROM sales.customers C
    JOIN sales.orders O ON C.Customer_ID = O.Customer_ID
    JOIN sales.order_items OI ON O.Order_ID = OI.Order_ID
    GROUP BY C.Customer_ID, C.First_Name, C.Last_Name
)
SELECT 
    *,
    RANK() OVER (ORDER BY Total_Spent DESC) AS Spending_Rank,
    NTILE(5) OVER (ORDER BY Total_Spent DESC) AS Spending_Group,
    CASE NTILE(5) OVER (ORDER BY Total_Spent DESC)
        WHEN 1 THEN 'VIP'
        WHEN 2 THEN 'Gold'
        WHEN 3 THEN 'Silver'
        WHEN 4 THEN 'Bronze'
        ELSE 'Standard'
    END AS Spending_Tier
FROM CustomerSpending;

-----------------------------------------

WITH StorePerformance AS (
    SELECT 
        S.Store_ID,
        S.Store_Name,
        COUNT(DISTINCT O.Order_ID) AS Order_Count,
        SUM(OI.Quantity * OI.list_price) AS Total_Revenue
    FROM sales.stores S
    LEFT JOIN sales.orders O ON S.Store_ID = O.Store_ID
    LEFT JOIN sales.order_items OI ON O.Order_ID = OI.Order_ID
    GROUP BY S.Store_ID, S.Store_Name
)
SELECT 
    Store_Name,
    Total_Revenue,
    Order_Count,
    RANK() OVER (ORDER BY Total_Revenue DESC) AS Revenue_Rank,
    RANK() OVER (ORDER BY Order_Count DESC) AS Order_Rank,
    PERCENT_RANK() OVER (ORDER BY Total_Revenue) AS Revenue_Percentile
FROM StorePerformance;

---------------------------------------------

SELECT *
FROM (
    SELECT 
        c.category_name,
        b.brand_name
    FROM production.products p
    JOIN production.categories c ON p.category_id = c.category_id
    JOIN production.brands b ON p.brand_id = b.brand_id
    WHERE b.brand_name IN ('Electra', 'Haro', 'Trek', 'Surly')
) AS SourceTable
PIVOT (
    COUNT(brand_name) FOR brand_name IN ([Electra], [Haro], [Trek], [Surly])
) AS PivotTable;

---------------------------------------------

SELECT *
FROM (
    SELECT 
        s.store_name,
        MONTH(o.order_date) AS order_month,
        oi.quantity * oi.list_price AS revenue
    FROM sales.orders o
    JOIN sales.stores s ON o.store_id = s.store_id
    JOIN sales.order_items oi ON o.order_id = oi.order_id
) AS source
PIVOT (
    SUM(revenue) FOR order_month IN (
        [1], [2], [3], [4], [5], [6], 
        [7], [8], [9], [10], [11], [12]
    )
) AS pivot_result;

--------------------------------------------------

SELECT *
FROM (
    SELECT 
        S.Store_Name,
        CASE O.order_status
            WHEN 1 THEN 'Pending'
            WHEN 2 THEN 'Processing'
            WHEN 3 THEN 'Completed'
            WHEN 4 THEN 'Rejected'
        END AS StatusLabel
    FROM sales.orders O
    JOIN sales.stores S ON O.Store_ID = S.Store_ID
) AS SourceTable
PIVOT (
    COUNT(StatusLabel) FOR StatusLabel IN ([Pending], [Processing], [Completed], [Rejected])
) AS PivotTable;

--------------------------------------------

WITH YearlySales AS (
    SELECT 
        B.brand_name,
        YEAR(O.order_date) AS Sale_Year,
        SUM(OI.quantity * OI.list_price) AS Revenue
    FROM sales.order_items OI
    JOIN sales.orders O ON OI.order_id = O.order_id
    JOIN production.products P ON OI.product_id = P.product_id
    JOIN production.brands B ON P.brand_id = B.brand_id
    GROUP BY B.brand_name, YEAR(O.order_date)
)
SELECT 
    brand_name,
    ISNULL([2016], 0) AS [2016],
    ISNULL([2017], 0) AS [2017],
    ISNULL([2018], 0) AS [2018],
    CASE 
        WHEN ISNULL([2016], 0) = 0 THEN NULL
        ELSE ROUND(((ISNULL([2017], 0) - ISNULL([2016], 0)) * 100.0 / ISNULL([2016], 0)), 2)
    END AS Growth_2016_2017,
    CASE 
        WHEN ISNULL([2017], 0) = 0 THEN NULL
        ELSE ROUND(((ISNULL([2018], 0) - ISNULL([2017], 0)) * 100.0 / ISNULL([2017], 0)), 2)
    END AS Growth_2017_2018
FROM YearlySales
PIVOT (
    SUM(Revenue) FOR Sale_Year IN ([2016], [2017], [2018])
) AS PivotTable;

-----------------------------------------------------------

SELECT 
    P.Product_ID,
    P.Product_Name,
    'In Stock' AS Availability_Status
FROM Production.Products P
JOIN Production.Stocks S ON P.Product_ID = S.Product_ID
WHERE S.Quantity > 0

UNION

SELECT 
    P.Product_ID,
    P.Product_Name,
    'Out of Stock' AS Availability_Status
FROM Production.Products P
JOIN Production.Stocks S ON P.Product_ID = S.Product_ID
WHERE ISNULL(S.Quantity, 0) = 0

UNION


SELECT 
    P.Product_ID,
    P.Product_Name,
    'Discontinued' AS Availability_Status
FROM Production.Products P
WHERE NOT EXISTS (
    SELECT 1 FROM Production.Stocks S WHERE S.Product_ID = P.Product_ID
);

----------------------------------------------------

SELECT DISTINCT Customer_ID
FROM sales.orders
WHERE YEAR(Order_Date) = 2017

INTERSECT

SELECT DISTINCT Customer_ID
FROM sales.orders
WHERE YEAR(Order_Date) = 2018;

----------------------------------------------------

SELECT Product_ID
FROM Production.Stocks
WHERE Store_ID = 1

INTERSECT

SELECT Product_ID
FROM Production.Stocks
WHERE Store_ID = 2

INTERSECT

SELECT Product_ID
FROM Production.Stocks
WHERE Store_ID = 3

UNION

SELECT Product_ID
FROM Production.Stocks
WHERE Store_ID = 1

EXCEPT

SELECT Product_ID
FROM Production.Stocks
WHERE Store_ID = 2;

---------------------------------------------------

SELECT C.Customer_ID, C.First_Name, C.Last_Name, 'Lost' AS Status
FROM sales.customers C
WHERE C.Customer_ID IN (
    SELECT Customer_ID FROM sales.orders WHERE YEAR(Order_Date) = 2016
)
AND C.Customer_ID NOT IN (
    SELECT Customer_ID FROM sales.orders WHERE YEAR(Order_Date) = 2017
)

UNION ALL

SELECT C.Customer_ID, C.First_Name, C.Last_Name, 'New' AS Status
FROM sales.customers C
WHERE C.Customer_ID IN (
    SELECT Customer_ID FROM sales.orders WHERE YEAR(Order_Date) = 2017
)
AND C.Customer_ID NOT IN (
    SELECT Customer_ID FROM sales.orders WHERE YEAR(Order_Date) = 2016
)

UNION ALL

SELECT C.Customer_ID, C.First_Name, C.Last_Name, 'Retained' AS Status
FROM sales.customers C
WHERE C.Customer_ID IN (
    SELECT Customer_ID FROM sales.orders WHERE YEAR(Order_Date) = 2016
)
AND C.Customer_ID IN (
    SELECT Customer_ID FROM sales.orders WHERE YEAR(Order_Date) = 2017
);
