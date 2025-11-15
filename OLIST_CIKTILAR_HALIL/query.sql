s--2.1-----------------------------------------------------------------------------------------------------------------------
 SELECT
  order_status,
  COUNT(order_status) AS tekrar_sayisi
FROM
  `stone-arch-474621-h4.project_dataset.olist_orders_dataset`
WHERE
  order_status IS NOT NULL
GROUP BY
  order_status
ORDER BY
  tekrar_sayisi DESC;

-- orders tablosundan order_status delivered olanları delivered olanların order_id sini - 
--order_istems tablosundan  order_id > product_id getir
-- product_id ile category name > english olarak 
--
select
sub1.product_id,
sub1.product_category_name_english,
count(sub1.product_id) as total_order_count
from
(
select
t1.order_id,
t2.product_id,
t3.product_category_name,
t4.product_category_name_english
from `stone-arch-474621-h4.project_dataset.olist_orders_dataset` as t1
left join
`stone-arch-474621-h4.project_dataset.olist_order_items_dataset` as t2
on t1.order_id=t2.order_id
left join
`stone-arch-474621-h4.project_dataset.olist_products_dataset` as t3
on t2.product_id = t3.product_id  
left join
`stone-arch-474621-h4.project_dataset.olist_product_category_name_translation` as t4
on t3.product_category_name = t4.product_category_name
where t1.order_status ='delivered'
)as sub1
group by sub1.product_id,sub1.product_category_name_english
order by total_order_count desc
limit 10;

--2.2-------------------------------------------------------------------------------------------------------

/*
Ürün ve Satış İçgörüleri:
Olist’in en çok satan ürünleri hangileridir?
Olist’te genel gelir trendleri nelerdir?
Hangi ürün kategorileri gelire en fazla katkıda bulunmaktadır?
*/

select payment_type,ROUND(sum(payment_value),2) as total_payment
from `stone-arch-474621-h4.project_dataset.olist_order_payments_dataset` 
group by payment_type order by total_payment desc;
--Boleto: Çoğunlukla bilet veya Brezilya'da bir ödeme emri.
--Voucher: Bir hizmete veya değere hak kazandığınızı gösteren kupon, çeki veya rezervasyon belgesi.

--2.3---------------------------------------------------------------------------------------------------------

--order id ile product_id ile birleştirip value toplamına bakmam lazım 
select 
t4.product_category_name_english,
round(sum(t1.payment_value),2) as total_value,
round(sum(t2.price),2) as total_price
 from `stone-arch-474621-h4.project_dataset.olist_order_payments_dataset` as t1
left join `stone-arch-474621-h4.project_dataset.olist_order_items_dataset` as t2
on t1.order_id=t2.order_id
left join `stone-arch-474621-h4.project_dataset.olist_products_dataset` as t3
on t2.product_id=t3.product_id
left join `stone-arch-474621-h4.project_dataset.olist_product_category_name_translation` as t4
on t3.product_category_name=t4.product_category_name
group by t4.product_category_name_english
order by total_value desc
limit 10;
----------------------------------------------------------------------------------------------------------------

/*
Pazar Yeri Dinamikleri:
Olist’te kaç aktif satıcı bulunmaktadır?
Ürünler farklı satıcılar arasında nasıl dağıtılmaktadır?
Satıcı ve ürün aktivitelerinde mevsimsel trendler var mı?*/

 
-----------------------------------------------------------------------------------------------------
--4.1
SELECT 
count(distinct sub.seller_id) as counter_seller
FROM 
(
select t1.seller_id -- ihtiyacım olan bu 
from `stone-arch-474621-h4.project_dataset.olist_sellers_dataset` as t1
INNER JOIN `stone-arch-474621-h4.project_dataset.olist_order_items_dataset` as t2 
ON t1.seller_id = t2.seller_id
)
as sub;

--4.2-------------------------------------------------------------------------------------------------------------

SELECT
    final.seller_id,
    final.seller_state,
    final.product_category_name_english,
    final.items_in_this_category,
    -- Satıcı bazında toplam satılan ürün adedi (tüm kategoriler dahil)
    SUM(final.items_in_this_category) OVER (PARTITION BY final.seller_id) AS total_items_by_seller,
    -- Satıcının satış yaptığı farklı kategori adedi
    COUNT(final.product_category_name_english) OVER (PARTITION BY final.seller_id) AS total_categories_by_seller
FROM
(
    -- ADIM 1: Satıcı ve kategori bazında sipariş kalemlerini gruplayıp sayıyoruz
    SELECT
        t1.seller_id,
        t1.seller_state,
        t4.product_category_name_english,
        COUNT(t2.order_item_id) AS items_in_this_category -- Kategori bazında ürün sayısı
    FROM 
        `stone-arch-474621-h4.project_dataset.olist_sellers_dataset` AS t1
    INNER JOIN 
        `stone-arch-474621-h4.project_dataset.olist_order_items_dataset` AS t2 
        ON t1.seller_id = t2.seller_id
    LEFT JOIN 
        `stone-arch-474621-h4.project_dataset.olist_products_dataset` AS t3
        ON t2.product_id = t3.product_id
    LEFT JOIN 
        `stone-arch-474621-h4.project_dataset.olist_product_category_name_translation` AS t4
        ON t3.product_category_name = t4.product_category_name
    GROUP BY 
        t1.seller_id,
        t1.seller_state,
        t4.product_category_name_english
) AS final
ORDER BY
    total_items_by_seller DESC, 
    final.seller_id,
    final.items_in_this_category DESC
