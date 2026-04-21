-- Supabase / PostgreSQL DDL for Shukla Healthcare
-- Best free-tier cloud database for SQL practice

-- 1. Dim Employers
CREATE TABLE dim_employers (
    employer_id SERIAL PRIMARY KEY,
    employer_name VARCHAR(255) NOT NULL,
    industry VARCHAR(100),
    hq_country VARCHAR(50),
    onboarding_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Dim Products
CREATE TABLE dim_products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    line_of_business VARCHAR(50), -- Life, Accident, Critical Illness, Dental, Pet
    risk_profile VARCHAR(20) DEFAULT 'Medium'
);

-- 3. Dim Employees
CREATE TABLE dim_employees (
    employee_id SERIAL PRIMARY KEY,
    employer_id INT REFERENCES dim_employers(employer_id),
    full_name VARCHAR(255) NOT NULL,
    birth_date DATE,
    enrollment_status VARCHAR(20) DEFAULT 'ACTIVE',
    monthly_salary DECIMAL(18,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Fact Claims
CREATE TABLE fact_claims (
    claim_id SERIAL PRIMARY KEY,
    employee_id INT REFERENCES dim_employees(employee_id),
    product_id INT REFERENCES dim_products(product_id),
    service_date DATE NOT NULL,
    claim_amount DECIMAL(18,2) NOT NULL,
    paid_amount DECIMAL(18,2) DEFAULT 0,
    claim_status VARCHAR(20) CHECK (claim_status IN ('APPROVED', 'DENIED', 'PENDING', 'VOID'))
);

-- Create some indexes for performance practice
CREATE INDEX idx_claims_service_date ON fact_claims(service_date);
CREATE INDEX idx_employee_employer ON dim_employees(employer_id);

-- View for easy analysis
CREATE OR REPLACE VIEW v_employer_loss_ratio AS
SELECT 
    e.employer_name,
    p.product_name,
    COUNT(c.claim_id) as total_claims,
    SUM(c.claim_amount) as total_billed,
    SUM(c.paid_amount) as total_paid,
    CASE 
        WHEN SUM(c.claim_amount) > 0 THEN ROUND((SUM(c.paid_amount) / SUM(c.claim_amount)) * 100, 2)
        ELSE 0 
    END as loss_ratio_pct
FROM dim_employers e
JOIN dim_employees emp ON e.employer_id = emp.employer_id
JOIN fact_claims c ON emp.employee_id = c.employee_id
JOIN dim_products p ON c.product_id = p.product_id
GROUP BY e.employer_name, p.product_name;
