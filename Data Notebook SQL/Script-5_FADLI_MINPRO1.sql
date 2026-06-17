-- ================================================================
-- 	MOCH FADLILAH RAHMADI
-- 	TUGAS MINPRO SQL-1
--  OLIST E-COMMERCE — BRAZIL SQL ANALYSIS
--  Dataset : olist_customers | olist_orders | olist_order_payments
--  Rows    : 15.000 per tabel
-- 	Alasan	: Tabel customers, orders, dan order_payments dipilih karena ketiganya merepresentasikan proses utama
-- dalam bisnis e-commerce, yaitu pelanggan, transaksi pemesanan, dan pembayaran. 
-- Ketiga tabel memiliki hubungan relasional yang memungkinkan analisis menyeluruh terhadap perilaku pelanggan, performa pengiriman, 
-- serta pola pembayaran transaksi.
-- ================================================================
 
 
-- ================================================================

-- SECTION 1 : DATABASE SETUP & DATA IMPORT

-- ================================================================
 
-- ------------------------------------------------------------
-- 1.1  Buat database (jalankan via postgresql terminal)
-- ------------------------------------------------------------
-- CREATE DATABASE baru dengan nama minpro1
 
-- ------------------------------------------------------------
-- 1.2  Buat tabel dengan Primary Key & tipe data yang tepat
-- ------------------------------------------------------------
DROP TABLE IF EXISTS order_payments;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;
 
CREATE TABLE customers (
    customer_id              VARCHAR(50)   NOT NULL,
    customer_unique_id       VARCHAR(50)   NOT NULL,
    customer_zip_code_prefix INT,
    customer_city            VARCHAR(100),
    customer_state           CHAR(2),
    CONSTRAINT pk_customers PRIMARY KEY (customer_id)
);
 
CREATE TABLE orders (
    order_id                        VARCHAR(50)  NOT NULL,
    customer_id                     VARCHAR(50)  NOT NULL,
    order_status                    VARCHAR(30),
    order_purchase_timestamp        TIMESTAMP,
    order_approved_at               TIMESTAMP,
    order_delivered_carrier_date    TIMESTAMP,
    order_delivered_customer_date   TIMESTAMP,
    order_estimated_delivery_date   TIMESTAMP,
    CONSTRAINT pk_orders            PRIMARY KEY (order_id),
    CONSTRAINT fk_orders_customer   FOREIGN KEY (customer_id)
                                    REFERENCES customers(customer_id)
);
 
CREATE TABLE order_payments (
    order_id             VARCHAR(50)    NOT NULL,
    payment_sequential   INT            NOT NULL,
    payment_type         VARCHAR(30),
    payment_installments INT,
    payment_value        NUMERIC(12,2),
    CONSTRAINT pk_payments          PRIMARY KEY (order_id, payment_sequential),
    CONSTRAINT fk_payments_order    FOREIGN KEY (order_id)
                                    REFERENCES orders(order_id)
);
 
-- ------------------------------------------------------------
-- 1.3  Import data via DBeaver
--      Klik kanan tabel → Import Data → pilih CSV file yang ingin digunakan→ Selesai

-- ------------------------------------------------------------
 
-- ------------------------------------------------------------
-- 1.4  Cek struktur tabel (information_schema)
-- ------------------------------------------------------------
SELECT
    table_name,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
        'customers',
        'orders',
        'order_payments'
      )
ORDER BY table_name, ordinal_position;
 
-- ------------------------------------------------------------
-- 1.5  Cek ukuran dataset setiap tabel
-- ------------------------------------------------------------
SELECT 'customers' AS nama_tabel, COUNT(*) AS jumlah_baris FROM customers
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_payments', COUNT(*) FROM order_payments;
 
-- ------------------------------------------------------------
-- 1.6  Cek tipe data & sample data
-- ------------------------------------------------------------
SELECT * FROM customers            LIMIT 5;
SELECT * FROM orders               LIMIT 5;
SELECT * FROM order_payments       LIMIT 5;
 
-- Cek Primary Key & Foreign Key di pg_constraint
SELECT
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    ccu.table_name  AS references_table,
    ccu.column_name AS references_column
FROM information_schema.table_constraints   tc
JOIN information_schema.key_column_usage    kcu
     ON tc.constraint_name = kcu.constraint_name
LEFT JOIN information_schema.constraint_column_usage ccu
     ON tc.constraint_name = ccu.constraint_name
WHERE tc.table_schema = 'public'
  AND tc.constraint_type IN ('PRIMARY KEY','FOREIGN KEY')
ORDER BY tc.table_name, tc.constraint_type;
 
 
-- ================================================================

-- SECTION 2 : DDL & DML PROCESS

-- ================================================================
 
-- ------------------------------------------------------------
-- 2.1  ALTER TABLE — tambah kolom baru
-- ------------------------------------------------------------
ALTER TABLE customers
    ADD COLUMN IF NOT EXISTS created_at   TIMESTAMP DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS is_active    BOOLEAN   DEFAULT TRUE;
 
ALTER TABLE orders
    ADD COLUMN IF NOT EXISTS delivery_days     INT,
    ADD COLUMN IF NOT EXISTS is_late_delivery  BOOLEAN;
 
ALTER table order_payments
    ADD COLUMN IF NOT EXISTS is_valid  BOOLEAN DEFAULT TRUE;
 
-- ------------------------------------------------------------
-- 2.2  ALTER TABLE — ubah tipe data kolom
-- ------------------------------------------------------------
ALTER TABLE customers
    ALTER COLUMN customer_state TYPE VARCHAR(10);
-- ------------------------------------------------------------
-- 2.3  ALTER TABLE — rename kolom
-- ------------------------------------------------------------
ALTER TABLE customers
    RENAME COLUMN customer_zip_code_prefix TO zip_code;
 
-- ------------------------------------------------------------
-- 2.4  ALTER TABLE — tambah constraint UNIQUE & NOT NULL
-- ------------------------------------------------------------ 
ALTER TABLE orders
    ALTER COLUMN order_purchase_timestamp SET NOT NULL;
 
ALTER TABLE order_payments
    ALTER COLUMN payment_value SET NOT NULL;
 
-- ------------------------------------------------------------
-- 2.5  INSERT — menambahkan data baru
-- ------------------------------------------------------------
INSERT INTO customers
    (customer_id, customer_unique_id, zip_code, customer_city, customer_state)
VALUES
    ('test_cust_001', 'test_uniq_001', 12345, 'São Paulo',      'SP'),
    ('test_cust_002', 'test_uniq_002', 20000, 'Rio de Janeiro', 'RJ'),
    ('test_cust_003', 'test_uniq_003', 30000, 'Belo Horizonte', 'MG');
 
-- Insert order untuk pelanggan test
INSERT INTO orders
    (order_id, customer_id, order_status, order_purchase_timestamp,
     order_approved_at, order_estimated_delivery_date)
