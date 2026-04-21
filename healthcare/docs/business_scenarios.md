# Business Case Studies: Shukla Healthcare

This document provides detailed business requirements for hands-on SQL practice. Use these to build your portfolio.

## Case 1: The "High Loss" Employer Analysis
**Requirement**: The VP of Sales wants to know which Employers are costing the company more than they bring in.
**Goal**: 
1. Identify employers where total claims paid > $50,000.
2. Breakdown these claims by Product (Did Life or Dental drive the cost?).
**SQL Concepts**: `GROUP BY`, `JOIN`, `HAVING`.

## Case 2: Claims Processing Efficiency
**Requirement**: The Operations team needs to find 'Bottlenecks'.
**Goal**:
1. Find the count of 'PENDING' claims per country.
2. Filter for claims older than 30 days (use `service_date`).
**SQL Concepts**: `WHERE`, `COUNT`, `DATE functions`.

## Case 3: Product Diversification
**Requirement**: Strategy team wants to see if Tech companies buy Pet insurance more than Finance companies.
**Goal**:
1. Join `dim_employers` to `dim_products`.
2. Count active enrollments for 'Pet Guardian' product grouped by `industry`.
**SQL Concepts**: `CASE WHEN`, `JOIN`, `Pivot logic`.

## Case 4: Global Payroll & Risk
**Requirement**: Correlation between Salary and Claim Amount.
**Goal**:
1. Group employees into Salary Brackets (Low < 5k, Mid 5-10k, High > 10k).
2. Calculate average claim amount per bracket.
**SQL Concepts**: `CASE WHEN` (Bucketing), `AVG`.

## Case 6: Provider Performance (Complex Joins)
**Requirement**: Which clinic specialties are most expensive?
**Goal**: Calculate average `paid_amount` grouped by `specialty`.
**SQL**: 
```sql
SELECT p.specialty, AVG(c.paid_amount) 
FROM dim_providers p 
JOIN fact_claims c ON p.provider_id = c.provider_id 
GROUP BY 1 ORDER BY 2 DESC;
```

## Case 7: The Audit Trail (CTEs)
**Requirement**: Find claims that took multiple status changes.
**Goal**: Use a CTE to find claims with more than 1 entry in `fact_claim_status_history`.
**SQL**:
```sql
WITH history_counts AS (
    SELECT claim_id, COUNT(*) as changes 
    FROM fact_claim_status_history 
    GROUP BY 1
)
SELECT * FROM history_counts WHERE changes > 1;
```

## Case 8: Member Coverage Density (Many-to-Many)
**Requirement**: Percentage of employees with more than 2 active insurance products.
**Goal**: Join `dim_employees` to `fact_enrollments`.
**SQL**:
```sql
SELECT employee_id, COUNT(product_id) as product_count
FROM fact_enrollments
GROUP BY 1
HAVING product_count >= 2;
```
