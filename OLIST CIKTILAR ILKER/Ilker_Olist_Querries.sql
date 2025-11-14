--CUSTOMERS
select * from `olist_tables.olist_customers_dataset`;
--ORDERS
select * from `olist_tables.olist_orders`;
--ORDERS PAYMENT 
select * from `olist_tables.olist_order_payment_dataset`;
-- ORDER REVIEWS
select * from `olist-project-477817.olist_tables.olist_order_reviews`;
--


# SECTION 1.1
--En değerli Müşteri
SELECT 
c.customer_unique_id,
SUM(op.payment_value) as Total_Payment,
o.order_status as Order_Status,
FROM `olist-project-477817.olist_tables.olist_customers_dataset` as c
inner join `olist_tables.olist_orders` as o on o.customer_id = c.customer_id
inner join `olist_tables.olist_order_payment_dataset` as  op on op.order_id = o.order_id
Group BY c.customer_unique_id,o.order_status
Having o.order_status = "delivered"
ORDER BY Total_Payment DESC;

--CLV


--Müşteriler ne sıklıkla tekrar satın alma yapıyor?
WITH date_avg AS 
(
SELECT 
c.customer_unique_id,
MIN(o.order_purchase_timestamp) as First_Order,
MAX(o.order_purchase_timestamp) as Last_Order,
DATE_DIFF(MAX(o.order_purchase_timestamp), MIN(o.order_purchase_timestamp), DAY) as day_diff
FROM `olist_tables.olist_customers_dataset`c 
INNER JOIN `olist_tables.olist_orders` o on o.customer_id = c.customer_id
GROUP BY c.customer_unique_id
HAVING COUNT(order_id) > 1 
)
SELECT 
  ROUND(AVG(day_diff), 1) AS AVG_DAY_BETWEEN_ORDERS
FROM date_avg;

#SECTION 1.3
 
 --Olist’te ortalama sipariş teslimat süresi nedir?
SELECT 
ROUND(AVG(DATE_DIFF(order_delivered_customer_date, order_purchase_timestamp, DAY)), 0) AS AVG_Delivery_Date
FROM `olist-project-477817.olist_tables.olist_orders`
WHERE order_status = 'delivered';

--Belirli satıcılar veya bölgeler teslimat gecikmeleri yaşıyor mu?
-- FONKSİYON OLUŞTURARAK DİĞER SORGULAR İÇİN GEREKEBİLECEK UZUN CTE LERDEN KAÇIŞ SAĞLADIM. 
 
CREATE OR REPLACE TABLE FUNCTION `olist-project-477817.olist_tables.get_delayed_orders`()
AS (
  WITH avg_delivery_time AS (
    SELECT 
      AVG(DATE_DIFF(DATE(order_delivered_customer_date), DATE(order_purchase_timestamp), DAY)) AS avg_delivery_days
    FROM `olist-project-477817.olist_tables.olist_orders`
    WHERE order_status = 'delivered'
  )
  SELECT 
    o.order_id,
    o.customer_id,
    o.order_status,
    DATE_DIFF(CURRENT_DATE(), DATE(o.order_purchase_timestamp), DAY) AS days_since_purchase,
    a.avg_delivery_days
  FROM `olist-project-477817.olist_tables.olist_orders` AS o
CROSS JOIN  avg_delivery_time a  
  WHERE o.order_status <> 'delivered' and o.order_status != 'canceled'
    AND DATE_DIFF(CURRENT_DATE(), DATE(o.order_purchase_timestamp), DAY) > a.avg_delivery_days
);


SELECT * FROM `olist-project-477817.olist_tables.get_delayed_orders`();


--Sipariş durumu müşteri memnuniyetini nasıl etkiliyor?

SELECT  
o.order_status,
COUNT(ore.review_id) as Review_COUNT,
ROUND(AVG(ore.review_score),0) as AVG_Review_Score  
FROM `olist_tables.olist_orders` o
LEFT JOIN `olist_tables.olist_order_reviews` ore on ore.order_id = o.order_id
GROUP BY o.order_status
ORDER BY AVG_Review_Score;



#SECTION 1.5

--Olist’in yorumlara dayalı genel müşteri memnuniyet puanı nedir?

 SELECT 
  ROUND(AVG(review_score), 2) AS overall_avg_review_score
FROM `olist-project-477817.olist_tables.olist_order_reviews`;

