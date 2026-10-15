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