LIMIT 50;

--4.3-------------------------------------------------------------------------------------------------------------
--Satıcı ve ürün aktivitelerinde mevsimsel trendler var mı?


SELECT
    EXTRACT(YEAR FROM t1.order_approved_at) AS sale_year,
    EXTRACT(MONTH FROM t1.order_approved_at) AS sale_month,
    COUNT(DISTINCT t2.seller_id) AS distinct_active_sellers, -- Aylık aktif satıcı sayısı
    COUNT(t1.order_id) AS total_orders_approved_in_month       -- Aylık toplam sipariş sayısı
FROM 
    `stone-arch-474621-h4.project_dataset.olist_orders_dataset` AS t1
INNER JOIN 
    `stone-arch-474621-h4.project_dataset.olist_order_items_dataset` AS t2 
    ON t1.order_id = t2.order_id 
WHERE 
    t1.order_status = 'delivered'
    AND t1.order_approved_at IS NOT NULL
   
GROUP BY
    sale_year,
    sale_month
ORDER BY
    sale_year,
    sale_month;

-- EKSTRA SORU : urun bazında var mı trend ? 
SELECT
    EXTRACT(YEAR FROM t1.order_purchase_timestamp) AS sale_year,
    EXTRACT(MONTH FROM t1.order_purchase_timestamp) AS sale_month,
    t4.product_category_name_english,
    COUNT(t2.order_item_id) AS items_sold_in_category -- Aylık kategorik satış hacmi
FROM 
    `stone-arch-474621-h4.project_dataset.olist_orders_dataset` AS t1
INNER JOIN 
    `stone-arch-474621-h4.project_dataset.olist_order_items_dataset` AS t2 
    ON t1.order_id = t2.order_id 
INNER JOIN 
    `stone-arch-474621-h4.project_dataset.olist_products_dataset` AS t3 -- Kategoriye ulaşmak için ekledik
    ON t2.product_id = t3.product_id
LEFT JOIN 
    `stone-arch-474621-h4.project_dataset.olist_product_category_name_translation` AS t4 -- İngilizce kategori adı için ekledik
    ON t3.product_category_name = t4.product_category_name
WHERE 
    t1.order_status = 'delivered'
GROUP BY
    sale_year,
    sale_month,
    t4.product_category_name_english
ORDER BY
    sale_year,
    sale_month,
    items_sold_in_category DESC;


--6.1-------------------------------------------------------------------------------------------------    
/*
Hangi bölgeler veya eyaletler Olist için en fazla geliri sağlıyor?
Müşteri davranışında bölgesel farklılıklar var mı?
Satıcılar ve müşteriler şehirler arasında nasıl dağıtılmaktadır?
*/

--Hangi bölgeler veya eyaletler Olist için en fazla geliri sağlıyor?
select
t1.seller_state,
round(sum(t2.price),2) as total_price
from `stone-arch-474621-h4.project_dataset.olist_sellers_dataset` as t1
inner join `stone-arch-474621-h4.project_dataset.olist_order_items_dataset` as t2
on t1.seller_id = t2.seller_id
inner join `stone-arch-474621-h4.project_dataset.olist_orders_dataset` as t3
on t2.order_id = t3.order_id  -- order status için bagladım
where t3.order_status='delivered'
group by seller_state order by total_price desc;

--6.2-------------------------------------------------------------------------------------------------    

--Müşteri davranışında bölgesel farklılıklar var mı?   var
--



SELECT
    customer_state,
    product_category_name_english,
    total_price
FROM
(
    -- Eyalet-Kategori bazında toplam fiyatı hesapla ve sırala
    SELECT
        t1.customer_state,
        t5.product_category_name_english,
        ROUND(SUM(t3.price), 2) AS total_price,
        -- Her eyalet (customer_state) içinde kategorileri total_price'a göre sırala
        ROW_NUMBER() OVER (
            PARTITION BY t1.customer_state
            ORDER BY SUM(t3.price) DESC
        ) AS category_rank
    FROM 
        `stone-arch-474621-h4.project_dataset.olist_customers_dataset` AS t1
    INNER JOIN 
        `stone-arch-474621-h4.project_dataset.olist_orders_dataset` AS t2
        ON t1.customer_id = t2.customer_id 
    INNER JOIN 
        `stone-arch-474621-h4.project_dataset.olist_order_items_dataset` AS t3
        ON t2.order_id = t3.order_id
    INNER JOIN 
        `stone-arch-474621-h4.project_dataset.olist_products_dataset` AS t4
        ON t3.product_id = t4.product_id
    INNER JOIN 
        `stone-arch-474621-h4.project_dataset.olist_product_category_name_translation` AS t5
        ON t4.product_category_name = t5.product_category_name 
    GROUP BY 
        t1.customer_state,
        t5.product_category_name_english
) AS ranked_categories
-- ADIM 2: Sadece ilk 3 sıradaki kategorileri filtrele
WHERE
    category_rank <= 3
ORDER BY
    customer_state,
    total_price DESC;

