SELECT year_month,
       COUNT(*) AS total_orders
FROM marts.fct_orders
GROUP BY year_month
ORDER BY year_month;