VALUES
    ('test_order_001', 'test_cust_001', 'delivered',
     '2024-01-15 10:00:00', '2024-01-15 11:00:00', '2024-01-25 00:00:00'),
    ('test_order_002', 'test_cust_002', 'processing',
     '2024-01-16 09:00:00', NULL,                   '2024-01-28 00:00:00');
 
-- Insert payment untuk order test
INSERT INTO order_payments
    (order_id, payment_sequential, payment_type, payment_installments, payment_value)
VALUES
    ('test_order_001', 1, 'credit_card', 3,  250.00),
    ('test_order_002', 1, 'boleto',      1,  175.50);
 
-- ------------------------------------------------------------
-- 2.6  UPDATE — memperbarui data
-- ------------------------------------------------------------
-- Hitung delivery_days untuk order yang sudah terkirim
UPDATE orders
SET delivery_days = EXTRACT(DAY FROM
        (order_delivered_customer_date - order_purchase_timestamp))
WHERE order_delivered_customer_date IS NOT NULL;
 
-- Tandai order yang terlambat
UPDATE orders
SET is_late_delivery = (order_delivered_customer_date > order_estimated_delivery_date)
WHERE order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;
 
-- Standarisasi kota: Title Case
UPDATE customers
SET customer_city = INITCAP(customer_city);
 
-- Standarisasi state: UPPER
UPDATE customers
SET customer_state = UPPER(customer_state);
 
-- Ganti payment_type 'not_defined' jadi 'unknown'
UPDATE order_payments
SET payment_type = 'unknown'
WHERE payment_type = 'not_defined';
 
-- ------------------------------------------------------------
-- 2.7  DELETE — hapus data test
-- ------------------------------------------------------------
DELETE FROM order_payments
WHERE order_id IN ('test_order_001','test_order_002');
 
DELETE FROM orders
WHERE order_id IN ('test_order_001','test_order_002');
 
DELETE FROM customers
WHERE customer_id IN ('test_cust_001','test_cust_002','test_cust_003');
 
-- Verifikasi hasil DML
SELECT COUNT(*) AS total_customers  FROM customers;
SELECT COUNT(*) AS total_orders     FROM orders;
SELECT COUNT(*) AS total_payments   FROM order_payments;
 
 
-- ================================================================
-- SECTION 3 : DATA CLEANING
-- ================================================================
-- ------------------------------------------------------------
-- 3.1  Deteksi Missing Values
-- ------------------------------------------------------------
--==================================
-- MENGECEK MISSING VALUE (customers)
--==================================
SELECT 'customer_id' AS column_name,
	COUNT(*) filter (where customer_id IS NULL) as missing_count 
FROM customers 
union all
SELECT 'customer_unique_id',
	COUNT(*) filter (where customer_unique_id IS NULL)  
FROM customers 
union all
SELECT 'zip_code',
	COUNT(*) filter (where zip_code IS NULL)  
FROM customers 
union all
SELECT 'customer_city',
	COUNT(*) filter (where customer_city IS NULL)  
FROM customers 
union all
SELECT 'customer_state',
	COUNT(*) filter (where customer_state IS NULL)  
FROM customers ; 

----====================================================
-- MENGECEK MISSING VALUE (orders)
--======================================================
SELECT 'order_id' AS column_name,
	COUNT(*) filter (where order_id IS NULL) as missing_count 
FROM orders 
union all
SELECT 'customer_id',
	COUNT(*) filter (where customer_id IS NULL)  
FROM orders 
union all
SELECT 'order_status',
	COUNT(*) filter (where order_status IS NULL)  
FROM orders 
union all
SELECT 'order_purchase_timestamp',
	COUNT(*) filter (where order_purchase_timestamp IS NULL)  
FROM orders 
union all
SELECT 'order_approved_at',
	COUNT(*) filter (where order_approved_at IS NULL)  
FROM orders 
union all
SELECT 'order_delivered_carrier_date',
	COUNT(*) filter (where order_delivered_carrier_date IS NULL)  
FROM orders 
union all 
SELECT 'order_delivered_customer_date',
	COUNT(*) filter (where order_delivered_customer_date IS NULL)  
FROM orders 
union all 
SELECT 'order_estimated_delivery_date',
	COUNT(*) filter (where order_estimated_delivery_date IS NULL)  
FROM orders 
union all 
SELECT 'delivery_days',
	COUNT(*) filter (where delivery_days IS NULL)  
FROM orders;

----====================================================
-- MENGECEK MISSING VALUE (payments)
--======================================================
SELECT 'order_id' AS column_name,
	COUNT(*) filter (where order_id IS NULL) as missing_count 
FROM order_payments 
union all
SELECT 'payment_sequential',
	COUNT(*) filter (where payment_sequential IS NULL)  
FROM order_payments 
union all
SELECT 'payment_type',
	COUNT(*) filter (where payment_type IS NULL)  
FROM order_payments 
union all
SELECT 'payment_installments',
	COUNT(*) filter (where payment_installments IS NULL)  
FROM order_payments 
union all
SELECT 'payment_value',
	COUNT(*) filter (where payment_value IS NULL)  
FROM order_payments  ;

---=========================================================
--3.2 MENGECEK DUPLICATE--
----===========================================================
-- CUSTOMERS
SELECT customer_id, customer_unique_id, COUNT(*)
FROM customers
GROUP BY customer_id, customer_unique_id
HAVING COUNT(*) > 1;

-- ORDERS
SELECT order_id, COUNT(*)
FROM orders 
group by order_id
having COUNT(*) > 1;

-- PAYMENTS
SELECT order_id, payment_sequential, COUNT(*)
FROM order_payments
group by order_id, payment_sequential
having COUNT(*) > 1;

---=================================================================
--- 3.3 MENGECEK OUTLIERS--
---=================================================================
--OUTLIER KOLOM NUMERIK TABEL PAYMENTS
-- 1. Hitung Q1 dan Q3 untuk semua kolom numerik pada tabel payments sekaligus bersamaan
WITH stats AS (
    SELECT 
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY payment_sequential) AS seq_q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY payment_sequential) AS seq_q3,
        
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY payment_installments) AS inst_q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY payment_installments) AS inst_q3,
        
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY payment_value) AS val_q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY payment_value) AS val_q3
    FROM order_payments
),

-- 2. Hitung Lower Bound dan Upper Bound untuk semua kolom numerik pada tabel payments
bounds AS (
    SELECT
        (seq_q1 - 1.5 * (seq_q3 - seq_q1)) AS seq_lower,
        (seq_q3 + 1.5 * (seq_q3 - seq_q1)) AS seq_upper,
        
        (inst_q1 - 1.5 * (inst_q3 - inst_q1)) AS inst_lower,
        (inst_q3 + 1.5 * (inst_q3 - inst_q1)) AS inst_upper,
        
        (val_q1 - 1.5 * (val_q3 - val_q1)) AS val_lower,
        (val_q3 + 1.5 * (val_q3 - val_q1)) AS val_upper
    FROM stats
)