---6.3------------------------------------------------------------------------------------------------    
--Satıcılar ve müşteriler şehirler arasında nasıl dağıtılmaktadır?
select
sum(total_orders)
from (
SELECT
    t1.seller_state,
    t4.customer_state,
    t1.seller_city,
    t4.customer_city,
    COUNT(t3.order_id) AS total_orders,
    -- Eyalet 
    CASE
        WHEN t1.seller_state = t4.customer_state THEN 'Ayni Eyalet Icinde' ELSE 'Farkli Eyaletler Arasi'
    END AS state_match_status,
    -- Şehir
    CASE
        WHEN t1.seller_city = t4.customer_city THEN 'Ayni Sehir Icinde' ELSE 'Farkli Sehirler Arasi'
    END AS city_match_status
FROM 
    `stone-arch-474621-h4.project_dataset.olist_sellers_dataset` AS t1
INNER JOIN 
    `stone-arch-474621-h4.project_dataset.olist_order_items_dataset` AS t2
    ON t1.seller_id = t2.seller_id
INNER JOIN 
    `stone-arch-474621-h4.project_dataset.olist_orders_dataset` AS t3
    ON t2.order_id = t3.order_id
INNER JOIN 
    `stone-arch-474621-h4.project_dataset.olist_customers_dataset` AS t4
    ON t3.customer_id = t4.customer_id
GROUP BY
    t1.seller_state,
    t4.customer_state,
    t1.seller_city,
    t4.customer_city,
    state_match_status,
    city_match_status
ORDER BY
    total_orders DESC
)as sub
where city_match_status ='Ayni Sehir Icinde' -- 5863
--where state_match_status ='Ayni Eyalet Icinde' --40756
--where state_match_status ='Farkli Eyaletler Arasi' --71894
--8.1---------------------------------------------------------------------------------
/*
Dolandırıcılık ve Risk Yönetimi:
İşlem verilerinde alışılmadık desenler veya anormallikler var mı?
Olist’in dolandırıcılık tespit sistemi ne kadar etkilidir?
Belirli bölgeler veya satıcılar daha yüksek riskle ilişkilendiriliyor mu?
*/



--Değer Anormallikleri (Fiyat, Kargo Ücreti)
SELECT
    t3.order_id,
    t3.price,
    -- Satış fiyatının genel ortalamaya göre ne kadar yüksek olduğunu görmek
    (t3.price / AVG(t3.price) OVER ()) AS price_vs_avg_ratio
FROM
    `stone-arch-474621-h4.project_dataset.olist_order_items_dataset` AS t3
ORDER BY
    price_vs_avg_ratio DESC -- En pahalı siparişler en başta
LIMIT 10; --- ilk 3 satır 55 katı ortalamanın diyor anormal diyebiliriz

---
SELECT
    t3.order_id,
    t3.price,
    t3.freight_value, -- kargo maliyeti
    -- Kargo fiyatının genel ortalamaya göre ne kadar yüksek olduğunu görmek
    (t3.freight_value / AVG(t3.freight_value) OVER ()) AS freight_vs_avg_ratio
FROM
    `stone-arch-474621-h4.project_dataset.olist_order_items_dataset` AS t3
ORDER BY
    freight_vs_avg_ratio DESC -- En pahalı kargo maliyeti en başta
LIMIT 10; --- 
---

SELECT
    t1.order_id,
    t1.order_purchase_timestamp,
    t1.order_delivered_customer_date,
    -- Teslimat süresi (Gün cinsinden)
    DATE_DIFF(t1.order_delivered_customer_date, t1.order_purchase_timestamp, DAY) AS delivery_duration_days
FROM
    `stone-arch-474621-h4.project_dataset.olist_orders_dataset` AS t1
WHERE
    t1.order_status = 'delivered'
ORDER BY
    delivery_duration_days DESC -- En yavaş teslimatlar en başta
LIMIT 10;



--Kategorik Anormallikler 
    t1.seller_id,
    COUNT(t3.order_status) AS total_cancellations
FROM 
    `stone-arch-474621-h4.project_dataset.olist_order_items_dataset` AS t1
INNER JOIN 
    `stone-arch-474621-h4.project_dataset.olist_orders_dataset` AS t3
    ON t1.order_id = t3.order_id
WHERE
    t3.order_status = 'canceled' -- İptal edilenler
GROUP BY
    t1.seller_id
ORDER BY
    total_cancellations DESC
LIMIT 10;




/*
Aşırı Hacimli Tekil Siparişler (Fiyat Anormalliği):
Bir kişinin tek bir siparişte ortalamanın çok üzerinde harcama yapması. (Genellikle çalınan kartlarla yapılan denemelerdir.)
*/

--Aşırı Hızlı İptal/Onay (Zaman Anormalliği):
--Siparişin saniyeler içinde verilip onaylanması ve hemen ardından iptal edilmesi. (Bot trafiği veya sistem denemeleri olabilir.)
SELECT
    t1.order_id,
    t1.order_status,
    t1.order_purchase_timestamp,
    t1.order_approved_at,
    -- Onay süresi (Saniye cinsinden)
    TIMESTAMP_DIFF(t1.order_approved_at, t1.order_purchase_timestamp, SECOND) AS approval_duration_seconds,
    t2.price,
    t4.customer_city,
    t4.customer_state
FROM
    `stone-arch-474621-h4.project_dataset.olist_orders_dataset` AS t1
INNER JOIN 
    `stone-arch-474621-h4.project_dataset.olist_order_items_dataset` AS t2 
    ON t1.order_id = t2.order_id
INNER JOIN 
    `stone-arch-474621-h4.project_dataset.olist_customers_dataset` AS t4
    ON t1.customer_id = t4.customer_id
