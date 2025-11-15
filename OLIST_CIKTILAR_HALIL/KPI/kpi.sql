--KPI LAR 


--Ortalama Sipariş Değeri (AOV) - Aylık bazda degerlendirmesi


-- All time AOV
select
ROUND(sum(t1.price),2) as total_revenue,     
ROUND(count(distinct t1.order_id),2) as total_orders, 
ROUND(sum(t1.price) / count(distinct t1.order_id),2) as average_order_value 
from
`stone-arch-474621-h4.project_dataset.olist_order_items_silver` as t1


--Aylık aov
select
extract(year from t2.order_approved_at) as sale_year,
extract(month from t2.order_approved_at) as sale_month,
ROUND(sum(t1.price),2) as total_revenue,     
ROUND(count(distinct t1.order_id),2) as total_orders, 
ROUND(sum(t1.price) / count(distinct t1.order_id),2) as average_order_value 
from `stone-arch-474621-h4.project_dataset.olist_order_items_silver` AS t1
inner join `stone-arch-474621-h4.project_dataset.olist_orders_silver` AS t2
on t1.order_id = t2.order_id
where t2.order_approved_at != TIMESTAMP("1453-05-29 00:00:00 UTC")
group by sale_year, sale_month
ORDER BY sale_year, sale_month

----------------------------------
--müşteri yaşam boyu değeri hesaplama 

--1. adım : (aov) hesaplama : 
--2. adım : (F) purchase frequency hesaplama : 
--3. adım : müşteri değeri hesaplama : CV =  aov * F
--4. adım : ortalama müşteri yaşam süresi = 1/churn rate

WITH CustomerData AS (
    -- 1. ADIM: Tüm verileri birleştirme ve sentinel değerleri hariç tutma
    SELECT
        t1.customer_id,
        t1.order_approved_at,
        t2.price
    FROM
        `stone-arch-474621-h4.project_dataset.olist_orders_silver` AS t1 
    INNER JOIN
        `stone-arch-474621-h4.project_dataset.olist_order_items_silver` AS t2
        ON t1.order_id = t2.order_id
    -- Sentinel (işaretleyici) değeri hariç tutuyoruz
    WHERE t1.order_approved_at IS NOT NULL 
      AND t1.order_approved_at != TIMESTAMP("1453-05-29 00:00:00 UTC") 
),

CustomerMetrics AS (
    -- 2. ADIM: Her Müşterinin Temel Metriklerini Hesaplama
    SELECT
        customer_id,
        MIN(order_approved_at) AS first_order_time,
        MAX(order_approved_at) AS last_order_time,
        
        ROUND(SUM(price), 2) AS customer_total_revenue,
        COUNT(DISTINCT order_approved_at) AS customer_total_orders,
        
        -- Gün cinsinden Müşteri Ömrü (LT_Days): İlk ve Son Sipariş Arasındaki Süre
        DATE_DIFF(DATE(MAX(order_approved_at)), DATE(MIN(order_approved_at)), DAY) AS lt_days
    FROM
        CustomerData
    GROUP BY
        customer_id
)

-- 3. ADIM: Her Müşteri İçin Nihai CLV Hesaplaması (Düzeltme Uygulandı)
SELECT
    m.customer_id,
    m.first_order_time,
    m.last_order_time,
    m.lt_days,
    m.customer_total_revenue,
    m.customer_total_orders,
    
    -- Düzeltilmiş CLV Hesaplaması: LT_Days = 0 ise, Total Revenue'yi kullan.
    ROUND(
        CASE 
            -- Eğer LT_Days sıfırsa (tek satın alma), CLV'yi o yılki toplam gelir olarak kabul et
            WHEN m.lt_days = 0 
                THEN m.customer_total_revenue 
            
            -- Eğer LT_Days sıfır değilse (tekrarlı satın alma), günlük ortalama geliri yıllık tahmine yansıt.
            ELSE (m.customer_total_revenue / m.lt_days) * 365.25
        END, 
    2) AS clv_estimated_yearly_brut
    
FROM
    CustomerMetrics AS m
ORDER BY
    clv_estimated_yearly_brut DESC;



