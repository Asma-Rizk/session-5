SELECT product_name,
       list_price,
       CASE
       WHEN list_price <300 THEN 'Economy'
       WHEN list_price BETWEEN 300 AND 900 THEN 'Standard'
       WHEN list_price BETWEEN 1000 AND 2499 THEN 'Premium'
       ELSE 'Luxury'
       END AS price_category
       FROM production.products
       SELECT TOP 1 * FROM sales.orders;

SELECT 
    order_id,
    order_date,
     order_status,
    CASE
       WHEN order_status =1 THEN 'Order Received'
       WHEN  order_status =2 THEN  'In Preparation'
       WHEN  order_status =3 THEN 'Cancelled'
       WHEN  order_status =4 THEN 'Order Delivered'
    END AS status_description,
  
  CASE 
    WHEN  order_status = 1 AND DATEDIFF(DAY, order_date, GETDATE()) > 5 THEN 'URGENT'
    WHEN  order_status = 2 AND DATEDIFF(DAY, order_date, GETDATE()) > 3 THEN 'HIGH'
    ELSE 'NORMAL'
  END AS priority
FROM sales.orders;

SELECT 
  s.staff_id,
  s.first_name + ' ' + s.last_name AS full_name,
  COUNT(o.order_id) AS total_orders,
  CASE
    WHEN COUNT(o.order_id) = 0 THEN 'New Staff'
    WHEN COUNT(o.order_id) BETWEEN 1 AND 10 THEN 'Junior Staff'
    WHEN COUNT(o.order_id) BETWEEN 11 AND 25 THEN 'Senior Staff'
    ELSE 'Expert Staff'
  END AS staff_level
FROM sales.staffs s
LEFT JOIN sales.orders o ON s.staff_id = o.staff_id
GROUP BY s.staff_id, s.first_name, s.last_name
ORDER BY total_orders DESC;

SELECT 
  customer_id,
  first_name+ ' '+last_name AS customer_name,
  ISNULL(phone,'Phone Not Available')AS phone,
  COALESCE(phone,email,'No Contact Method')AS preferred_contact,
  email,
  city,
  state
FROM sales.customers;

SELECT 
  customer_id,
  first_name + ' ' + last_name AS full_name,
  COALESCE(street, 'No Street') AS street,
  COALESCE(city, 'No City') AS city,
  COALESCE(state, 'No State') AS state,
  COALESCE(zip_code, 'No ZIP') AS zip_code,
  COALESCE(street, '') + ', ' +
  COALESCE(city, '') + ', ' +
  COALESCE(state, '') + ' ' +
  COALESCE(zip_code, '') AS formatted_address
FROM sales.customers
ORDER BY customer_id;

WITH CustomerSpending AS (
  SELECT 
    o.customer_id,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spent
  FROM sales.orders o
  JOIN sales.order_items oi ON o.order_id = oi.order_id
  GROUP BY o.customer_id
)
SELECT 
  c.customer_id,
  c.first_name + ' ' + c.last_name AS full_name,
  cs.total_spent
FROM CustomerSpending cs
JOIN sales.customers c ON cs.customer_id = c.customer_id
WHERE cs.total_spent > 1500
ORDER BY cs.total_spent DESC;

WITH RevenuePerCategory AS (
  SELECT c.category_id, c.category_name,
         SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue
  FROM production.categories c
  JOIN production.products p ON c.category_id = p.category_id
  JOIN sales.order_items oi ON p.product_id = oi.product_id
  GROUP BY c.category_id, c.category_name
),
AvgOrderValue AS (
  SELECT c.category_id,
         AVG(oi.list_price * oi.quantity) AS avg_order_value
  FROM production.categories c
  JOIN production.products p ON c.category_id = p.category_id
  JOIN sales.order_items oi ON p.product_id = oi.product_id
  GROUP BY c.category_id
  )
SELECT r.category_name, r.total_revenue, a.avg_order_value,
       CASE
         WHEN r.total_revenue > 50000 THEN 'Excellent'
         WHEN r.total_revenue > 20000 THEN 'Good'
         ELSE 'Needs Improvement'
       END AS performance
FROM RevenuePerCategory r
JOIN AvgOrderValue a ON r.category_id = a.category_id;