WHERE
    t1.order_approved_at IS NOT NULL
ORDER BY
    approval_duration_seconds desc -- En hızlı onaylananlar en üstte
LIMIT 100;


--Aynı müşterinin sürekli olarak  çok düşük fiyatlı ürünleri alması.
SELECT
    t4.customer_unique_id,
    COUNT(DISTINCT t1.order_id) AS total_orders,                           -- Toplam sipariş sayısı
    ROUND(AVG(t2.price), 2) AS average_item_price,                         -- Ortalama ürün fiyatı
    ROUND(SUM(t2.price), 2) AS total_revenue_from_customer                -- Müşteriden gelen total gelir
FROM
    `stone-arch-474621-h4.project_dataset.olist_orders_dataset` AS t1
INNER JOIN 
    `stone-arch-474621-h4.project_dataset.olist_order_items_dataset` AS t2 
    ON t1.order_id = t2.order_id
INNER JOIN 
    `stone-arch-474621-h4.project_dataset.olist_customers_dataset` AS t4
    ON t1.customer_id = t4.customer_id
WHERE
    t1.order_status NOT IN ('canceled', 'unavailable') -- İptal edilenleri saymayacam
GROUP BY
    t4.customer_unique_id
-- Analiz: En az 5 siparişi olan ve ortalama fiyatı çok düşük olan müşterileri hedefle
HAVING
    total_orders >= 2 AND average_item_price < 100
ORDER BY
    total_orders DESC,
    average_item_price ASC; -- En çok sipariş veren ve en düşük ortalamaya sahip olanlar üste çıksın


----
-- 8 numaralı şüpheli - kredi kartı ile ödendiyse muhtemelen çalıntı diye yorumlanabilir.
SELECT
    t1.order_id,
    t1.customer_id,
    t1.order_status,
    order_totals.total_order_price,
    -- Tüm siparişlerin ortalama toplam değerini hesapla
    ROUND(AVG(order_totals.total_order_price) OVER (), 2) AS overall_avg_order_price,
    -- Bireysel siparişin ortalamaya göre kaç kat yüksek olduğunu gösteren oran
    ROUND((order_totals.total_order_price / AVG(order_totals.total_order_price) OVER ()), 2) AS price_vs_avg_ratio
FROM
    `stone-arch-474621-h4.project_dataset.olist_orders_dataset` AS t1
INNER JOIN 
(
    -- ADIM 1: Her siparişin toplam fiyatını (Ürün + Kargo) hesapla
    SELECT
        order_id,
        SUM(price + freight_value) AS total_order_price 
    FROM
        `stone-arch-474621-h4.project_dataset.olist_order_items_dataset`
    GROUP BY
        order_id
) AS order_totals
ON t1.order_id = order_totals.order_id
ORDER BY
    price_vs_avg_ratio DESC -- Ortalama siparişe göre en büyük orana sahip olanlar üste çıksın
LIMIT 10;




------------------------10.kısım----MEMNUNİYET ÜZERİNE DÜŞÜNELİM---------------------------------------------------------------------------------
/* Belirli bölgeler veya satıcılar daha yüksek riskle ilişkilendiriliyor mu?
Bu sorgu, her bir satıcının toplam sipariş sayısına oranla ne kadar çok siparişi iptal edildiğini hesaplar. Yüksek orana sahip satıcılar, yüksek riskle ilişkilendirilir. 
*/
select 
t1.seller_id,
COUNT(t2.order_id) AS total_orders_handled,
SUM(CASE WHEN t2.order_status = 'canceled' THEN 1 ELSE 0 END) AS total_canceled_orders, -- İptal edilen sipariş sayısı
-- İptal Oranı
ROUND(SUM(CASE WHEN t2.order_status = 'canceled' THEN 1 ELSE 0 END) * 100.0 / COUNT(t2.order_id),2) AS cancellation_rate_percent
from `stone-arch-474621-h4.project_dataset.olist_order_items_dataset` as t1
inner join `stone-arch-474621-h4.project_dataset.olist_orders_dataset` as t2
ON t1.order_id = t2.order_id
GROUP BY t1.seller_id
-- Sadece anlamlı sonuçlar için, en az 10 siparişi olan satıcıları alalım
HAVING COUNT(t2.order_id) >= 10
ORDER BY
cancellation_rate_percent DESC,
total_orders_handled DESC
LIMIT 10;

----

/*Müşteri Eyaletleri Başına İptal Oranı (Geographical Risk)
Bu sorgu, bir siparişin yapıldığı bölgenin iptal oranını gösterir. Belirli bölgelerdeki müşteriler, diğerlerine göre daha sık siparişlerini iptal ediyor olabilir.
*/
SELECT
    t4.customer_state,
    COUNT(t2.order_id) AS total_orders_from_state,
    SUM(CASE WHEN t2.order_status = 'canceled' THEN 1 ELSE 0 END) AS total_canceled_orders,
    
    -- İptal Oranı
    ROUND(
        SUM(CASE WHEN t2.order_status = 'canceled' THEN 1 ELSE 0 END) * 100.0 / COUNT(t2.order_id),
    2) AS cancellation_rate_percent
FROM 
    `stone-arch-474621-h4.project_dataset.olist_orders_dataset` AS t2 
INNER JOIN 
    `stone-arch-474621-h4.project_dataset.olist_customers_dataset` AS t4
    ON t2.customer_id = t4.customer_id