-- 3. Hitung total outlier masing-masing kolom numerik pada tabel payments dalam satu baris dengan output horizontal
-- Disini menggunakan SUM(CASE WHEN) karena mengecek outlier banyak kolom sekaligus dalam satu query
-- Jika COUNT(*) WHERE itu digunakan jika hanya mengecek 1 kolom saja seperti diatas
SELECT
    SUM(CASE WHEN p.payment_sequential < b.seq_lower OR p.payment_sequential > b.seq_upper THEN 1 ELSE 0 END) AS outlier_payment_sequential,
    SUM(CASE WHEN p.payment_installments < b.inst_lower OR p.payment_installments > b.inst_upper THEN 1 ELSE 0 END) AS outlier_payment_installments,
    SUM(CASE WHEN p.payment_value < b.val_lower OR p.payment_value > b.val_upper THEN 1 ELSE 0 END) AS outlier_payment_value
FROM order_payments p
CROSS JOIN bounds b;

--- OUTLIERS KOLOM NUMERIK TABEL ORDERS
-- =========================================================
-- OUTLIER DETAIL : delivery_days
-- =========================================================

WITH stats AS (
    SELECT
        PERCENTILE_CONT(0.25)
            WITHIN GROUP (ORDER BY delivery_days) AS q1,

        PERCENTILE_CONT(0.75)
            WITHIN GROUP (ORDER BY delivery_days) AS q3
    FROM orders
    WHERE delivery_days IS NOT NULL
),

bounds AS (
    SELECT
        (q1 - 1.5 * (q3 - q1)) AS lower_bound,
        (q3 + 1.5 * (q3 - q1)) AS upper_bound
    FROM stats
)

SELECT
    SUM(CASE WHEN o.delivery_days < b.lower_bound OR o.delivery_days > b.upper_bound THEN 1 ELSE 0 END) AS outlier_deliver_days
FROM orders o
CROSS JOIN bounds b ;

-- ------------------------------------------------------------
-- 3.4  Deteksi Data Inconsistency
-- ------------------------------------------------------------
-- Order status 'delivered' tapi tanggal pengiriman NULL (data error)
SELECT order_id, order_status, order_delivered_customer_date
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;
 
-- Nilai payment negatif atau nol (anomali)
SELECT *
FROM order_payments
WHERE payment_value < 0
   OR (payment_value = 0 AND payment_type != 'unknown');
 
-- Tanggal pengiriman lebih awal dari tanggal pembelian (mustahil)
SELECT order_id, order_purchase_timestamp, order_delivered_customer_date
FROM orders
WHERE order_delivered_customer_date < order_purchase_timestamp;
 
-- Distribusi payment_type (cek nilai tidak lazim)
SELECT payment_type, COUNT(*) AS jumlah
FROM order_payments
GROUP BY payment_type
ORDER BY jumlah DESC;


-- ------------------------------------------------------------
-- 3.4  Handling Missing Values dengan COALESCE
-- ------------------------------------------------------------
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    -- Jika approved_at NULL, anggap 1 hari setelah purchase
    COALESCE(
        order_approved_at,
        order_purchase_timestamp + INTERVAL '1 day'
    ) AS order_approved_at_clean,
    -- Jika carrier date NULL, tampilkan teks deskriptif
    COALESCE(
        TO_CHAR(order_delivered_carrier_date, 'YYYY-MM-DD HH24:MI'),
        'Belum Dikirim ke Carrier'
    ) AS carrier_date_clean,
    -- Jika delivered date NULL, tampilkan teks deskriptif
    COALESCE(
        TO_CHAR(order_delivered_customer_date, 'YYYY-MM-DD HH24:MI'),
        'Belum Sampai ke Pelanggan'
    ) AS delivered_date_clean
FROM orders
LIMIT 20;

---=====================================================================
--- 3.5 PERBANDINGAN DATA YANG SUDAH DI CLEANING DAN BELUM
---=====================================================================
SELECT

    -- APPROVED AT
    COUNT(*) FILTER (
        WHERE order_approved_at IS NULL
    ) AS before_cleaning_approved,

    COUNT(*) FILTER (
        WHERE COALESCE(
            order_approved_at,
            order_purchase_timestamp + INTERVAL '1 day'
        ) IS NULL
    ) AS after_cleaning_approved,

    -- CARRIER DATE
    COUNT(*) FILTER (
        WHERE order_delivered_carrier_date IS NULL
    ) AS before_cleaning_carrier,

    COUNT(*) FILTER (
        WHERE COALESCE(
            TO_CHAR(order_delivered_carrier_date, 'YYYY-MM-DD HH24:MI'),
            'Belum Dikirim ke Carrier'
        ) IS NULL
    ) AS after_cleaning_carrier,

    -- DELIVERED DATE
    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NULL
    ) AS before_cleaning_delivered,

    COUNT(*) FILTER (
        WHERE COALESCE(
            TO_CHAR(order_delivered_customer_date, 'YYYY-MM-DD HH24:MI'),
            'Belum Sampai ke Pelanggan'
        ) IS NULL
    ) AS after_cleaning_delivered

FROM orders;

-- ================================================================
-- SECTION 4 : BASIC SQL QUERY
-- ================================================================
 
-- ------------------------------------------------------------
-- 4.1  SELECT dasar — tampilkan semua kolom + filter state
-- ------------------------------------------------------------
SELECT
    customer_id,
    customer_unique_id,
    zip_code,
    customer_city,
    customer_state
FROM customers
WHERE customer_state = 'SP'
ORDER BY customer_city ASC
LIMIT 20;
 
-- 4.2  WHERE dengan multiple operator logika
-- Order dengan nilai tinggi menggunakan credit card / boleto, sudah delivered
SELECT
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp,
    p.payment_type,
    p.payment_installments,
    p.payment_value
FROM orders o
JOIN order_payments p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
  AND p.payment_value > 200
  AND p.payment_type IN ('credit_card', 'boleto')
  AND p.payment_installments >= 3
ORDER BY p.payment_value DESC
LIMIT 20;
 
-- Order yang dibatalkan atau tidak tersedia di tahun 2018
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp::DATE AS tanggal
FROM orders
WHERE order_status IN ('canceled', 'unavailable')
  AND EXTRACT(YEAR FROM order_purchase_timestamp) = 2018
ORDER BY order_purchase_timestamp DESC;
 
-- ------------------------------------------------------------
-- 4.3  ORDER BY — sorting multi-kolom
-- ------------------------------------------------------------
SELECT
    c.customer_state,
    c.customer_city,
    o.order_id,
    p.payment_value