-----------------------------------------------------------------------------------------------------
--EN ÇOK SATAN ÜRÜNLER 

select 
a3.product_category_name_english as product_category,
--ROUND(sum(a1.price),2) as total_revenue, 
count(a2.product_id) as product_count
from `stone-arch-474621-h4.project_dataset.olist_order_items_silver` as a1
inner join `stone-arch-474621-h4.project_dataset.olist_products_dataset` as a2
on a1.product_id = a2.product_id
inner join `stone-arch-474621-h4.project_dataset.olist_product_category_name_translation` as a3
on a2.product_category_name = a3.product_category_name
group by product_category
order by product_count desc


--EN FAZLA GELİR GETİREN ÜRÜNLER 
select 
a3.product_category_name_english as product_category,
ROUND(sum(a1.price),2) as total_revenue, 
from `stone-arch-474621-h4.project_dataset.olist_order_items_silver` as a1
inner join `stone-arch-474621-h4.project_dataset.olist_products_dataset` as a2
on a1.product_id = a2.product_id
inner join `stone-arch-474621-h4.project_dataset.olist_product_category_name_translation` as a3
on a2.product_category_name = a3.product_category_name
group by product_category
order by total_revenue desc
-------------------------------------------------------------------------------------------------
-- Zaman İçindeki Sipariş Sayısı

SELECT
    -- Yıl ve Ayı birleştirerek YYYY-MM formatında bir sütun oluşturur
    FORMAT_DATE('%Y-%m', DATE(t1.order_approved_at)) AS year_month, 
    
    -- O aya ait benzersiz sipariş sayısını sayar
    COUNT(DISTINCT t1.order_id) AS total_orders
FROM
    `stone-arch-474621-h4.project_dataset.olist_orders_silver` AS t1
WHERE
    -- Sentinel değerleri ve NULL olanları hariç tutar
    t1.order_approved_at IS NOT NULL 
    AND t1.order_approved_at != TIMESTAMP("1453-05-29 00:00:00 UTC")
GROUP BY
    year_month
ORDER BY
    year_month;


-- HAFTALIK BAZDA SIRALAMA - ekstra 
SELECT
    -- Yıl ve Hafta numarasını verir (Örn: 2017-01)
    FORMAT_DATE('%Y-%W', DATE(t1.order_approved_at)) AS year_week, 
    
    -- O haftaya ait benzersiz sipariş sayısını sayar
    COUNT(DISTINCT t1.order_id) AS total_orders
FROM
    `stone-arch-474621-h4.project_dataset.olist_orders_silver` AS t1
WHERE
    t1.order_approved_at IS NOT NULL 
    AND t1.order_approved_at != TIMESTAMP("1453-05-29 00:00:00 UTC")
GROUP BY
    year_week
ORDER BY
    year_week;

---------------------------------------------------------------------------------
--tekrar eden müşteri ve sipariş olmadıgı için sıklıga bakamadım
select count(*),count(distinct customer_id) from `stone-arch-474621-h4.project_dataset.orders_raw` 
--Siparişler Arasındaki Ortalama Süre
-- state bazında ortalama kac gunde siparişler ulaşıyor istenebilir
-- kategori bazında ortalama süre istenebilir



SELECT
    t1.customer_state,
    -- Ortalama Teslim Süresi: Teslimat Tarihi - kargoya verme Tarihi
    ROUND(AVG(DATE_DIFF(t2.order_delivered_customer_date, t2.order_delivered_carrier_date, DAY)), 2) AS avg_delivery_days
FROM
    `stone-arch-474621-h4.project_dataset.olist_customers_dataset` AS t1
INNER JOIN
    `stone-arch-474621-h4.project_dataset.olist_orders_silver` AS t2
    ON t1.customer_id = t2.customer_id
INNER JOIN
    `stone-arch-474621-h4.project_dataset.olist_order_items_silver` AS t3
    ON t2.order_id = t3.order_id
INNER JOIN
    `stone-arch-474621-h4.project_dataset.olist_products_dataset` AS t4
    ON t3.product_id = t4.product_id