GROUP BY
    t4.customer_state
-- Sadece anlamlı sonuçlar için, en az 50 siparişi olan eyaletleri alalım
HAVING 
    COUNT(t2.order_id) >= 50
ORDER BY
    cancellation_rate_percent DESC,
    total_orders_from_state DESC;
-----------------------------------------------------------------------------------------------
--teslimat süresi düştükçe puan artmış

select 
count(t1.order_id) as count_order_with_score,
t1.review_score,
avg(date_diff(t1.review_answer_timestamp,t1.review_creation_date,DAY)) as diff_days_reviews,
avg(date_diff(t2.order_delivered_customer_date,t2.order_approved_at,DAY)) as process_days_order
 
from `stone-arch-474621-h4.project_dataset.olist_order_reviews_dataset` as t1
inner join `stone-arch-474621-h4.project_dataset.olist_orders_dataset`  as t2
on t1.order_id = t2.order_id
WHERE
t2.order_status = 'delivered'
AND t2.order_approved_at IS NOT NULL
AND t2.order_delivered_customer_date IS NOT NULL
GROUP BY
t1.review_score
ORDER BY
t1.review_score;


/*
Olist'in kendi içinde en güçlü olduğu ve muhtemelen rekabette avantajlı olduğu kategorileri belirleyebiliriz.
Hacim Liderliği (Volume Dominance): En çok satılan ve en çok gelir getiren kategoriler. (Büyük Pazar Payı)
Müşteri Memnuniyeti Liderliği (Satisfaction Leader): En yüksek ortalama yoruma sahip kategoriler. (Kalite ve Deneyim Avantajı)
*/

WITH CategoryMetrics AS (
    -- ADIM 1: Her kategori için Hacim, Gelir ve Ortalama Puanı hesapla
    SELECT
        t4.product_category_name_english,
        COUNT(t1.order_item_id) AS total_items_sold,
        ROUND(SUM(t1.price), 2) AS total_revenue,
        ROUND(AVG(t3.review_score), 2) AS average_review_score,
        COUNT(t3.review_score) AS total_reviews_count
    FROM 
        `stone-arch-474621-h4.project_dataset.olist_order_items_dataset` AS t1
    INNER JOIN 
        `stone-arch-474621-h4.project_dataset.olist_products_dataset` AS t2 
        ON t1.product_id = t2.product_id
    LEFT JOIN 
        `stone-arch-474621-h4.project_dataset.olist_product_category_name_translation` AS t4
        ON t2.product_category_name = t4.product_category_name
    LEFT JOIN
        `stone-arch-474621-h4.project_dataset.olist_orders_dataset` AS t5 -- Yorumlar için
        ON t1.order_id = t5.order_id
    LEFT JOIN
        `stone-arch-474621-h4.project_dataset.olist_order_reviews_dataset` AS t3 
        ON t1.order_id = t3.order_id
    GROUP BY
        t4.product_category_name_english
    -- Anlamlı sonuçlar için: En az 500 ürün satılan ve 50 yorum alan kategorileri al
    HAVING 
        COUNT(t1.order_item_id) >= 500 AND COUNT(t3.review_score) >= 50
)
-- ADIM 2: Memnuniyet skoruna göre sıralama (RANK) yap
SELECT
    product_category_name_english,
    total_revenue,
    total_items_sold,
    average_review_score,
    -- Memnuniyet skoruna göre kategori sıralaması
    RANK() OVER (ORDER BY average_review_score DESC, total_reviews_count DESC) AS satisfaction_rank
FROM 
    CategoryMetrics
ORDER BY
    total_revenue DESC -- Hacim liderlerini üstte tut
LIMIT 20; -- En büyük 20 kategoriyi listele


/*
sonuc
health_beauty (Hem Hacim Hem Kalite)  sıralama 12 hacim yüksek bu alanda güçlü
bed_bath_table hacim var ama puan düşük sıralama da kötü -- müşteri kaybına müsait
*/

/*
Zayıf Alanlara Müdahale: bed_bath_table (Memnuniyet Sıralaması 26.) ve watches_gifts (Memnuniyet Sıralaması 20.) gibi hacmi yüksek ancak puanı düşük olan kategorilerdeki satıcılar için sert performans eşikleri belirlenmelidir. Bu kategorilerde puanları 3.5'in altında olan satıcılar ya platformdan çıkarılmalı ya da özel eğitim programlarına alınmalıdır.

anormali tespiti için test yada fonksiyon ile kontrol edilebilir

"Hızlı Kargo Sözü" Kategorisi: En çok satılan ve puanı en yüksek olan kategorilerde (health_beauty, sports_leisure), müşterilere "24 saatte kargo" gibi agresif teslimat sözleri verilerek, rakiplerle aradaki memnuniyet farkı açılmalıdır.

Satıcı Risk Azaltma: Yüksek iptal oranına sahip satıcılar (tespit edilen ilk 10 satıcı), stoklarını doğru girmeleri için zorlanmalı veya satabilecekleri maksimum ürün hacmi sınırlandırılmalıdır. Bu, envanter hatasından kaynaklanan sipariş iptallerini doğrudan azaltır.

*/
-----------------------------------------------------------------------------------------