FROM customers c
JOIN orders o         ON c.customer_id = o.customer_id
JOIN order_payments p ON o.order_id    = p.order_id
WHERE o.order_status = 'delivered'
ORDER BY
    c.customer_state   ASC,
    c.customer_city    ASC,
    p.payment_value    DESC
LIMIT 30;
 
-- ------------------------------------------------------------
-- 4.4  GROUP BY — ringkasan per payment_type
-- ------------------------------------------------------------
SELECT
    payment_type,
    COUNT(*)                           AS total_transaksi,
    COUNT(DISTINCT order_id)           AS total_order_unik,
    SUM(payment_value)                 AS total_revenue,
    ROUND(AVG(payment_value),  2)      AS rata_rata_nilai,
    MIN(payment_value)                 AS nilai_minimum,
    MAX(payment_value)                 AS nilai_maksimum,
    ROUND(AVG(payment_installments),1) AS rata_cicilan
FROM order_payments
WHERE payment_type != 'unknown'
GROUP BY payment_type
ORDER BY total_revenue DESC;
 
-- ------------------------------------------------------------
-- 4.5  HAVING — filter setelah GROUP BY
-- ------------------------------------------------------------
-- State dengan lebih dari 500 pelanggan
SELECT
    customer_state,
    COUNT(DISTINCT customer_id)  AS jumlah_pelanggan,
    COUNT(DISTINCT customer_city) AS jumlah_kota
FROM customers
GROUP BY customer_state
HAVING COUNT(DISTINCT customer_id) > 500
ORDER BY jumlah_pelanggan DESC;
 
-- State dengan rata-rata nilai order di atas rata-rata nasional
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id)       AS total_order,
    ROUND(AVG(p.payment_value), 2)   AS avg_order_value
FROM customers c
JOIN orders o         ON c.customer_id = o.customer_id
JOIN order_payments p ON o.order_id    = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
HAVING AVG(p.payment_value) > (SELECT AVG(payment_value) FROM order_payments)
ORDER BY avg_order_value DESC;
 
-- ------------------------------------------------------------
-- 4.6  6 Aggregate Functions dalam satu query
-- ------------------------------------------------------------
SELECT
    o.order_status,
    COUNT(DISTINCT o.order_id)           AS count_order,       -- COUNT
    COUNT(DISTINCT o.customer_id)        AS count_customer,    -- COUNT DISTINCT
    SUM(p.payment_value)                 AS sum_revenue,       -- SUM
    ROUND(AVG(p.payment_value), 2)       AS avg_value,         -- AVG
    MIN(p.payment_value)                 AS min_value,         -- MIN
    MAX(p.payment_value)                 AS max_value          -- MAX
FROM orders o
JOIN order_payments p ON o.order_id = p.order_id
GROUP BY o.order_status
ORDER BY sum_revenue DESC NULLS LAST;
 
-- ------------------------------------------------------------
-- 4.7  Analisis order per bulan (GROUP BY + date functions)
-- ------------------------------------------------------------
SELECT
    TO_CHAR(order_purchase_timestamp, 'YYYY-MM') AS bulan,
    EXTRACT(YEAR FROM order_purchase_timestamp)  AS tahun,
    EXTRACT(MONTH FROM order_purchase_timestamp) AS no_bulan,
    COUNT(DISTINCT order_id)                     AS total_order,
    COUNT(DISTINCT customer_id)                  AS unik_pelanggan
FROM orders
GROUP BY bulan, tahun, no_bulan
ORDER BY bulan;

-- ================================================================
-- SECTION 5 : INTERMEDIATE SQL QUERY
-- ================================================================
 
-- ------------------------------------------------------------
-- 5.1  CASE WHEN — segmentasi nilai transaksi
-- ------------------------------------------------------------
SELECT
    order_id,
    payment_type,
    payment_value,
    payment_installments,
    CASE
        WHEN payment_value >= 500  THEN 'High Value (≥ R$500)'
        WHEN payment_value >= 200  THEN 'Medium Value (R$200–499)'
        WHEN payment_value >= 50   THEN 'Low Value (R$50–199)'
        ELSE                            'Micro Value (< R$50)'
    END AS value_segment,
    CASE
        WHEN payment_installments = 1           THEN 'Bayar Lunas'
        WHEN payment_installments BETWEEN 2 AND 3 THEN 'Cicil Pendek (2–3x)'
        WHEN payment_installments BETWEEN 4 AND 6 THEN 'Cicil Menengah (4–6x)'
        ELSE                                         'Cicil Panjang (>6x)'
    END AS installment_category,
    CASE
        WHEN payment_type = 'credit_card' THEN 'Kartu Kredit'
        WHEN payment_type = 'boleto'      THEN 'Transfer Bank'
        WHEN payment_type = 'debit_card'  THEN 'Kartu Debit'
        WHEN payment_type = 'voucher'     THEN 'Voucher/Diskon'
        ELSE                                   'Tidak Diketahui'
    END AS metode_bayar_indo
FROM order_payments
WHERE payment_type != 'unknown'
ORDER BY payment_value DESC
LIMIT 30;
 
-- Ringkasan per segmen nilai
SELECT
    CASE
        WHEN payment_value >= 500  THEN 'High Value'
        WHEN payment_value >= 200  THEN 'Medium Value'
        WHEN payment_value >= 50   THEN 'Low Value'
        ELSE                            'Micro Value'
    END AS value_segment,
    COUNT(*)                         AS jumlah_transaksi,
    ROUND(SUM(payment_value),  2)    AS total_revenue,
    ROUND(AVG(payment_value),  2)    AS avg_value
FROM order_payments
GROUP BY value_segment
ORDER BY avg_value DESC;
 
-- ------------------------------------------------------------
-- 5.2  INNER JOIN — order + customer + payment
-- ------------------------------------------------------------
SELECT
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    o.order_id,
    o.order_status,
    TO_CHAR(o.order_purchase_timestamp, 'YYYY-MM-DD') AS tanggal_beli,
    p.payment_type,
    p.payment_installments,
    p.payment_value
FROM customers c
INNER JOIN orders o          ON c.customer_id = o.customer_id
INNER JOIN order_payments p  ON o.order_id    = p.order_id
WHERE o.order_status = 'delivered'
ORDER BY o.order_purchase_timestamp DESC
LIMIT 20;
 
-- ------------------------------------------------------------
-- 5.3  LEFT JOIN — semua customer termasuk yang belum order
-- ------------------------------------------------------------
SELECT
    c.customer_id,
    c.customer_city,
    c.customer_state,
    COUNT(o.order_id)               AS total_order,
    COALESCE(SUM(p.payment_value), 0) AS total_belanja
FROM customers c
LEFT JOIN orders o          ON c.customer_id = o.customer_id
LEFT JOIN order_payments p  ON o.order_id    = p.order_id
GROUP BY c.customer_id, c.customer_city, c.customer_state
ORDER BY total_belanja DESC
LIMIT 20;
 
