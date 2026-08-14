# 🎵 KKBOX Subscription Growth & Retention Case Study

A comprehensive product data analytics and growth case study investigating subscription retention leakage, behavioral milestones (Aha! moments), and pricing optimization strategies for KKBOX.

---

## 📌 Project Overview
Subscription streaming services often suffer from high early-stage customer churn, particularly among users acquired through free trials or promotional cycles. This project utilizes end-to-end data engineering, statistical profiling, cohort retention modeling, and behavioral sequence mapping to identify structural bottlenecks and propose data-backed pricing interventions.

---

## 🛠️ Data Pipeline & Engineering
The raw transaction logs (`transactions_full`) underwent rigorous data profiling and transformation to ensure high analytical fidelity:
* **Missing Value Audits:** Verified primary key integrity across user IDs (`msno`) and operational timestamps.
* **Deduplication Logic:** Handled overlapping transaction entries using window functions (`ROW_NUMBER()`) ranked by expiration gap closeness.
* **Logical Date Correction:** Automatically repaired inverted subscription lifelines (`expire_date < tran_date`) using standard plan durations.
* **Anomaly Filtering:** Removed invalid financial outliers and unrealistic trial periods.

## 📊 Analytical Methodology & Power BI Dashboards
* **RFM Feature Engineering & Quantile Benchmarking:**
  * Built user-level behavioral profiles measuring Recency, Frequency, and Monetary metrics.
  * Applied statistical distribution percentiles (`quantile_cont`) to segment the user base objectively without arbitrary assumptions.
* **Segment Performance & Cohort Retention (Dashboard Page 1 & 2):**
  * Categorized users into Loyal / VIP (Top 20%), Potential / Regular, and Normal / At-Risk.
  * Tracked monthly cohort retention heatmaps to expose early-stage "leaky bucket" behaviors.
* **Aha! Movement & Behavioral Path Sequencing (Dashboard Page 3):**
  * Correlated transaction frequency against a 90-day retention lifespan window to isolate core engagement milestones.
  * Mapped `msno`-level user journey pathways (Branch A, B, C) to diagnose precise drop-off points.

## 🔑 Key Findings & Business Insights
* **The Normal Segment Bottleneck:** The Normal / At-Risk cohort accounts for nearly 48.47% of total users ($1.18\text{M}$) but yields the lowest retention and monetization performance.
* **Aha! Milestones:**
  * **Milestone 3 (Transaction 3):** Serves as the critical Aha! trigger where 90-day retention jumps abruptly to 45%.
  * **Milestone 5 (Transaction 5):** Reaches total saturation and habit lock-in at 99% retention.
* **The Billing Shock Root Cause:** Over $18\%$ of Normal users (Branch A3) churn immediately after consuming two zero-cost cycles (`1st=0, 2nd=0`). When forced to transition, they face an inflated price wall (averaging $395.29$) that exceeds full-paying users ($368.17$), triggering acute churn.

## 🚀 Strategic Recommendations
* **Stepped-Value Half-Pricing at Transaction 3:** Introduce an exclusive 50% transition incentive for converted free-tier users at Milestone 3 to eliminate billing shock and bridge users past the 45% retention barrier.
* **Automated Habit Lock-In at Transaction 5:** Smoothly graduate users to standard full pricing upon reaching Transaction 5 while unlocking high-tier ecosystem benefits to maximize LTV.
