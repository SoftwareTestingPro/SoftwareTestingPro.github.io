const challenges = [
    // --- 1. BASIC SELECTION & FILTERING ---
    {
        text: "Retrieve the Top 5 highest paid ACTIVE employees excluding the 'Finance' industry.",
        solution: "SELECT e.full_name, e.monthly_salary FROM dim_employees e JOIN dim_employers emp ON e.employer_id = emp.employer_id WHERE e.enrollment_status = 'ACTIVE' AND emp.industry != 'Finance' ORDER BY e.monthly_salary DESC LIMIT 5;"
    },
    {
        text: "Find all employers who joined in the year 2023.",
        solution: "SELECT * FROM dim_employers WHERE onboarding_date BETWEEN '2023-01-01' AND '2023-12-31';"
    },

    // --- 2. AGGREGATES & GROUPING ---
    {
        text: "List the number of employees each employer has. Sort by company with most employees first.",
        solution: "SELECT emp.employer_name, COUNT(e.employee_id) as headcount FROM dim_employers emp JOIN dim_employees e ON emp.employer_id = e.employer_id GROUP BY 1 ORDER BY 2 DESC;"
    },
    {
        text: "Calculate the average claim amount for each Product Line (LOB).",
        solution: "SELECT p.line_of_business, AVG(c.claim_amount) FROM dim_products p JOIN fact_claims c ON p.product_id = c.product_id GROUP BY 1;"
    },
    {
        text: "Which industry has the highest total billed claim amount?",
        solution: "SELECT emp.industry, SUM(c.claim_amount) FROM dim_employers emp JOIN dim_employees e ON emp.employer_id = e.employer_id JOIN fact_claims c ON e.employee_id = c.employee_id GROUP BY 1 ORDER BY 2 DESC LIMIT 1;"
    },

    // --- 3. FILTERING WITH HAVING ---
    {
        text: "Identify employers who have paid out more than $20,000 in total claims.",
        solution: "SELECT emp.employer_name, SUM(c.paid_amount) FROM dim_employers emp JOIN dim_employees e ON emp.employer_id = e.employer_id JOIN fact_claims c ON e.employee_id = c.employee_id GROUP BY 1 HAVING SUM(c.paid_amount) > 20000;"
    },

    // --- 4. CONDITIONAL LOGIC (CASE WHEN) ---
    {
        text: "Classify employees into 3 Salary Brackets: 'Entry' (<5k), 'Mid' (5k-10k), 'Senior' (>10k). Count users in each.",
        solution: "SELECT CASE WHEN monthly_salary < 5000 THEN 'Entry' WHEN monthly_salary BETWEEN 5000 AND 10000 THEN 'Mid' ELSE 'Senior' END as bracket, COUNT(*) FROM dim_employees GROUP BY 1;"
    },
    {
        text: "Calculate 'Payout Efficiency': If paid_amount is > 90% of claim_amount, mark as 'High', else 'Regular'.",
        solution: "SELECT claim_id, CASE WHEN paid_amount >= (claim_amount * 0.9) THEN 'High' ELSE 'Regular' END as efficiency FROM fact_claims;"
    },

    // --- 5. SUBQUERIES & IN ---
    {
        text: "Find employees who have NEVER filed a claim (Unclaimed members).",
        solution: "SELECT full_name FROM dim_employees WHERE employee_id NOT IN (SELECT DISTINCT employee_id FROM fact_claims);"
    },
    {
        text: "Find employers whose Average Salary is higher than the Global Average Salary for all employees.",
        solution: "SELECT emp.employer_name FROM dim_employers emp JOIN dim_employees e ON emp.employer_id = e.employer_id GROUP BY 1 HAVING AVG(e.monthly_salary) > (SELECT AVG(monthly_salary) FROM dim_employees);"
    },

    // --- 6. ADVANCED JOINS (Many-to-Many) ---
    {
        text: "List unique employees who are enrolled in BOTH 'Life' and 'Dental' products.",
        solution: "SELECT e.full_name FROM dim_employees e JOIN fact_enrollments f1 ON e.employee_id = f1.employee_id JOIN dim_products p1 ON f1.product_id = p1.product_id JOIN fact_enrollments f2 ON e.employee_id = f2.employee_id JOIN dim_products p2 ON f2.product_id = p2.product_id WHERE p1.line_of_business = 'Life' AND p2.line_of_business = 'Dental';"
    },

    // --- 7. AUDIT & HISTORY (Time-Series) ---
    {
        text: "Calculate the average time (in days) a claim stays in 'PENDING' before approval (Use Audit History).",
        solution: "SELECT AVG(JULIANDAY(updated_at) - JULIANDAY(c.service_date)) FROM fact_claim_history h JOIN fact_claims c ON h.claim_id = c.claim_id WHERE h.new_status = 'APPROVED';"
    },

    // --- 8. STRING & PATTERN MATCHING ---
    {
        text: "Find all providers whose name contains the word 'Clinic'.",
        solution: "SELECT provider_name FROM dim_providers WHERE provider_name LIKE '%Clinic%';"
    },

    // --- 9. WINDOW FUNCTIONS (Expert) ---
    {
        text: "For each employer, rank their employees by salary (1, 2, 3...) using a Window Function.",
        solution: "SELECT employer_id, full_name, monthly_salary, RANK() OVER (PARTITION BY employer_id ORDER BY monthly_salary DESC) as salary_rank FROM dim_employees;"
    },
    {
        text: "Calculate the 'Running Total' of claim amounts for each employee over time.",
        solution: "SELECT employee_id, service_date, claim_amount, SUM(claim_amount) OVER (PARTITION BY employee_id ORDER BY service_date) as running_total FROM fact_claims;"
    },

    // --- 10. DATA QUALITY & RECONCILIATION ---
    {
        text: "Identify any claims where 'Paid Amount' is greater than 'Claim Amount' (Data Error check).",
        solution: "SELECT * FROM fact_claims WHERE paid_amount > claim_amount;"
    },

    // --- 11. RATIO & FINANCIAL ANALYSIS ---
    {
        text: "Calculate the 'Loss Ratio' (Total Paid / Total Claimed) for each Product Category.",
        solution: "SELECT p.line_of_business, SUM(c.paid_amount) / SUM(c.claim_amount) as loss_ratio FROM dim_products p JOIN fact_claims c ON p.product_id = c.product_id GROUP BY 1;"
    },
    {
        text: "Find the 'Premium to Payout' ratio per employee (Salary / Total Claims).",
        solution: "SELECT e.full_name, e.monthly_salary / SUM(c.paid_amount) as safety_margin FROM dim_employees e JOIN fact_claims c ON e.employee_id = c.employee_id GROUP BY 1;"
    },

    // --- 12. NETWORK DENSITY ---
    {
        text: "Identify specialty areas (e.g. Dentist) that have 0 'IN-NETWORK' providers.",
        solution: "SELECT specialty FROM dim_providers GROUP BY specialty HAVING SUM(CASE WHEN network_status = 'IN-NETWORK' THEN 1 ELSE 0 END) = 0;"
    },

    // --- 13. CHURN & ENROLLMENT FLOW ---
    {
        text: "Count how many employees are currently enrolled in a product but marked as 'INACTIVE' in the employee table.",
        solution: "SELECT COUNT(DISTINCT e.employee_id) FROM dim_employees e JOIN fact_enrollments f ON e.employee_id = f.employee_id WHERE e.enrollment_status = 'INACTIVE';"
    },

    // --- 14. DATA DISCOVERY ---
    {
        text: "Find the Month with the highest number of claims submitted across the entire 1,200 record history.",
        solution: "SELECT STRFTIME('%Y-%m', service_date) as month, COUNT(*) FROM fact_claims GROUP BY 1 ORDER BY 2 DESC LIMIT 1;"
    }
];

let currentChallenge = null;

function getNewChallenge() {
    const randomIndex = Math.floor(Math.random() * challenges.length);
    currentChallenge = challenges[randomIndex];
    document.getElementById('challenge-text').innerText = currentChallenge.text;
    document.getElementById('btn-solution').style.display = 'block';
    switchTab('sql-lab');
    editor.value = "-- Challenge Task: " + currentChallenge.text + "\n";
}

function showSolution() {
    if(currentChallenge) {
        editor.value = currentChallenge.solution;
        runQuery();
    }
}
