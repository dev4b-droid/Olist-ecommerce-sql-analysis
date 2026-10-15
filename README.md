# Olist Marketplace: Delivery Delays and Seller Performance (SQL)

A MySQL analysis of the Brazilian E-Commerce Public Dataset by Olist (about 100k orders, 2016-2018, 9 related tables). The project answers four business questions about delivery delays, revenue growth, seller performance, and repeat customers, using joins, CTEs, views, and window functions.

**Author:** Dev Khandelwal | **Tools:** MySQL 8.0+, MySQL Workbench

---

## 📌 Business Questions

1. **Does late delivery hurt review scores?**
2. **What is the month-on-month revenue growth?**
3. **Who are the top sellers, and do they deliver good service?**
4. **Who are the repeat customers?**

---

## 📊 Key Findings

### 1. Late Delivery and Reviews
* **6.77%** of delivered orders arrive late (delivered after the estimated date).
* Late orders average **2.27 stars** vs **4.29** for on-time orders, creating a massive gap of 2 full points.
* Most of the reputational damage happens in the first week:

| Delivery vs Estimate | Orders | Avg Review |
| :--- | :--- | :--- |
| On time or early | 89,913 | 4.3 |
| 1-3 days late | 1,870 | 3.3 |
| 4-7 days late | 1,802 | 2.1 |
| 8-14 days late | 1,478 | 1.7 |
| 15+ days late | 1,384 | 1.7 |

* Late rates are highest in the north and northeast: **MA 17.4%**, CE 13.8%, BA 12.2%.
* **RJ** is the largest problem by volume, experiencing a 12.1% late rate on 12,349 orders.
* SP (4.5%) and PR (4.0%) are the best-performing states.
* States with higher late rates tend to score lower overall (MA 3.83 vs SP 4.25).

### 2. Revenue Growth (Jan 2017 to Aug 2018)
* Monthly revenue grew by approximately **7.5x**, scaling from R$111.6K to R$838.6K.
* Total revenue over the 20 analysed months reached **R$13.18M**.
* Volume drove this growth: monthly orders rose from 749 to 6,351, while average order value remained stable between R$124 and R$149.
* **Nov 2017 was the peak month** with R$987.6K in revenue and 7,288 orders (+52.4% MoM), followed by a 26.5% drop in Dec 2017.
* Growth levelled off in 2018: revenue held at roughly R$925K to R$980K from Jan to May, then eased to about R$840K to R$870K over the summer.

### 3. Seller Performance
* There are **2,968 sellers** in total, but revenue is highly concentrated.
* The **top 10% of sellers (297) earn 67.12%** of the total revenue, while the bottom half earns only about 3%.
* The absolute top seller earned R$226,988 from 1,124 orders.
* The top 10 sellers together capture about 13.3% of revenue, and 9 of the 10 are located in SP.
* SP holds about 60% of all sellers and generates 64% of total revenue.
* High volume does not guarantee high service quality: **21 of the top 30 sellers (70%)** perform worse than the marketplace benchmark on average review scores or late rates.

### 4. Repeat Customers
* **97.00%** of customers bought only once.
* 2.16% returned on a later day, and 0.84% placed several orders on the same day only (likely split baskets).
* Including same-day orders, there are 2,798 repeat customers representing 3.00% of the 93,330 total base.
* These repeat customers placed 5,915 orders (6.13% of all orders) and generated R$727,390 (5.5% of total revenue).
* Within 90 days of a first order, only about **1.3%** of customers returned

---

## 🛠️ SQL Techniques Utilized
* Multi-table `JOIN`s (`INNER` and `LEFT`) and one-row-per-order aggregations to prevent join fan-out.
* CTEs and Views (`order_analysis`, `seller_orders`, `seller_summary`, `seller_category`, `customer_base`, `customer_first_order`).
* Window Functions: `ROW_NUMBER`, `RANK`/`DENSE_RANK` (with `PARTITION BY`), `NTILE`, `LAG`, and running totals using `SUM() OVER`.
* Logical and Date Functions: `CASE` expressions, `DATEDIFF`, `DATE_FORMAT`, `NULLIF`, and `HAVING` filters.
* Advanced analytical concepts like Cohort Analysis and comparative Benchmarking.