/*
2. kısım 1. soru 
Müşteri davranışı desenlerini analiz edin.
--RFM (Recency, Frequency, Monetary) hesapladık ve bunu istatistiksel bir yaklaşım ile yaptık when-case ile puanlarken
3 asadaman olusuyor sorgu
 --> Veri hazırlama --> Skorlama --> Segmentasyon
not 2.kısım 2.soruda da kullanacağmı için tablo olusturdum
*/

create or replace table `stone-arch-474621-h4.project_dataset.olist_customer_score_dataset` as

WITH CustomerMetrics AS (
    -- 1. Müşteri bazında R, F, M metriklerini hesaplar
    SELECT 
        t1.customer_id,
        DATE_DIFF(CURRENT_DATE(), date(MAX(t1.order_purchase_timestamp)), DAY) AS Recency,
        COUNT(DISTINCT t1.order_id) AS Frequency, 
        SUM(t2.price) AS Monetary
    FROM 
        `stone-arch-474621-h4.project_dataset.olist_orders_dataset` AS t1
    INNER JOIN
        `stone-arch-474621-h4.project_dataset.olist_order_items_dataset` AS t2 
        ON t1.order_id = t2.order_id
    WHERE 
        t1.order_status = 'delivered'
    GROUP BY t1.customer_id
),

QuartileThresholds AS (
    -- 2. Beşte birlik (quintile) eşik değerlerini hesaplar
    -- zaman farklarının hepsini aldık 
        --verinin 0%, 20%, 40%, 60%, 80% ve 100% yüzdelik dilimlerini (quantile) bulduk
        -- APPROX_QUANTILES dizi yaratır offset ile  offset 1 dediğimizde en yakın yüzde 20 ye denk geliyor sıralamadaki  bunlara 5 verecem ki yakın zamanda almışlar
    SELECT
        APPROX_QUANTILES(Recency, 5)[OFFSET(1)] AS R_Score_1_Max,    -- 0 ile P20 arası R_Score_1_Max (P20)5 Puan
        APPROX_QUANTILES(Recency, 5)[OFFSET(2)] AS R_Score_2_Max,    -- P20 ile P40 arası R_Score_2_Max (P420)4 Puan
        APPROX_QUANTILES(Recency, 5)[OFFSET(3)] AS R_Score_3_Max,    -- P40 ile P60 arası R_Score_3_Max (P460)3 Puan
        APPROX_QUANTILES(Recency, 5)[OFFSET(4)] AS R_Score_4_Max,    -- P60 ile P80 arası R_Score_4_Max (P480)2 Puan
                                                                     -- Case when ile geriye kalana da 1 puan atarız       
        
        APPROX_QUANTILES(Frequency, 5)[OFFSET(1)] AS F_Score_1_Max, 
        APPROX_QUANTILES(Frequency, 5)[OFFSET(2)] AS F_Score_2_Max,
        APPROX_QUANTILES(Frequency, 5)[OFFSET(3)] AS F_Score_3_Max,
        APPROX_QUANTILES(Frequency, 5)[OFFSET(4)] AS F_Score_4_Max, 

        APPROX_QUANTILES(Monetary, 5)[OFFSET(1)] AS M_Score_1_Max, 
        APPROX_QUANTILES(Monetary, 5)[OFFSET(2)] AS M_Score_2_Max,
        APPROX_QUANTILES(Monetary, 5)[OFFSET(3)] AS M_Score_3_Max,
        APPROX_QUANTILES(Monetary, 5)[OFFSET(4)] AS M_Score_4_Max
    FROM
        CustomerMetrics
),

RFMScores AS (
    -- 3. Eşik değerlerini kullanarak skorlamayı yapar
    SELECT
        cm.customer_id,
        cm.Recency,
        cm.Frequency,
        cm.Monetary,
        -- R_Score (Düşük Recency = Yüksek Skor)
        CASE
            WHEN cm.Recency <= qt.R_Score_1_Max THEN 5 
            WHEN cm.Recency <= qt.R_Score_2_Max THEN 4
            WHEN cm.Recency <= qt.R_Score_3_Max THEN 3
            WHEN cm.Recency <= qt.R_Score_4_Max THEN 2
            ELSE 1
        END AS R_Score,
        -- F_Score (Yüksek Frequency = Yüksek Skor)
        CASE
            WHEN cm.Frequency >= qt.F_Score_4_Max THEN 5 
            WHEN cm.Frequency >= qt.F_Score_3_Max THEN 4
            WHEN cm.Frequency >= qt.F_Score_2_Max THEN 3
            WHEN cm.Frequency >= qt.F_Score_1_Max THEN 2
            ELSE 1
        END AS F_Score,
        -- M_Score (Yüksek Monetary = Yüksek Skor)
        CASE
            WHEN cm.Monetary >= qt.M_Score_4_Max THEN 5
            WHEN cm.Monetary >= qt.M_Score_3_Max THEN 4
            WHEN cm.Monetary >= qt.M_Score_2_Max THEN 3
            WHEN cm.Monetary >= qt.M_Score_1_Max THEN 2
            ELSE 1
        END AS M_Score
    FROM
        CustomerMetrics AS cm
    CROSS JOIN 
        QuartileThresholds AS qt 
)