SELECT 
  p.category_id,
  c.category_name,
  p.product_name,
  p.list_price,
  ROW_NUMBER() OVER (PARTITION BY p.category_id ORDER BY p.list_price DESC) AS row_num,
  RANK() OVER (PARTITION BY p.category_id ORDER BY p.list_price DESC) AS rank,
  DENSE_RANK() OVER (PARTITION BY p.category_id ORDER BY p.list_price DESC) AS dense_rank
FROM production.products p
JOIN production.categories c ON p.category_id = c.category_id
WHERE p.list_price IS NOT NULL;

WITH CustomerTotals AS (
  SELECT 
    o.customer_id,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spent
  FROM sales.orders o
  JOIN sales.order_items oi ON o.order_id = oi.order_id
  GROUP BY o.customer_id
)
WITH CustomerTotals AS (
  SELECT 
    o.customer_id,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spent
  FROM sales.orders o
  JOIN sales.order_items oi ON o.order_id = oi.order_id
  GROUP BY o.customer_id
),
RankedCustomers AS (
  SELECT
    c.customer_id,
    c.first_name + ' ' + c.last_name AS full_name,
    ct.total_spent,
    RANK() OVER (ORDER BY ct.total_spent DESC) AS spending_rank,
    NTILE(5) OVER (ORDER BY ct.total_spent DESC) AS spending_group
  FROM CustomerTotals ct
  JOIN sales.customers c ON c.customer_id = ct.customer_id
)
SELECT *,
  CASE 
    WHEN spending_group = 1 THEN 'VIP'
    WHEN spending_group = 2 THEN 'Gold'
    WHEN spending_group = 3 THEN 'Silver'
    WHEN spending_group = 4 THEN 'Bronze'
    ELSE 'Standard'
  END AS tier
FROM RankedCustomers
ORDER BY total_spent DESC;


WITH StorePerformance AS (
  SELECT 
    s.store_id,
    s.store_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue
  FROM sales.stores s
  LEFT JOIN sales.orders o ON s.store_id = o.store_id
  LEFT JOIN sales.order_items oi ON o.order_id = oi.order_id
  GROUP BY s.store_id, s.store_name
)
SELECT 
  store_id,
  store_name,
  total_orders,
  total_revenue,
  RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
  RANK() OVER (ORDER BY total_orders DESC) AS order_count_rank,
  PERCENT_RANK() OVER (ORDER BY total_revenue DESC) AS revenue_percent_rank
FROM StorePerformance
ORDER BY total_revenue DESC;



SELECT 
  c.category_name,
  b.brand_name
INTO #ProductData
FROM production.products p
JOIN production.categories c ON p.category_id = c.category_id
JOIN production.brands b ON p.brand_id = b.brand_id
WHERE b.brand_name IN ('Electra', 'Haro', 'Trek', 'Surly');

SELECT 
  category_name,
  ISNULL([Electra], 0) AS Electra,
  ISNULL([Haro], 0) AS Haro,
  ISNULL([Trek], 0) AS Trek,
  ISNULL([Surly], 0) AS Surly
FROM (
  SELECT category_name, brand_name
  FROM #ProductData
) AS SourceTable
PIVOT (
  COUNT(brand_name)
  FOR brand_name IN ([Electra], [Haro], [Trek], [Surly])
) AS PivotTable;
DROP TABLE #ProductData;


SELECT
  s.store_name,
  MONTH(o.order_date) AS order_month,
  ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS monthly_revenue
INTO #MonthlySales
FROM sales.orders o
JOIN sales.order_items oi ON o.order_id = oi.order_id
JOIN sales.stores s ON o.store_id = s.store_id
GROUP BY s.store_name, MONTH(o.order_date);
SELECT 
  store_name,
  ISNULL([1], 0) AS Jan,
  ISNULL([2], 0) AS Feb,
  ISNULL([3], 0) AS Mar,
  ISNULL([4], 0) AS Apr,
  ISNULL([5], 0) AS May,
  ISNULL([6], 0) AS Jun,
  ISNULL([7], 0) AS Jul,
  ISNULL([8], 0) AS Aug,
  ISNULL([9], 0) AS Sep,
  ISNULL([10], 0) AS Oct,
  ISNULL([11], 0) AS Nov,
  ISNULL([12], 0) AS Dec,
  ISNULL([1], 0) + ISNULL([2], 0) + ISNULL([3], 0) + ISNULL([4], 0) +
  ISNULL([5], 0) + ISNULL([6], 0) + ISNULL([7], 0) + ISNULL([8], 0) +
  ISNULL([9], 0) + ISNULL([10], 0) + ISNULL([11], 0) + ISNULL([12], 0)
  AS total_revenue