-- Hanya pelanggan yang BELUM pernah order (NULL dari LEFT JOIN)
SELECT
    c.customer_id,
    c.customer_city,
    c.customer_state
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;
 
-- ------------------------------------------------------------
-- 5.4  RIGHT JOIN — semua order (termasuk anomali tanpa customer)
-- ------------------------------------------------------------
SELECT
    c.customer_city,
    c.customer_state,
    o.order_id,
    o.order_status,
    TO_CHAR(o.order_purchase_timestamp,'YYYY-MM-DD') AS tanggal
FROM customers c
RIGHT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'canceled'
ORDER BY o.order_purchase_timestamp DESC;
 
-- ------------------------------------------------------------
-- 5.5  FULL JOIN — deteksi ketidakcocokan data (orphan records)
-- ------------------------------------------------------------
SELECT
    o.order_id    AS order_id_from_orders,
    p.order_id    AS order_id_from_payments,
    o.order_status,
    p.payment_type,
    p.payment_value,
    CASE
        WHEN o.order_id IS NULL THEN 'Payment tanpa Order'
        WHEN p.order_id IS NULL THEN 'Order tanpa Payment'
        ELSE 'OK'
    END AS integrity_status
FROM orders o
FULL OUTER JOIN order_payments p ON o.order_id = p.order_id
WHERE o.order_id IS NULL OR p.order_id IS NULL
LIMIT 20;
 
-- ------------------------------------------------------------
-- 5.6  UNION ALL — gabungkan ringkasan per kategori status
-- ------------------------------------------------------------
SELECT 'DELIVERED'   AS status_kategori, COUNT(*) AS jumlah
FROM orders WHERE order_status = 'delivered'
UNION ALL
SELECT 'CANCELED',COUNT(*)
FROM orders WHERE order_status = 'canceled'
UNION ALL
SELECT 'SHIPPED', COUNT(*)
FROM orders WHERE order_status = 'shipped'
UNION ALL
SELECT 'PROCESSING', COUNT(*)
FROM orders WHERE order_status = 'processing'
UNION ALL
SELECT 'INVOICED', COUNT(*)
FROM orders WHERE order_status = 'invoiced'
UNION ALL
SELECT 'UNAVAILABLE',COUNT(*)
FROM orders WHERE order_status = 'unavailable'
UNION ALL
SELECT '─── TOTAL ───', COUNT(*)
FROM orders;
 
-- ------------------------------------------------------------
-- 5.7  UNION (distinct) — kota dari dua state berbeda
-- ------------------------------------------------------------
SELECT customer_city, 'SP' AS asal_state
FROM customers WHERE customer_state = 'SP'
UNION
SELECT customer_city, 'RJ'
FROM customers WHERE customer_state = 'RJ'
ORDER BY customer_city;
 
-- ------------------------------------------------------------
-- 5.8  Subquery di WHERE — pelanggan dengan belanja di atas rata-rata
-- ------------------------------------------------------------
SELECT
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    SUM(p.payment_value) AS total_belanja
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_payments p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id, c.customer_city, c.customer_state
HAVING SUM(p.payment_value) > (
    -- Subquery: rata-rata total belanja semua pelanggan
    SELECT AVG(total_per_customer)
    FROM (
        SELECT c2.customer_id, SUM(p2.payment_value) AS total_per_customer
        FROM customers c2
        JOIN orders o2 ON c2.customer_id = o2.customer_id
        JOIN order_payments p2 ON o2.order_id = p2.order_id
        WHERE o2.order_status = 'delivered'
        GROUP BY c2.customer_id
    ) sub_avg
)
ORDER BY total_belanja DESC
LIMIT 20;
 
-- ------------------------------------------------------------
-- 5.9  Subquery di SELECT — bandingkan avg per tipe vs nasional
-- ------------------------------------------------------------
SELECT
    payment_type,
    COUNT(*) AS total_transaksi,
    ROUND(AVG(payment_value), 2) AS avg_tipe,
    ROUND(
        (SELECT AVG(payment_value) FROM order_payments
         WHERE payment_type != 'unknown'), 2) AS avg_nasional,
    ROUND(
        AVG(payment_value)
        - (SELECT AVG(payment_value) FROM order_payments
           WHERE payment_type != 'unknown'), 2) AS selisih_vs_nasional,
    CASE
        WHEN AVG(payment_value) > (SELECT AVG(payment_value)
                                   FROM order_payments
                                   WHERE payment_type != 'unknown')
            THEN 'Di atas rata-rata'
        ELSE 'Di bawah rata-rata'
    END AS posisi_vs_nasional
FROM order_payments
WHERE payment_type != 'unknown'
GROUP BY payment_type
ORDER BY avg_tipe DESC;
 
-- ------------------------------------------------------------
-- 5.10  Subquery di FROM — top 5 state berdasarkan revenue
-- ------------------------------------------------------------
SELECT
    state_summary.customer_state,
    state_summary.total_pelanggan,
    state_summary.total_order,
    state_summary.total_revenue,
    state_summary.avg_order_value
FROM (
    SELECT
        c.customer_state,
        COUNT(DISTINCT c.customer_id) AS total_pelanggan,
        COUNT(DISTINCT o.order_id)  AS total_order,
        ROUND(SUM(p.payment_value), 2) AS total_revenue,
        ROUND(AVG(p.payment_value), 2) AS avg_order_value
    from customers c
    JOIN orders o         ON c.customer_id = o.customer_id
    JOIN order_payments p ON o.order_id    = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_state
) AS state_summary
ORDER BY total_revenue DESC
LIMIT 5;

-- ================================================================
-- SECTION 6 : ADVANCED SQL ANALYSIS
-- ================================================================
 
-- ------------------------------------------------------------
-- 6.1  ROW_NUMBER, RANK, DENSE_RANK per state
-- ------------------------------------------------------------
SELECT
    c.customer_state,
    o.order_id,
    ROUND(SUM(p.payment_value), 2) AS order_value,
    ROW_NUMBER() OVER (
        PARTITION BY c.customer_state
        ORDER BY SUM(p.payment_value) DESC
    ) AS row_num,
    RANK() OVER (
        PARTITION BY c.customer_state
        ORDER BY SUM(p.payment_value) DESC
    ) AS rank_val,
    DENSE_RANK() OVER (
        PARTITION BY c.customer_state
        ORDER BY SUM(p.payment_value) DESC
    ) AS dense_rank_val
FROM customers c
JOIN orders o  ON c.customer_id = o.customer_id
JOIN order_payments p ON o.order_id = p.order_id
WHERE c.customer_state IN ('SP','RJ','MG')
GROUP BY c.customer_state, o.order_id
ORDER BY c.customer_state, order_value DESC;
 