-- 4. Nihai Sonuçları ve Segmentasyonu Seçme
SELECT 
    customer_id,
    recency,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    
    -- RFM_Score: Virgül hatası burada giderildi
    CONCAT(
        CAST(r_score AS STRING),
        CAST(f_score AS STRING),
        CAST(m_score AS STRING)
    ) AS RFM_Score, -- RFM_Score olarak takma ad, virgül (,) eklendi.
    
    -- RFM_Segment
    CASE
        WHEN r_score = 5 AND f_score = 5 AND m_score = 5 THEN 'En Iyi Müşteri'
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Sadık Müşteriler'
        WHEN r_score = 5 AND f_score BETWEEN 1 AND 3 THEN 'Yeni Müşteriler'
        WHEN r_score <= 2 AND f_score >= 5 AND m_score >= 4 THEN 'Yüksek Değerli Kayıp Riskli'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Kayıp Müşteriler'
        WHEN r_score BETWEEN 3 AND 4 AND f_score BETWEEN 3 AND 4 THEN 'Potansiyel Sadık Müşteriler'
        WHEN r_score <= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Dikkat Gerektirenler'
        ELSE 'Diger' 
    END AS RFM_segment

FROM RFMScores -- 
ORDER BY r_score DESC, f_score DESC, m_score DESC;


---2.1-2   -- en iyi müşterilerimiz de boleto olanlar var > bunların alıskanlıklarını değiştirebiliriz .
with sub as (
select 
*
from `stone-arch-474621-h4.project_dataset.olist_customer_score_dataset` as t1
inner join `stone-arch-474621-h4.project_dataset.olist_orders_dataset` as t2
on t1.customer_id = t2.customer_id
where t1.RFM_Score ='555' limit 10 -- en iyi müşterim ne ile alışveriş yapıyor 

)

select
sub.*,
t3.*
from sub inner join `stone-arch-474621-h4.project_dataset.olist_order_payments_dataset` AS t3
ON sub.order_id = t3.order_id 


/* 2 -2 soruları tek sorguda cevapladım 
Ürün Performans Değerlendirmesi:
Satışlar ve müşteri yorumlarına göre ürün performansını değerlendirin.
En çok satan ürünleri ve ana ürün kategorilerini belirleyin.
=YORUM! score oy kullananlar da ürünü satın almayanlar da var guvenli degil 
*/



WITH ProductPerformance AS (
    SELECT 
        -- Ürün ve Kategori Bilgileri
        t2.product_id,
        t6.product_category_name_english,
        
        -- Satış Metrikleri
        COUNT(DISTINCT t1.order_id) AS total_sales_count, -- Toplam satış adedi
        SUM(t2.price) AS total_monetary, -- Toplam parasal değer
        AVG(t2.price) AS average_price, -- Ortalama fiyat
        
        -- Yorum Metrikleri
        AVG(t4.review_score) AS average_review_score, -- Ortalama yorum skoru (Performans)
        COUNT(t4.review_id) AS total_review_count, -- Toplam yorum adedi
        
      FROM 
        `stone-arch-474621-h4.project_dataset.olist_orders_dataset` AS t1
    INNER JOIN 
        `stone-arch-474621-h4.project_dataset.olist_order_items_dataset` AS t2 ON t1.order_id = t2.order_id
    INNER JOIN 
        `stone-arch-474621-h4.project_dataset.olist_products_dataset` AS t5 ON t2.product_id = t5.product_id
    INNER JOIN 
        `stone-arch-474621-h4.project_dataset.olist_product_category_name_translation` AS t6 ON t5.product_category_name = t6.product_category_name
    LEFT JOIN 
        `stone-arch-474621-h4.project_dataset.olist_order_reviews_dataset` AS t4 ON t1.order_id = t4.order_id 
        
    WHERE 
        t1.order_status = 'delivered' 
        AND t2.price > 0
        
    GROUP BY 
        1, 2 -- Ürün ID'si ve Kategoriye göre gruplama
)
-- 2. ANA SORGULAR: Analiz sorularına göre sıralama yapar
SELECT 
    product_category_name_english,
    product_id,
    total_sales_count,
    total_monetary,
    average_review_score,
    total_review_count,
FROM 
    ProductPerformance
-- En çok satan ürünleri ve en iyi performans gösterenleri görmek için bu kısmı kullanın:
ORDER BY 
    total_sales_count DESC, -- 1. En çok satanları belirler
    total_monetary DESC,    -- 2. Parasal ağırlığı en yüksek olanları belirler
    average_review_score DESC -- 3. Yorum skoruna göre sıralar (en iyi performansı gösterenler)
LIMIT 100;


--------------------------------------------------------------------
WITH sub AS (
    
    SELECT 
        t2.price,
        t2.freight_value,
        t3.customer_state,
        t4.review_score,
        -- answer_time_day hesaplaması
        DATE_DIFF(t4.review_answer_timestamp, t4.review_creation_date, DAY) AS answer_time_day,
        t6.product_category_name_english
    FROM 
        `stone-arch-474621-h4.project_dataset.olist_orders_dataset` AS t1
    INNER JOIN 
        `stone-arch-474621-h4.project_dataset.olist_order_items_dataset` AS t2
        ON t1.order_id = t2.order_id
    INNER JOIN 
        `stone-arch-474621-h4.project_dataset.olist_customers_dataset` AS t3
        ON t1.customer_id = t3.customer_id
    INNER JOIN 
        `stone-arch-474621-h4.project_dataset.olist_order_reviews_dataset` AS t4
        ON t1.order_id = t4.order_id 
    INNER JOIN `stone-arch-474621-h4.project_dataset.olist_products_dataset` AS t5
    ON t2.product_id = t5.product_id
    INNER JOIN `stone-arch-474621-h4.project_dataset.olist_product_category_name_translation` AS t6
    ON t5.product_category_name = t6.product_category_name
    WHERE 
        t1.order_status = 'delivered' 
        AND t2.price > 0 -- Sıfıra bölme hatasını önler
)
-- 2. Ana Sorgu: Eyalet bazında toplama (aggregation) yapar
SELECT 
    customer_state,
    SUM(price) AS total_price,
    AVG(freight_value / price) AS avg_cargo_ratio,
    AVG(review_score) AS avg_score,
    AVG(answer_time_day) AS avg_answer_time_day -- Ortalama cevaplama süresi
