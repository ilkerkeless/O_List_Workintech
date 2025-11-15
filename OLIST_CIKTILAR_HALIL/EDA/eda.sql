/*
 EDA PROCESS
--> her bir tabloda sutün isimleri ve tipleri uyumlu mu ?
--> tekrar eden satırlar veriyi bozacak bir tekrar mı ? varsa  silinecek
--> eksik degerleri yönetelim - fill or del
--> aykırı degerleri tespit edelim 
--> isimleri standartlaştıralım
--> zaman damgalaarını normalleştirelim
--> PK atamalarını yapalım 
*/


--ORDER_ITEMS TABLOSU İÇİN DÜZENLEMELER ----------------------------------------------------------------------------------------------------------------------

select count(*),count(distinct order_id) from `stone-arch-474621-h4.project_dataset.olist_order_items_dataset`
--112650    98666
--tekrar edenleri inceleyelim 

create or replace table `stone-arch-474621-h4.project_dataset.olist_order_items_silver` as
select * from `stone-arch-474621-h4.project_dataset.olist_order_items_dataset`
where true
qualify
row_number() over (
partition by order_id
)=1

-- AYKIRI DEGER VAR MI ? YOK
select * from `stone-arch-474621-h4.project_dataset.olist_order_items_silver`
where price <0 

select 
--seller_id
price
from `stone-arch-474621-h4.project_dataset.olist_order_items_silver`
where 
--seller_id
price
is null

-- order_id PK OLUR MU ? OLUR 
SELECT count(*), count (distinct order_id) FROM `stone-arch-474621-h4.project_dataset.olist_order_items_silver`
--98666  98666 
SELECT * FROM `stone-arch-474621-h4.project_dataset.olist_order_items_silver` where order_id is null
--NO 
ALTER TABLE `stone-arch-474621-h4.project_dataset.olist_order_items_silver`
ADD PRIMARY KEY (order_id) NOT ENFORCED; -- yeni veri gelirse kontrolü bizde olacak 


-- ZAMAN DAMGASINI DEGİSTİRELİM
SELECT
t.*,
--1. UTC zaman damgasını İstanbul saat dilimine dönüştürür
DATE(
t.shipping_limit_date,
"Asia/Istanbul" -- İstanbul (Türkiye) saat dilimi
) AS istanbul_tarihi
FROM `stone-arch-474621-h4.project_dataset.olist_order_items_silver` AS t






--ORDER TABLOSU İÇİN DÜZENLEMELER ----------------------------------------------------------------------------------------------------------------------

SELECT * FROM `stone-arch-474621-h4.project_dataset.olist_orders_dataset`
QUALIFY
  ROW_NUMBER() OVER(
    PARTITION BY order_id 
     
  ) > 1; --tekrar eden yok

-- order_id PK OLUR MU ? OLUR 
SELECT count(*), count (distinct order_id) FROM `stone-arch-474621-h4.project_dataset.olist_orders_dataset`
--99441  99441 
SELECT * FROM `stone-arch-474621-h4.project_dataset.olist_orders_dataset` where order_id is null
--NO 
ALTER TABLE `stone-arch-474621-h4.project_dataset.olist_order_reviews_silver`
ADD PRIMARY KEY (order_id) NOT ENFORCED; -- yeni veri gelirse kontrolü bizde olacak 


select * from 


SELECT
--order_status
 FROM `stone-arch-474621-h4.project_dataset.olist_orders_dataset` where order_status is null


-- null olanları UNKNOWN YAZALIM
select * from `stone-arch-474621-h4.project_dataset.olist_orders_dataset` 
where order_approved_at is null

update 
`stone-arch-474621-h4.project_dataset.olist_orders_silver`
set  order_approved_at = 'UNKNOWN'
where order_approved_at is null


CREATE OR REPLACE TABLE  `stone-arch-474621-h4.project_dataset.olist_orders_silver` as
from `stone-arch-474621-h4.project_dataset.olist_orders_dataset` 


--null olan tarihlere gezersiz tarih atadım
UPDATE
`stone-arch-474621-h4.project_dataset.olist_orders_silver`
SET
order_approved_at = TIMESTAMP("1453-05-29 00:00:00 UTC") 
WHERE
order_approved_at IS NULL;

--REVIEWS TABLOSU İÇİN DÜZENLEMELER ----------------------------------------------------------------------------------------------------------------------
select count(order_id),count(distinct order_id) from `stone-arch-474621-h4.project_dataset.olist_order_reviews_dataset`;
--aynı sipariş için birden fazla yorum yapılmış
--99224 -  98673   NOT unique   fark 551 
--547  1 time duplicated
--4    2 time duplicated
--where order_id is null  NO 


--TEKRARLAYANLARI ALMADAN TABLOYU OLUSTURDUK
CREATE OR REPLACE TABLE `stone-arch-474621-h4.project_dataset.olist_order_reviews_silver` AS
SELECT * FROM `stone-arch-474621-h4.project_dataset.olist_order_reviews_dataset`
QUALIFY
  ROW_NUMBER() OVER(
    PARTITION BY order_id 
    ORDER BY review_id ASC 
  ) = 1; -- Sadece row_num'ı 1 olanı (yani korunacak tekil kaydı) alır.
    

-- NULL SATIR YOK
select
--order_id
--review_score
--review_creation_date
review_answer_timestamp
 from  `stone-arch-474621-h4.project_dataset.olist_order_reviews_silver` where review_answer_timestamp 
 is null 