-- ------------------------------------------------------------
-- 6.2  LEAD & LAG — tren order & revenue bulanan
-- ------------------------------------------------------------
WITH monthly_stats AS (
    SELECT
        TO_CHAR(o.order_purchase_timestamp, 'YYYY-MM') AS bulan,
        COUNT(DISTINCT o.order_id) AS total_order,
        ROUND(SUM(p.payment_value), 2) AS total_revenue
    FROM orders o
    JOIN order_payments p ON o.order_id = p.order_id
    GROUP BY bulan
)
SELECT
    bulan,
    total_order,
    total_revenue,
    LAG(total_order,1) OVER (ORDER BY bulan) AS order_bulan_lalu,
    LEAD(total_order,1) OVER (ORDER BY bulan) AS order_bulan_depan,
    total_order - LAG(total_order, 1) OVER (ORDER BY bulan) AS delta_order,
    LAG(total_revenue, 1) OVER (ORDER BY bulan) AS revenue_bulan_lalu,
    ROUND(
        (total_revenue - LAG(total_revenue,1) OVER (ORDER BY bulan))
        / NULLIF(LAG(total_revenue,1) OVER (ORDER BY bulan), 0)* 100, 2) AS pct_growth_revenue
FROM monthly_stats
ORDER BY bulan;
 
-- ------------------------------------------------------------
-- 6.3  SUM OVER — Cumulative / Running Total
-- ------------------------------------------------------------
WITH monthly_revenue AS (
    SELECT
        TO_CHAR(o.order_purchase_timestamp, 'YYYY-MM') AS bulan,
        ROUND(SUM(p.payment_value), 2) AS rev_bulanan
    FROM orders o
    JOIN order_payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY bulan
)
SELECT
    bulan,
    rev_bulanan,
    ROUND(SUM(rev_bulanan) OVER (ORDER BY bulan
                                  ROWS BETWEEN UNBOUNDED PRECEDING
                                  AND CURRENT ROW), 2) AS kumulatif_revenue,
    ROUND(AVG(rev_bulanan) OVER (ORDER BY bulan
                                  ROWS BETWEEN 2 PRECEDING
                                  AND CURRENT ROW), 2) AS moving_avg_3bln,
    ROUND(rev_bulanan
          / SUM(rev_bulanan) OVER ()
          * 100, 2) AS pct_dari_total
FROM monthly_revenue
ORDER BY bulan;
 
-- ------------------------------------------------------------
-- 6.4  PARTITION BY + OVER — ranking order per customer
-- ------------------------------------------------------------
SELECT
    c.customer_unique_id,
    o.order_id,
    o.order_purchase_timestamp::DATE  AS tanggal,
    p.payment_value,
    ROW_NUMBER() OVER (
        PARTITION BY c.customer_unique_id
        ORDER BY o.order_purchase_timestamp
    ) AS urutan_order,
    SUM(p.payment_value) OVER (
        PARTITION BY c.customer_unique_id
        ORDER BY o.order_purchase_timestamp
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS kumulatif_per_customer
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_payments p ON o.order_id = p.order_id
ORDER BY c.customer_unique_id, urutan_order
LIMIT 30;
 
-- ------------------------------------------------------------
-- 6.5  CTE — Top-10 Pelanggan berdasarkan total belanja
-- ------------------------------------------------------------
WITH customer_spending AS (
    -- CTE 1: hitung metrik per pelanggan
    SELECT
        c.customer_unique_id,
        c.customer_city,
        c.customer_state,
        COUNT(DISTINCT o.order_id) AS total_order,
        ROUND(SUM(p.payment_value), 2) AS total_spent,
        ROUND(AVG(p.payment_value), 2) AS avg_per_order,
        MIN(o.order_purchase_timestamp::DATE) AS first_order,
        MAX(o.order_purchase_timestamp::DATE) AS last_order
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, c.customer_city, c.customer_state
),
ranked_customers AS (
    -- CTE 2: tambahkan ranking
    SELECT
        *,
        RANK() OVER (ORDER BY total_spent DESC)  AS rank_by_spent,
        RANK() OVER (ORDER BY total_order DESC)  AS rank_by_freq,
        NTILE(4) OVER (ORDER BY total_spent DESC)  AS kuartil_spent
    FROM customer_spending
)
SELECT *
FROM ranked_customers
WHERE rank_by_spent <= 10
ORDER BY rank_by_spent;
 
-- ------------------------------------------------------------
-- 6.6  CTE Berantai — Delivery Performance Analysis
-- ------------------------------------------------------------
WITH base AS (
    -- CTE 1: gabungkan tabel
    SELECT
        o.order_id,
        c.customer_state,
        o.order_status,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        ROUND(SUM(p.payment_value), 2) AS order_value
    FROM orders o
    JOIN customers c      ON o.customer_id = c.customer_id
    JOIN order_payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY
        o.order_id, c.customer_state, o.order_status,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
),
delivery_metrics AS (
    -- CTE 2: hitung metrik pengiriman
    SELECT
        *,
        EXTRACT(DAY FROM
            order_delivered_customer_date - order_purchase_timestamp
        )::INT                                                  AS actual_days,
        EXTRACT(DAY FROM
            order_estimated_delivery_date - order_purchase_timestamp
        )::INT                                                  AS estimated_days,
        CASE
            WHEN order_delivered_customer_date
                 <= order_estimated_delivery_date THEN 'Tepat Waktu'
            ELSE 'Terlambat'
        END                                                     AS delivery_status
    FROM base
),
summary AS (
    -- CTE 3: ringkasan per state & status pengiriman
    SELECT
        customer_state,
        delivery_status,
        COUNT(*)                        AS jumlah_order,
        ROUND(AVG(actual_days), 1)      AS avg_hari_aktual,
        ROUND(AVG(estimated_days), 1)   AS avg_hari_estimasi,
        ROUND(AVG(order_value), 2)      AS avg_nilai_order,
        MIN(actual_days)                AS min_hari,
        MAX(actual_days)                AS max_hari
    FROM delivery_metrics
    GROUP BY customer_state, delivery_status
)
SELECT
    *,
    ROUND(jumlah_order * 100.0
          / SUM(jumlah_order) OVER (PARTITION BY customer_state), 2) AS pct_dalam_state,
    RANK() OVER (
        PARTITION BY delivery_status
        ORDER BY jumlah_order DESC
    ) AS rank_in_status
FROM summary
ORDER BY customer_state, delivery_status;
 
-- ------------------------------------------------------------
-- 6.7  Customer Segmentation RFM (Recency-Frequency-Monetary)
--       menggunakan CTE + NTILE + CASE WHEN
-- ------------------------------------------------------------
-- =========================================================
-- CUSTOMER SEGMENTATION RFM
-- Menggunakan CTE + NTILE + CASE WHEN
-- =========================================================

WITH customer_rfm_raw AS (

    -- =====================================================
    -- Hitung nilai dasar RFM per customer
    -- =====================================================

    SELECT
        c.customer_unique_id,
        c.customer_city,
        c.customer_state,

        MAX(o.order_purchase_timestamp::DATE)
            AS last_purchase_date,

        COUNT(DISTINCT o.order_id)
            AS frequency,

        ROUND(SUM(p.payment_value), 2)
            AS monetary

    FROM customers c

    JOIN orders o ON c.customer_id = o.customer_id

    JOIN order_payments p ON o.order_id = p.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        c.customer_unique_id,
        c.customer_city,
        c.customer_state
),

customer_rfm AS (

    -- =====================================================
    -- Hitung recency (selisih hari dari transaksi terakhir)
    -- =====================================================

    SELECT
        *,

        (
            MAX(last_purchase_date) OVER ()
            - last_purchase_date
        ) AS recency_days

    FROM customer_rfm_raw
),

rfm_scored AS (

    -- =====================================================
    -- Scoring RFM dengan NTILE(5)
    -- =====================================================

    SELECT
        *,

        NTILE(5) OVER (
            ORDER BY recency_days ASC
        ) AS r_score,

        NTILE(5) OVER (
            ORDER BY frequency DESC
        ) AS f_score,

        NTILE(5) OVER (
            ORDER BY monetary DESC
        ) AS m_score

    FROM customer_rfm
),

rfm_labeled AS (

    -- =====================================================
    -- Segmentasi customer
    -- =====================================================

    SELECT
        *,

        (r_score + f_score + m_score) AS rfm_total,

        CASE

            WHEN (r_score + f_score + m_score) >= 13
                THEN 'Champion'

            WHEN (r_score + f_score + m_score) >= 10
                THEN 'Loyal Customer'

            WHEN (r_score + f_score + m_score) >= 7
                THEN 'Potential Loyalist'

            WHEN (r_score + f_score + m_score) >= 5
                THEN 'At Risk'

            ELSE 'Lost Customer'

        END AS rfm_segment

    FROM rfm_scored
)

-- =========================================================
-- Ringkasan hasil segmentasi
-- =========================================================

SELECT

    rfm_segment,

    COUNT(*) AS jumlah_pelanggan,

    ROUND(AVG(monetary), 2) AS avg_monetary,

    ROUND(SUM(monetary), 2) AS total_revenue_segment,

    ROUND(AVG(frequency), 2) AS avg_frequency,

    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
        2
    ) AS pct_pelanggan