FROM 
    sub
GROUP BY 
    customer_state
ORDER BY 
    total_price DESC

--------------------------


WITH CategoryMetrics AS (
    -- Tüm eyaletler ve kategoriler için toplamları hesaplar
    SELECT 
        t3.customer_state,
        t6.product_category_name_english,
        SUM(t2.price) AS category_monetary, -- Kategori bazlı parasal ağırlık
        COUNT(t1.order_id) AS category_count, -- Kategori bazlı adet (order_id üzerinden)
        t2.price,
        t2.freight_value,
        t4.review_score,
        DATE_DIFF(t4.review_answer_timestamp, t4.review_creation_date, DAY) AS answer_time_day
    FROM 
        `stone-arch-474621-h4.project_dataset.olist_orders_dataset` AS t1
    INNER JOIN 
        `stone-arch-474621-h4.project_dataset.olist_order_items_dataset` AS t2 ON t1.order_id = t2.order_id
    INNER JOIN 
        `stone-arch-474621-h4.project_dataset.olist_customers_dataset` AS t3 ON t1.customer_id = t3.customer_id
    INNER JOIN 
        `stone-arch-474621-h4.project_dataset.olist_order_reviews_dataset` AS t4 ON t1.order_id = t4.order_id 
    INNER JOIN 
        `stone-arch-474621-h4.project_dataset.olist_products_dataset` AS t5 ON t2.product_id = t5.product_id -- Tablo adı düzeltildi
    INNER JOIN 
        `stone-arch-474621-h4.project_dataset.olist_product_category_name_translation` AS t6 ON t5.product_category_name = t6.product_category_name
    WHERE 
        t1.order_status = 'delivered' 
        AND t2.price > 0
    GROUP BY 
        1, 2, t2.price, t2.freight_value, t4.review_score, t4.review_answer_timestamp, t4.review_creation_date
),

RankedCategories AS (
    -- 2. CTE: Her eyalet içindeki kategorileri parasal değer ve adede göre sıralar
    SELECT
        *,
        -- Parasal ağırlığa göre sıralama
        ROW_NUMBER() OVER(PARTITION BY customer_state ORDER BY category_monetary DESC) AS monetary_rank,
        -- Satış adedine göre sıralama
        ROW_NUMBER() OVER(PARTITION BY customer_state ORDER BY category_count DESC) AS count_rank
    FROM 
        CategoryMetrics
),

StateAggregates AS (
    -- 3. CTE: Eyalet bazında temel toplam ve ortalama metrikleri hesaplar
    SELECT
        customer_state,
        SUM(price) AS total_price,
        AVG(freight_value / price) AS avg_cargo_ratio,
        AVG(review_score) AS avg_score,
        AVG(answer_time_day) AS avg_answer_time_day
    FROM
        CategoryMetrics
    GROUP BY
        customer_state
)

-- 4. ANA SORGULAR: Temel metrikleri en iyi kategorilerle birleştirir
SELECT 
    sa.customer_state,
    sa.total_price,
    sa.avg_cargo_ratio,
    sa.avg_score,
    sa.avg_answer_time_day,
    -- Parasal ağırlığı en yüksek kategori
    MAX(CASE WHEN rc_monetary.monetary_rank = 1 THEN rc_monetary.product_category_name_english END) AS most_monetary_category,
    -- Satış adedi en yüksek kategori
    MAX(CASE WHEN rc_count.count_rank = 1 THEN rc_count.product_category_name_english END) AS most_counted_category
FROM 
    StateAggregates AS sa
-- Parasal ağırlık için birleştirme (Rank=1 olan kategoriyi bulmak için)
LEFT JOIN 
    RankedCategories AS rc_monetary
    ON sa.customer_state = rc_monetary.customer_state AND rc_monetary.monetary_rank = 1
-- Adet için birleştirme
LEFT JOIN 
    RankedCategories AS rc_count
    ON sa.customer_state = rc_count.customer_state AND rc_count.count_rank = 1
GROUP BY
    1, 2, 3, 4, 5
ORDER BY 
    sa.total_price DESC












--EDA------------------

--order_id PK olabilir.
SELECT 
count(order_id), count(distinct order_id)
--order_id
FROM `stone-arch-474621-h4.project_dataset.olist_orders_dataset` 
--99441 -  99441  unique
--where order_id is null  NO

--customer_id PK olabilir.
SELECT 
--count(customer_id), count(distinct customer_id)
customer_id
FROM `stone-arch-474621-h4.project_dataset.olist_customers_dataset` 
--99441 -  99441  unique
--where customer_id is null    NO 


--aynı sipariş için birden fazla yorum yapılmış
--99224 -  98673   NOT unique
--547  1 time duplicated
--4    2 time duplicated
--where order_id is null  NO 