FROM (
  SELECT store_name, order_month, monthly_revenue
  FROM #MonthlySales
) AS SourceTable
PIVOT (
  SUM(monthly_revenue)
  FOR order_month IN ([1], [2], [3], [4], [5], [6], [7], [8], [9], [10], [11], [12])
) AS PivotTable;
DROP TABLE #MonthlySales;

SELECT 
  s.store_name,
  CASE 
    WHEN o.order_status = 1 THEN 'Pending'
    WHEN o.order_status = 2 THEN 'Processing'
    WHEN o.order_status = 3 THEN 'Rejected'
    WHEN o.order_status = 4 THEN 'Completed'
    ELSE 'Unknown'
  END AS status_text
INTO #OrderStatusByStore
FROM sales.orders o
JOIN sales.stores s ON o.store_id = s.store_id;

SELECT 
  store_name,
  ISNULL(Pending, 0) AS Pending,
  ISNULL(Processing, 0) AS Processing,
  ISNULL(Completed, 0) AS Completed,
  ISNULL(Rejected, 0) AS Rejected
FROM (
  SELECT store_name, status_text
  FROM #OrderStatusByStore
) AS SourceTable
PIVOT (
  COUNT(status_text)
  FOR status_text IN ([Pending], [Processing], [Completed], [Rejected])
) AS PivotTable;

DROP TABLE #OrderStatusByStore;

SELECT 
  b.brand_name,
  YEAR(o.order_date) AS sales_year,
  ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS total_revenue
INTO #BrandYearSales
FROM sales.orders o
JOIN sales.order_items oi ON o.order_id = oi.order_id
JOIN production.products p ON oi.product_id = p.product_id
JOIN production.brands b ON p.brand_id = b.brand_id
WHERE YEAR(o.order_date) IN (2016, 2017, 2018)
GROUP BY b.brand_name, YEAR(o.order_date);
SELECT
  brand_name,
  ISNULL([2016], 0) AS Revenue_2016,
  ISNULL([2017], 0) AS Revenue_2017,
  ISNULL([2018], 0) AS Revenue_2018,
  CASE 
    WHEN ISNULL([2016], 0) = 0 THEN 'N/A'
    ELSE 
      CAST(ROUND(((ISNULL([2017], 0) - ISNULL([2016], 0)) / ISNULL([2016], 1)) * 100, 2) AS VARCHAR) + '%' 
  END AS Growth_2016_2017,
  
  CASE 
    WHEN ISNULL([2017], 0) = 0 THEN 'N/A'
    ELSE 
      CAST(ROUND(((ISNULL([2018], 0) - ISNULL([2017], 0)) / ISNULL([2017], 1)) * 100, 2) AS VARCHAR) + '%' 
  END AS Growth_2017_2018

FROM (
  SELECT brand_name, sales_year, total_revenue
  FROM #BrandYearSales
) AS SourceTable
PIVOT (
  SUM(total_revenue)
  FOR sales_year IN ([2016], [2017], [2018])
) AS PivotTable;
DROP TABLE #BrandYearSales;
SELECT 
  p.product_id,
  p.product_name,
  'In Stock' AS availability
FROM production.products p
JOIN production.stocks s ON p.product_id = s.product_id
WHERE s.quantity > 0
UNION
SELECT 
  p.product_id,
  p.product_name,
  'Out of Stock' AS availability
FROM production.products p
JOIN production.stocks s ON p.product_id = s.product_id
WHERE s.quantity = 0 OR s.quantity IS NULL
UNION
SELECT 
  p.product_id,
  p.product_name,
  'Discontinued' AS availability
FROM production.products p
WHERE NOT EXISTS (
  SELECT 1 
  FROM production.stocks s 
  WHERE s.product_id = p.product_id
);

SELECT DISTINCT customer_id
FROM sales.orders
WHERE YEAR(order_date) = 2017

INTERSECT

SELECT DISTINCT customer_id
FROM sales.orders
WHERE YEAR(order_date) = 2018;