FROM rfm_labeled

GROUP BY rfm_segment

ORDER BY total_revenue_segment DESC;
 
-- ------------------------------------------------------------
-- 6.8  Trend Analysis — deteksi peak hour pembelian
-- ------------------------------------------------------------
SELECT
    EXTRACT(HOUR FROM order_purchase_timestamp) AS jam,
    COUNT(*) AS total_order,
    ROUND(AVG(p.payment_value), 2) AS avg_nilai,
    RANK() OVER (ORDER BY COUNT(*) DESC) AS rank_tersibuk
FROM orders o
JOIN order_payments p ON o.order_id = p.order_id
GROUP BY jam
ORDER BY jam;
 
-- Trend harian dalam seminggu
SELECT
    TO_CHAR(order_purchase_timestamp, 'Day') AS hari,
    EXTRACT(DOW FROM order_purchase_timestamp) AS no_hari,
    COUNT(*) AS total_order,
    ROUND(SUM(p.payment_value), 2) AS total_revenue
FROM orders o
JOIN order_payments p ON o.order_id = p.order_id
GROUP BY hari, no_hari

ORDER BY no_hari;

-- ================================================================
-- SECTION 7 : DASHBOARD & REPORTING (VIEWS)
-- ================================================================
 
-- ------------------------------------------------------------
-- VIEW 1 : Dashboard Penjualan Bulanan
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_monthly_sales_dashboard AS
WITH monthly_base AS (
    SELECT
        TO_CHAR(o.order_purchase_timestamp, 'YYYY-MM') AS bulan,
        COUNT(DISTINCT o.order_id)  AS total_order,
        COUNT(DISTINCT o.customer_id) AS unik_pelanggan,
        ROUND(SUM(p.payment_value), 2) AS total_revenue,
        ROUND(AVG(p.payment_value), 2) AS avg_order_value,
        COUNT(*) FILTER (WHERE o.order_status = 'delivered') AS order_selesai,
        COUNT(*) FILTER (WHERE o.order_status = 'canceled') AS order_batal,
        COUNT(*) FILTER (WHERE o.order_status = 'shipped') AS order_dikirim
    FROM orders o
    JOIN order_payments p ON o.order_id = p.order_id
    GROUP BY bulan
)
SELECT
    bulan,
    total_order,
    unik_pelanggan,
    total_revenue,
    avg_order_value,
    order_selesai,
    order_batal,
    order_dikirim,
    ROUND(order_selesai * 100.0
          / NULLIF(total_order, 0), 2) AS delivery_rate_pct,
    -- MoM comparison
    LAG(total_order,   1) OVER (ORDER BY bulan) AS order_bulan_lalu,
    LAG(total_revenue, 1) OVER (ORDER BY bulan) AS revenue_bulan_lalu,
    ROUND(
        (total_revenue - LAG(total_revenue,1) OVER (ORDER BY bulan))
        / NULLIF(LAG(total_revenue,1) OVER (ORDER BY bulan), 0)
        * 100
    , 2) AS mom_growth_pct,
    -- Running total
    ROUND(SUM(total_revenue) OVER (ORDER BY bulan
              ROWS BETWEEN UNBOUNDED PRECEDING
              AND CURRENT ROW), 2) AS kumulatif_revenue,
    -- Rank bulan terbaik
    RANK() OVER (ORDER BY total_revenue DESC) AS rank_revenue
FROM monthly_base
ORDER BY bulan;
 
-- Tampilkan View 1
SELECT * FROM vw_monthly_sales_dashboard;
 
-- ------------------------------------------------------------
-- VIEW 2 : Dashboard Segmentasi Pelanggan RFM
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_customer_rfm_dashboard AS
WITH rfm_raw AS (
    SELECT
        c.customer_unique_id,
        c.customer_city,
        c.customer_state,
        COUNT(DISTINCT o.order_id) AS frequency,
        ROUND(SUM(p.payment_value), 2) AS monetary,
        MAX(o.order_purchase_timestamp::DATE) AS last_order_date,
        MIN(o.order_purchase_timestamp::DATE) AS first_order_date
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, c.customer_city, c.customer_state
),
scored AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY last_order_date DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency) AS f_score,
        NTILE(5) OVER (ORDER BY monetary)  AS m_score
    FROM rfm_raw
)
SELECT
    customer_unique_id,
    customer_city,
    customer_state,
    frequency,
    monetary,
    last_order_date,
    first_order_date,
    r_score,
    f_score,
    m_score,
    (r_score + f_score + m_score)     AS rfm_total,
    CASE
        WHEN (r_score + f_score + m_score) >= 13 THEN 'Champion'
        WHEN (r_score + f_score + m_score) >= 10 THEN 'Loyal Customer'
        WHEN (r_score + f_score + m_score) >= 7  THEN 'Potential Loyalist'
        WHEN (r_score + f_score + m_score) >= 5  THEN 'At Risk'
        ELSE                                          'Lost Customer'
    END  AS rfm_segment,
    RANK() OVER (ORDER BY monetary DESC) AS spending_rank
