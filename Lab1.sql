## 1. Identify duplicate rows where no key is provided

#standardSQL
SELECT COUNT(*) as num_duplicate_rows, * FROM 
`data-to-insights.ecommerce.all_sessions_raw` 
GROUP BY 
fullVisitorId, channelGrouping, time, country, city, totalTransactionRevenue, transactions, timeOnSite, pageviews, sessionQualityDim, date, visitId, type, productRefundAmount, productQuantity, productPrice, productRevenue, productSKU, v2ProductName, v2ProductCategory, productVariant, currencyCode, itemQuantity, itemRevenue, transactionRevenue, transactionId, pageTitle, searchKeyword, pagePathLevel1, eCommerceAction_type, eCommerceAction_step, eCommerceAction_option
HAVING num_duplicate_rows > 1;

###########################################################################################################################################

## 2. confirm no duplicates exist

#standardSQL
# schema: https://support.google.com/analytics/answer/3437719?hl=en
SELECT 
fullVisitorId, # the unique visitor ID  
visitId, # a visitor can have multiple visits
date, # session date stored as string YYYYMMDD
time, # time of the individual site hit  (can be 0 to many per visitor session)
v2ProductName, # not unique since a product can have variants like Color
productSKU, # unique for each product
type, # a visitor can visit Pages and/or can trigger Events (even at the same time)
eCommerceAction_type, # maps to ‘add to cart', ‘completed checkout'
eCommerceAction_step, 
eCommerceAction_option,
  transactionRevenue, # revenue of the order
  transactionId, # unique identifier for revenue bearing transaction
COUNT(*) as row_count 
FROM 
`data-to-insights.ecommerce.all_sessions` 
GROUP BY 1,2,3 ,4, 5, 6, 7, 8, 9, 10,11,12
HAVING row_count > 1 # find duplicates 

###########################################################################################################################################


## 3. Write a query that shows total unique visitors

#standardSQL
SELECT 
  COUNT(*) AS product_views,
  COUNT(DISTINCT fullVisitorId) AS unique_visitors
FROM `data-to-insights.ecommerce.all_sessions`;

###########################################################################################################################################


## 4. Write a query that shows total unique visitors by channel grouping (organic, referring site)

#standardSQL
SELECT 
  COUNT(DISTINCT fullVisitorId) AS unique_visitors,
  channelGrouping
FROM `data-to-insights.ecommerce.all_sessions`
GROUP BY 2
ORDER BY 2 DESC;

###########################################################################################################################################

## 5. What are all the unique product names listed alphabetically?

#standardSQL
SELECT 
  v2ProductName
FROM `data-to-insights.ecommerce.all_sessions`
GROUP BY 1
ORDER BY 1;

###########################################################################################################################################

## 6. Which 5 products had the most views from unique visitors viewed each product?

#standardSQL
SELECT 
  COUNT(*) AS product_views,
  v2ProductName 
FROM `data-to-insights.ecommerce.all_sessions`
WHERE type = 'PAGE'
GROUP BY v2ProductName
ORDER BY product_views DESC
LIMIT 5;

###########################################################################################################################################


## 7. Expand your previous query to include the total number of distinct products ordered as well as the total number of total units ordered

#standardSQL
SELECT 
  COUNT(*) AS product_views,
  COUNT(productQuantity) AS orders,
  SUM(productQuantity) AS quantity_product_ordered,
  v2ProductName 
FROM `data-to-insights.ecommerce.all_sessions`
WHERE type = 'PAGE'
GROUP BY v2ProductName
ORDER BY product_views DESC
LIMIT 5;

###########################################################################################################################################

## 8. Expand the query to include the ratio of product units to order

#standardSQL
SELECT 
  COUNT(*) AS product_views,
  COUNT(productQuantity) AS orders,
  SUM(productQuantity) AS quantity_product_ordered,
  SUM(productQuantity) / COUNT(productQuantity) AS avg_per_order,
  v2ProductName 
FROM `data-to-insights.ecommerce.all_sessions`
WHERE type = 'PAGE'
GROUP BY v2ProductName
ORDER BY product_views DESC
LIMIT 5;

###########################################################################################################################################

## Challenge 1: Calculating Conversion Rate
## For products with over 1000 units that have been added to cart or ordered that are not frisbees:
## 1. How many distinct times was the product part of an order (either complete or incomplete order)?
## 2. How many total units of the product were part of orders (either complete or incomplete)?
## 3. Which product had the highest conversion ?

#standardSQL
SELECT 
  COUNT(*) AS product_views,
  COUNT(productQuantity) AS potential_orders,
  SUM(productQuantity) AS quantity_product_added,
  (COUNT(productQuantity) / COUNT(*)) AS conversion_rate,
  v2ProductName
FROM `data-to-insights.ecommerce.all_sessions`
WHERE LOWER(v2ProductName) NOT LIKE '%frisbee%' 
GROUP BY v2ProductName
HAVING quantity_product_added > 1000 
ORDER BY conversion_rate DESC
LIMIT 10;

###########################################################################################################################################

## Challenge 2: Track Visitor Checkout Progress
## Write a query that shows the eCommerceAction_type and the distinct count of fullVisitorId associated with each type.

#standardSQL
SELECT 
  COUNT(DISTINCT fullVisitorId) AS number_of_unique_visitors,
  eCommerceAction_type
FROM `data-to-insights.ecommerce.all_sessions` 
GROUP BY eCommerceAction_type
ORDER BY eCommerceAction_type;

# Use a Case Statement to add a new column to your previous query to display the eCommerceAction_type label (e.g. "Completed purchase")

#standardSQL
SELECT 
  COUNT(DISTINCT fullVisitorId) AS number_of_unique_visitors,
  eCommerceAction_type,
  CASE eCommerceAction_type
  WHEN '0' THEN 'Unknown'
  WHEN '1' THEN 'Click through of product lists'
  WHEN '2' THEN 'Product detail views'
  WHEN '3' THEN 'Add product(s) to cart'
  WHEN '4' THEN 'Remove product(s) from cart'
  WHEN '5' THEN 'Check out'
  WHEN '6' THEN 'Completed purchase'
  WHEN '7' THEN 'Refund of purchase'
  WHEN '8' THEN 'Checkout options'
  ELSE 'ERROR'
  END AS eCommerceAction_type_label
FROM `data-to-insights.ecommerce.all_sessions` 
GROUP BY eCommerceAction_type
ORDER BY eCommerceAction_type;

###########################################################################################################################################

## Challenge 3: Track Abandoned Carts from High Quality Sessions
## Write a query using aggregation functions that returns 
## the unique session ids of those visitors who 
## have added a product to their cart but never completed checkout (abandoned their shopping cart).
## high quality sessions

#standardSQL
# high quality abandoned carts
SELECT  
  #unique_session_id
  CONCAT(fullVisitorId,CAST(visitId AS STRING)) AS unique_session_id,
  sessionQualityDim,
  SUM(productRevenue) AS transaction_revenue,
  MAX(eCommerceAction_type) AS checkout_progress
FROM `data-to-insights.ecommerce.all_sessions` 
WHERE sessionQualityDim > 60 # high quality session
GROUP BY unique_session_id, sessionQualityDim
HAVING 
  checkout_progress = '3' # 3 = added to cart
  AND (transaction_revenue = 0 OR transaction_revenue IS NULL)