--Ürün kategorileri ile yorum puanları arasında bir korelasyon var mı?

SELECT 
    p.product_category_name,
    ROUND(AVG(r.review_score), 2) AS avg_score,
    COUNT(*) AS review_count
FROM `olist_tables.olist_order_items` oi 
JOIN `olist_tables.olist_products_dataset` p ON p.product_id = oi.product_id
JOIN `olist_tables.olist_orders` o ON o.order_id = oi.order_id
JOIN `olist-project-477817.olist_tables.olist_order_reviews` r ON r.order_id = o.order_id
GROUP BY p.product_category_name
ORDER BY avg_score DESC;




 --Müşteriler yorumlarında belirli geri bildirimler bırakıyor mu?
--KULLANICILARIN BIRAKMIŞ OLDUĞU HERHANGİ BİR GERİ BİLDİRİM BULUNAMADI.
select * from `olist_tables.olist_order_reviews` ;


#SECTION 1.7

  --Olist’in pazarlama kampanyaları yeni müşteriler edinmede ne kadar etkilidir?
  --Müşteri kaydı zaman içindeki trendleri nelerdir?
  -- BU İKİ SORGULAMA BİRBİRİNİN YORUM OLARAK BENZERLERİNİ İÇERİR.

-- CTE oluşturup yeni müşteri sayılarının yıllara göre dağılımını bularak yıllara göre yapılan kampanyaların etkilerini görebiliriz.

WITH first_orders AS (
  SELECT
    cd.customer_unique_id,
    MIN(o.order_purchase_timestamp) AS first_order_date
  FROM `olist-project-477817.olist_tables.olist_customers_dataset` AS cd
  INNER JOIN `olist-project-477817.olist_tables.olist_orders` AS o
    ON cd.customer_id = o.customer_id
  GROUP BY cd.customer_unique_id
)

SELECT
  EXTRACT(YEAR FROM first_order_date) AS year,
  EXTRACT(MONTH FROM first_order_date) AS month,
  COUNT(DISTINCT customer_unique_id) AS new_customers
FROM first_orders
GROUP BY year, month
ORDER BY year; 

  --Farklı pazarlama kanallarında müşteri edinim maliyeti (CAC) nedir?
  /*Olist veri setinde pazarlama kanalı veya kampanya harcaması bilgisi bulunmadığı için kanal bazlı müşteri edinim maliyeti (CAC) doğrudan hesaplanamaz.
Ancak müşteri kazanım trendleri (first order date) incelenerek dönemsel müşteri edinimi analiz edilebilir ve potansiyel kampanya etkileri dolaylı olarak değerlendirilebilir.*/



#SECTION 1.9


--STOK SORULARI İÇİN ELİMİZDE BUNLARA AİT VERİLER YOK O YÜZDEN BİR YORUMLAMA YAPILAMIYOR. 



#SECTION 2.2)3

-- CLV(Customer Lifetime Value)

WITH customer_revenue AS (
  SELECT
    c.customer_unique_id,
    SUM(i.price + i.freight_value) AS total_revenue
  FROM `olist-project-477817.olist_tables.olist_customers_dataset` c
  INNER JOIN `olist-project-477817.olist_tables.olist_orders` o
    ON c.customer_id = o.customer_id
  INNER JOIN `olist-project-477817.olist_tables.olist_order_items` i
    ON o.order_id = i.order_id
  GROUP BY c.customer_unique_id
)
SELECT
  ROUND(AVG(total_revenue), 2) AS CLV
FROM customer_revenue;


--Zaman içindeki sipariş trendlerini, mevsimselliği de dahil olmak üzere inceleyin.

SELECT
  EXTRACT(YEAR FROM order_purchase_timestamp) AS year,
  EXTRACT(MONTH FROM order_purchase_timestamp) AS month,
  COUNT(o.order_id) AS total_orders,
  SUM(price) AS total_revenue
FROM `olist-project-477817.olist_tables.olist_orders` o
INNER JOIN `olist-project-477817.olist_tables.olist_order_items` i
  ON o.order_id = i.order_id
GROUP BY year, month
ORDER BY year, month;

--Ortalama Sipariş Değeri (AOV) 

SELECT
  ROUND(SUM(price) / COUNT(DISTINCT order_id), 2) AS AOV
FROM `olist-project-477817.olist_tables.olist_order_items`;
