FROM scored;
 
-- Tampilkan View 2 — ringkasan per segmen
SELECT
    rfm_segment,
    COUNT(*) AS jumlah_pelanggan,
    ROUND(AVG(monetary), 2) AS avg_spent,
    ROUND(SUM(monetary), 2) AS total_revenue,
    ROUND(AVG(frequency), 2) AS avg_order,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_pelanggan
FROM vw_customer_rfm_dashboard
GROUP BY rfm_segment
ORDER BY avg_spent DESC;
 
-- Top 20 pelanggan (Champion & Loyal)
SELECT *
FROM vw_customer_rfm_dashboard
WHERE rfm_segment IN ('Champion','Loyal Customer')
ORDER BY spending_rank
LIMIT 20;
 
-- ------------------------------------------------------------
-- VIEW 3 : Dashboard Performa Regional (per State)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_regional_performance_dashboard AS
SELECT
    c.customer_state,
    COUNT(DISTINCT c.customer_id) AS total_pelanggan,
    COUNT(DISTINCT c.customer_city) AS jumlah_kota,
    COUNT(DISTINCT o.order_id) AS total_order,
    ROUND(SUM(p.payment_value), 2) AS total_revenue,
    ROUND(AVG(p.payment_value), 2) AS avg_order_value,
    COUNT(*) FILTER (WHERE o.order_status='delivered') AS order_delivered,
    COUNT(*) FILTER (WHERE o.order_status='canceled')  AS order_canceled,
    ROUND(
        COUNT(*) FILTER (WHERE o.order_status='delivered')
        * 100.0 / NULLIF(COUNT(DISTINCT o.order_id), 0)
    , 2) AS delivery_rate_pct,
    ROUND(
        SUM(p.payment_value)
        / NULLIF(COUNT(DISTINCT c.customer_id), 0)
    , 2) AS revenue_per_customer,
    -- Ranking
    RANK() OVER (ORDER BY SUM(p.payment_value) DESC) AS rank_by_revenue,
    RANK() OVER (ORDER BY COUNT(DISTINCT c.customer_id) DESC) AS rank_by_customer,
    DENSE_RANK() OVER (ORDER BY AVG(p.payment_value) DESC) AS rank_by_avg_value,
    -- Bandingkan dengan rata-rata nasional
    CASE
        WHEN AVG(p.payment_value) > (SELECT AVG(payment_value)
                                     FROM order_payments)
            THEN 'Di atas rata-rata'
        ELSE 'Di bawah rata-rata'
    END AS posisi_avg_nasional
FROM customers c
JOIN orders o  ON c.customer_id = o.customer_id
JOIN order_payments p ON o.order_id = p.order_id
GROUP BY c.customer_state;
 
-- Tampilkan View 3 — urut dari revenue terbesar
SELECT * FROM vw_regional_performance_dashboard
ORDER BY rank_by_revenue;
 
-- ------------------------------------------------------------
-- 7.1  Laporan Tabel Summary — KPI Utama
-- ------------------------------------------------------------
SELECT
    'Total Orders' AS kpi, COUNT(*)::TEXT AS nilai FROM orders
UNION ALL
SELECT 'Orders Delivered',   COUNT(*)::TEXT FROM orders WHERE order_status='delivered'
UNION ALL
SELECT 'Orders Canceled',    COUNT(*)::TEXT FROM orders WHERE order_status='canceled'
UNION ALL
SELECT 'Total Customers',    COUNT(*)::TEXT FROM customers
UNION ALL
SELECT 'Total Revenue (R$)',
    ROUND(SUM(payment_value),2)::TEXT FROM order_payments WHERE payment_type!='unknown'
UNION ALL
SELECT 'Avg Order Value (R$)',
    ROUND(AVG(payment_value),2)::TEXT FROM order_payments WHERE payment_type!='unknown'
UNION ALL
SELECT 'Max Order Value (R$)',
    MAX(payment_value)::TEXT FROM order_payments
UNION ALL
SELECT 'Delivery Rate (%)',
    ROUND(COUNT(*) FILTER (WHERE order_status='delivered')*100.0/COUNT(*),2)::TEXT
    FROM orders;
 
-- ------------------------------------------------------------
-- 7.2  Ranking Analysis — Top 10 State berdasarkan Revenue
-- ------------------------------------------------------------
WITH state_ranked AS (
    SELECT
        *,
        RANK() OVER (ORDER BY total_revenue DESC) AS posisi
    FROM vw_regional_performance_dashboard
)
SELECT
    posisi,
    customer_state,
    total_pelanggan,
    total_order,
    total_revenue,
    avg_order_value,
    delivery_rate_pct,
    revenue_per_customer
FROM state_ranked
WHERE posisi <= 10
ORDER BY posisi;
 
-- ------------------------------------------------------------
-- 7.3  Trend Analysis — MoM Growth Revenue
-- ------------------------------------------------------------
SELECT
    bulan,
    total_order,
    total_revenue,
    mom_growth_pct,
    kumulatif_revenue,
    CASE
        WHEN mom_growth_pct > 0  THEN 'Naik'
        WHEN mom_growth_pct < 0  THEN 'Turun'
        WHEN mom_growth_pct = 0  THEN 'Stabil'
        ELSE '—'
    END AS tren_label
FROM vw_monthly_sales_dashboard
ORDER BY bulan;
 
-- ------------------------------------------------------------
-- 7.4  Segmentasi Data — Distribusi Metode Pembayaran
-- ------------------------------------------------------------
SELECT
    payment_type  AS metode_bayar,
    COUNT(*) AS total_transaksi,
    ROUND(SUM(payment_value), 2) AS total_revenue,
    ROUND(AVG(payment_value), 2) AS avg_nilai,
    ROUND(COUNT(*) * 100.0
          / SUM(COUNT(*)) OVER (), 2) AS pct_transaksi,
    ROUND(SUM(payment_value) * 100.0
          / SUM(SUM(payment_value)) OVER (), 2) AS pct_revenue,
    RANK() OVER (ORDER BY SUM(payment_value) DESC) AS rank_revenue
FROM order_payments
WHERE payment_type != 'unknown'
GROUP BY payment_type
ORDER BY rank_revenue;