INNER JOIN
    `stone-arch-474621-h4.project_dataset.olist_product_category_name_translation` AS t5
    ON t4.product_category_name = t5.product_category_name
WHERE
    -- Sadece onaylanmış ve teslim edilmiş siparişleri dahil et
    t2.order_approved_at IS NOT NULL
    AND t2.order_delivered_customer_date IS NOT NULL
GROUP BY
    t1.customer_state
ORDER BY
    avg_delivery_days DESC;


SELECT
    t5.product_category_name_english,
    -- Ortalama Teslim Süresi: Teslimat Tarihi - kargoya verme Tarihi
   ROUND(AVG(DATE_DIFF(t2.order_delivered_customer_date, t2.order_delivered_carrier_date, DAY)), 2) AS 
FROM
    `stone-arch-474621-h4.project_dataset.olist_customers_dataset` AS t1
INNER JOIN
    `stone-arch-474621-h4.project_dataset.olist_orders_silver` AS t2
    ON t1.customer_id = t2.customer_id
INNER JOIN
    `stone-arch-474621-h4.project_dataset.olist_order_items_silver` AS t3
    ON t2.order_id = t3.order_id
INNER JOIN
    `stone-arch-474621-h4.project_dataset.olist_products_dataset` AS t4
    ON t3.product_id = t4.product_id
INNER JOIN
    `stone-arch-474621-h4.project_dataset.olist_product_category_name_translation` AS t5
    ON t4.product_category_name = t5.product_category_name
WHERE
    -- Sadece onaylanmış ve teslim edilmiş siparişleri dahil et
    t2.order_approved_at IS NOT NULL
    AND t2.order_delivered_customer_date IS NOT NULL
GROUP BY
    t5.product_category_name_english
ORDER BY
    avg_delivery_days DESC;

---------------------------------------------------------------------------------
select

extract(year from t2.order_approved_at) as sale_year,
extract(month from t2.order_approved_at) as sale_month,
ROUND(sum(t1.price),2) as total_revenue

from `stone-arch-474621-h4.project_dataset.olist_order_items_silver` AS t1
inner join `stone-arch-474621-h4.project_dataset.olist_orders_silver` AS t2
on t1.order_id = t2.order_id

where t2.order_approved_at != TIMESTAMP("1453-05-29 00:00:00 UTC")
group by sale_year, sale_month
order by sale_year, sale_month


--------------------------------------------------------------------------------------------
--Bölgeye Göre Gelir


select
t1.customer_state,
round(sum(t3.price),2) as total_price
from `stone-arch-474621-h4.project_dataset.olist_customers_dataset` as t1
inner join `stone-arch-474621-h4.project_dataset.olist_orders_silver` as t2
on t1.customer_id = t2.customer_id  -- order status için bagladım
inner join `stone-arch-474621-h4.project_dataset.olist_order_items_silver` as t3
on t2.order_id = t3.order_id
where t2.order_status='delivered'
group by t1.customer_state order by total_price desc;


--------------------------------------------------------------------------------------------
--En İyi Şehirlerden Siparişler


with citycategoryrevenue as (
select

t1.customer_city,
t5.product_category_name_english,
round(sum(t3.price),2) as total_price

from `stone-arch-474621-h4.project_dataset.olist_customers_dataset` as t1
inner join `stone-arch-474621-h4.project_dataset.olist_orders_silver` as t2
on t1.customer_id = t2.customer_id  -- order status için bagladım
inner join `stone-arch-474621-h4.project_dataset.olist_order_items_silver` as t3
on t2.order_id = t3.order_id
inner join `stone-arch-474621-h4.project_dataset.olist_products_dataset` AS t4
on t3.product_id = t4.product_id
inner join
`stone-arch-474621-h4.project_dataset.olist_product_category_name_translation` AS t5
on t4.product_category_name = t5.product_category_name


where t2.order_status='delivered'
group by t1.customer_city, t5.product_category_name_english

),
rankedcategory as (

    select *,
    rank() over (
        partition by customer_city
        order by total_price desc
    )as cate_rank from citycategoryrevenue
)
select 
customer_city,
product_category_name_english AS most_category,
total_price
from rankedcategory
where cate_rank = 1
order by total_price desc






