---

## 📂 Repository Contents

| File | Description |
| :--- | :--- |
| `SQL_BRAZIL_PROJECT.sql` | The full analysis: database setup, data load, views, and all four query solutions. |
| `README.md` | This documentation file. |

---

## 🚀 How to Run

1. **Install MySQL 8.0+** (Required for window functions and CTEs).
2. **Download the Dataset:** Obtain the Olist CSV files from Kaggle.
3. **Enable Local File Loading:**
   * **Server:** Execute `SET GLOBAL local_infile = 1;` (requires admin privileges; comment this line out in the script if unavailable).
   * **Client:** Add `local_infile` to your connection settings. In MySQL Workbench: Navigate to Edit Connection > Advanced > Others, add `OPT_LOCAL_INFILE=1`, and reconnect.
4. **Update File Paths:** In `SQL_BRAZIL_PROJECT.sql`, replace `C:/path/to/dataset/` in every `LOAD DATA` statement with your local directory containing the CSV files.
5. **Execute:** Run the entire script. It is designed to drop and recreate the `olist` database, meaning it can safely be re-run multiple times.

> **Expected Row Counts After Loading:** customers 99,441, orders 99,441, order_items 112,650, order_payments 103,886, order_reviews 99,224, products 32,951, sellers 3,095. The master `order_analysis` view should output exactly **96,447** rows.

---

## ⚙️ Data Preparation & Definitions
* **Orders Analysed:** Restricted to delivered orders with a valid delivery date and no impossible timestamps (e.g., carrier pickup date cannot be after customer delivery date). This trims the dataset from 99,441 to 96,447 orders.
* **Late Definition:** The actual delivery date is strictly after the estimated delivery date (evaluated by date, ignoring time of day).
* **Revenue Calculation:** The sum of item `price`, explicitly excluding freight costs.
* **Review Deduplication:** Some orders contain multiple reviews; the most recent one is isolated using `ROW_NUMBER`.
* **Join Inflation Prevention:** Items and payments are pre-aggregated to one row per order before joining to avoid repeating rows and artificially inflating revenue metrics.
* **Customer Identification:** `customer_unique_id` tracks a single person across multiple purchases, whereas `customer_id` acts as a unique session ID for every new order.
* **Repeat Customer Definition:** A user with a subsequent order placed on a later date than their initial order. Same-day multiple orders are consolidated as a single purchase session.
* **Revenue Window:** Limited to Jan 2017 – Aug 2018. Outlying earlier and later months contain too few orders to calculate meaningful growth rates.
* **Cohorts:** Restricted to customers whose first order occurred between Jan 2017 and May 2018, guaranteeing every analyzed customer has a complete 90-day window to make a return purchase.
* **Seller Benchmarking:** Only sellers exceeding 30 historical orders are evaluated against the benchmark to filter out unreliable averages from low-volume merchants.
* **Omitted Data:** The geolocation table and category translation tables were not utilized in this specific analysis scope.

---

## ⚠️ Limitations
* **Correlation vs. Causation:** The analysis highlights associations. For instance, late deliveries correlate strongly with lower reviews and diminished repeat orders, but other external variables may also be contributing factors.
* **Incomplete Lifecycle Data:** Only officially delivered orders are analyzed. Recent temporal data may be slightly understated if a volume of orders was still in transit when the dataset was frozen.
* **Order-Level Aggregation:** Reviews and late flags are tied to the overarching order. For the 1.3% of orders fulfilled by multiple different sellers, each participating seller mathematically inherits the exact same review score and late flag.
* **Statistical Significance:** The gap in repeat rates between late and on-time first orders is relatively small, and the late group consists of only 5,693 customers; this should be interpreted as a general tendency rather than a rigid rule.
* **Seller Flagging:** Seller quality flags are triggered using an "either/or" logic threshold compared against simple (unweighted) market averages.

---

## 🗄️ Dataset Source
Brazilian E-Commerce Public Dataset by Olist, available on Kaggle.
https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
