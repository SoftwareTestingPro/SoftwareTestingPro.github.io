import random
from datetime import datetime, timedelta

# SCALE: Enterprise Grade
NUM_EMPLOYERS = 30
NUM_EMPLOYEES = 500
NUM_CLAIMS = 1500
NUM_PROVIDERS = 50
NUM_ENROLLMENTS = 1000

industries = ['Technology', 'Finance', 'Manufacturing', 'Healthcare', 'Retail', 'Energy', 'Logistics']
countries = ['US', 'UK', 'IN', 'CA', 'AU', 'DE', 'FR']
specialties = ['General Practitioner', 'Dentist', 'Cardiologist', 'Pediatrician', 'Veterinary Specialist']
products = [
    (1, 'Life Shield Plus', 'Life'),
    (2, 'AccidenCare', 'Accident'),
    (3, 'Critical Assist', 'Critical Illness'),
    (4, 'Dental Smile', 'Dental'),
    (5, 'Pet Guardian', 'Pet')
]

def random_date(start_year=2020):
    start = datetime(start_year, 1, 1)
    end = datetime.now()
    return start + timedelta(seconds=random.randint(0, int((end - start).total_seconds())))

sql_statements = []

# 1. Providers
sql_statements.append("-- Providers\nINSERT INTO dim_providers (provider_id, provider_name, specialty, network_status) VALUES")
provider_rows = []
p_names = ['City Hospital', 'Prime Dental', 'Wellness Clinic', 'Heart Institute', 'Global Pharma', 'Animal Care']
for i in range(1, NUM_PROVIDERS + 1):
    provider_rows.append(f"({i}, '{random.choice(p_names)} {i}', '{random.choice(specialties)}', '{random.choice(['IN-NETWORK', 'OUT-OF-NETWORK'])}')")
sql_statements.append(",\n".join(provider_rows) + ";\n")

# 2. Products
sql_statements.append("INSERT INTO dim_products (product_id, product_name, line_of_business, risk_profile) VALUES")
sql_statements.append(",\n".join([f"({p[0]}, '{p[1]}', '{p[2]}', 'Medium')" for p in products]) + ";\n")

# 3. Employers
sql_statements.append("INSERT INTO dim_employers (employer_id, employer_name, industry, hq_country, onboarding_date) VALUES")
employer_rows = []
for i in range(1, NUM_EMPLOYERS + 1):
    employer_rows.append(f"({i}, 'Corp_{i}', '{random.choice(industries)}', '{random.choice(countries)}', '{random_date().strftime('%Y-%m-%d')}')")
sql_statements.append(",\n".join(employer_rows) + ";\n")

# 4. Employees
sql_statements.append("INSERT INTO dim_employees (employee_id, employer_id, full_name, birth_date, enrollment_status, monthly_salary) VALUES")
employee_rows = []
for i in range(1, NUM_EMPLOYEES + 1):
    employee_rows.append(f"({i}, {random.randint(1, NUM_EMPLOYERS)}, 'Employee {i}', '{random_date(1975).strftime('%Y-%m-%d')}', 'ACTIVE', {round(random.uniform(4000, 16000), 2)})")
sql_statements.append(",\n".join(employee_rows) + ";\n")

# 5. Enrollments
sql_statements.append("INSERT INTO fact_enrollments (enrollment_id, employee_id, product_id, enrollment_date, status) VALUES")
enrollment_rows = []
for i in range(1, NUM_ENROLLMENTS + 1):
    enrollment_rows.append(f"({i}, {random.randint(1, NUM_EMPLOYEES)}, {random.randint(1, 5)}, '{random_date(2022).strftime('%Y-%m-%d')}', 'ACTIVE')")
sql_statements.append(",\n".join(enrollment_rows) + ";\n")

# 6. Claims
sql_statements.append("INSERT INTO fact_claims (claim_id, employee_id, product_id, provider_id, service_date, claim_amount, paid_amount, claim_status) VALUES")
claim_rows = []
for i in range(1, NUM_CLAIMS + 1):
    amt = round(random.uniform(100, 8000), 2)
    paid = round(amt * random.uniform(0.6, 0.95), 2) if random.random() > 0.15 else 0
    claim_rows.append(f"({i}, {random.randint(1, NUM_EMPLOYEES)}, {random.randint(1, 5)}, {random.randint(1, NUM_PROVIDERS)}, '{random_date(2023).strftime('%Y-%m-%d')}', {amt}, {paid}, '{'DENIED' if paid == 0 else 'APPROVED'}')")
sql_statements.append(",\n".join(claim_rows) + ";\n")

# 7. Audit History
sql_statements.append("INSERT INTO fact_claim_status_history (history_id, claim_id, old_status, new_status, updated_at) VALUES")
audit_rows = []
for i in range(1, 300):
    audit_rows.append(f"({i}, {random.randint(1, NUM_CLAIMS)}, 'PENDING', 'APPROVED', '{random_date(2024).strftime('%Y-%m-%d %H:%M:%S')}')")
sql_statements.append(",\n".join(audit_rows) + ";\n")

all_sql = "\n".join(sql_statements)

# --- Output 1: data.js for Web UI ---
with open('data.js', 'w') as f:
    f.write("const SEED_DATA = `\n" + all_sql + "`;")

# --- Output 2: mysql_export.sql for External Tools ---
with open('mysql_export.sql', 'w') as f:
    f.write("CREATE DATABASE IF NOT EXISTS shukla_healthcare;\nUSE shukla_healthcare;\n\n")
    f.write("-- Schema for External MySQL Workbench\n")
    f.write("""
CREATE TABLE IF NOT EXISTS dim_employers (employer_id INT PRIMARY KEY, employer_name VARCHAR(255), industry VARCHAR(100), hq_country VARCHAR(50), onboarding_date DATE);
CREATE TABLE IF NOT EXISTS dim_products (product_id INT PRIMARY KEY, product_name VARCHAR(100), line_of_business VARCHAR(50), risk_profile VARCHAR(20));
CREATE TABLE IF NOT EXISTS dim_employees (employee_id INT PRIMARY KEY, employer_id INT, full_name VARCHAR(255), birth_date DATE, enrollment_status VARCHAR(20), monthly_salary DECIMAL(18,2));
CREATE TABLE IF NOT EXISTS dim_providers (provider_id INT PRIMARY KEY, provider_name VARCHAR(255), specialty VARCHAR(100), network_status VARCHAR(50));
CREATE TABLE IF NOT EXISTS fact_enrollments (enrollment_id INT PRIMARY KEY, employee_id INT, product_id INT, enrollment_date DATE, status VARCHAR(20));
CREATE TABLE IF NOT EXISTS fact_claims (claim_id INT PRIMARY KEY, employee_id INT, product_id INT, provider_id INT, service_date DATE, claim_amount DECIMAL(18,2), paid_amount DECIMAL(18,2), claim_status VARCHAR(20));
CREATE TABLE IF NOT EXISTS fact_claim_status_history (history_id INT PRIMARY KEY, claim_id INT, old_status VARCHAR(20), new_status VARCHAR(20), updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);\n\n""")
    f.write(all_sql)

print("Generated both data.js (Web) and mysql_export.sql (External MySQL Workbench)")
