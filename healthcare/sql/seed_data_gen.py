import random
from datetime import datetime, timedelta

# SCALE: Enterprise Grade
NUM_EMPLOYERS = 30
NUM_EMPLOYEES = 500
NUM_CLAIMS = 1500
NUM_PROVIDERS = 50
NUM_ENROLLMENTS = 1000 # Most employees enroll in multiple products

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

with open('data.js', 'w') as f:
    f.write("// Enterprise-Scale Seed Data for Shukla Healthcare\n")
    f.write("const SEED_DATA = `\n")
    
    # 1. Dim Providers (New)
    f.write("-- Providers\n")
    f.write("INSERT INTO dim_providers (provider_id, provider_name, specialty, network_status) VALUES\n")
    provider_rows = []
    p_names = ['City Hospital', 'Prime Dental', 'Wellness Clinic', 'Heart Institute', 'Global Pharma', 'Animal Care']
    for i in range(1, NUM_PROVIDERS + 1):
        name = f"{random.choice(p_names)} {i}"
        spec = random.choice(specialties)
        net = random.choice(['IN-NETWORK', 'IN-NETWORK', 'OUT-OF-NETWORK'])
        provider_rows.append(f"({i}, '{name}', '{spec}', '{net}')")
    f.write(",\n".join(provider_rows) + ";\n\n")

    # 2. Products
    f.write("INSERT INTO dim_products (product_id, product_name, line_of_business, risk_profile) VALUES\n")
    product_vals = [f"({p[0]}, '{p[1]}', '{p[2]}', 'Medium')" for p in products]
    f.write(",\n".join(product_vals) + ";\n\n")

    # 3. Employers
    f.write("INSERT INTO dim_employers (employer_id, employer_name, industry, hq_country, onboarding_date) VALUES\n")
    employer_rows = []
    for i in range(1, NUM_EMPLOYERS + 1):
        name = f"Corp_{['Alpha', 'Beta', 'Gamma', 'Delta', 'Zeta', 'Sigma', 'Omega', 'Prime'][i%8]}_{i}"
        ind = random.choice(industries)
        cty = random.choice(countries)
        employer_rows.append(f"({i}, '{name}', '{ind}', '{cty}', '{random_date().strftime('%Y-%m-%d')}')")
    f.write(",\n".join(employer_rows) + ";\n\n")

    # 4. Employees
    f.write("INSERT INTO dim_employees (employee_id, employer_id, full_name, birth_date, enrollment_status, monthly_salary) VALUES\n")
    employee_rows = []
    first_names = ['John', 'Jane', 'Alex', 'Sarah', 'Raj', 'Priya', 'Sven', 'Elena', 'Li', 'Wei']
    last_names = ['Smith', 'Doe', 'Kumar', 'Chen', 'Garcia', 'Muller', 'Abadi']
    for i in range(1, NUM_EMPLOYEES + 1):
        name = f"{random.choice(first_names)} {random.choice(last_names)}"
        salary = round(random.uniform(4000, 16000), 2)
        employee_rows.append(f"({i}, {random.randint(1, NUM_EMPLOYERS)}, '{name}', '{random_date(1975).strftime('%Y-%m-%d')}', 'ACTIVE', {salary})")
    f.write(",\n".join(employee_rows) + ";\n\n")

    # 5. Enrollments (New)
    f.write("-- Enrollments Bridge\n")
    f.write("INSERT INTO fact_enrollments (enrollment_id, employee_id, product_id, enrollment_date, status) VALUES\n")
    enrollment_rows = []
    for i in range(1, NUM_ENROLLMENTS + 1):
        emp_id = random.randint(1, NUM_EMPLOYEES)
        prod_id = random.randint(1, 5)
        enrollment_rows.append(f"({i}, {emp_id}, {prod_id}, '{random_date(2022).strftime('%Y-%m-%d')}', 'ACTIVE')")
    f.write(",\n".join(enrollment_rows) + ";\n\n")

    # 6. Claims
    f.write("INSERT INTO fact_claims (claim_id, employee_id, product_id, provider_id, service_date, claim_amount, paid_amount, claim_status) VALUES\n")
    claim_rows = []
    for i in range(1, NUM_CLAIMS + 1):
        amt = round(random.uniform(100, 8000), 2)
        paid = round(amt * random.uniform(0.6, 0.95), 2) if random.random() > 0.15 else 0
        claim_rows.append(f"({i}, {random.randint(1, NUM_EMPLOYEES)}, {random.randint(1, 5)}, {random.randint(1, NUM_PROVIDERS)}, '{random_date(2023).strftime('%Y-%m-%d')}', {amt}, {paid}, '{'DENIED' if paid == 0 else 'APPROVED'}')")
    f.write(",\n".join(claim_rows) + ";\n\n")
    
    # 7. Audit History (New)
    f.write("-- Claim Audit History\n")
    f.write("INSERT INTO fact_claim_status_history (history_id, claim_id, old_status, new_status, updated_at) VALUES\n")
    audit_rows = []
    for i in range(1, 500): # Sample 500 status changes
        audit_rows.append(f"({i}, {random.randint(1, NUM_CLAIMS)}, 'PENDING', 'APPROVED', '{random_date(2024).strftime('%Y-%m-%d %H:%M:%S')}')")
    f.write(",\n".join(audit_rows) + ";\n\n")
    
    f.write("`;\n")

print("Generated data.js with Enterprise Architecture")
