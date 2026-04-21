# Shukla Healthcare Data Analysis Practice

Welcome to the Shukla Healthcare Data Ecosystem. This folder contains a complete setup for practicing SQL, Data Engineering, and Business Analytics in a realistic US Insurance domain.

## 📁 Directory Structure
- `/app`: A professional web-based SQL Practice Studio (Completely Free).
- `/docs`: ERD, Data Dictionary, and Source-to-Target Mapping (STM).
- `/sql`: DDL scripts for **Supabase**, **DuckDB**, and sample data generators.

## 🚀 How to Practice (Free Tools Only)

### 1. Cloud-Based: Supabase (PostgreSQL)
Supabase offers a powerful free tier with a built-in SQL editor and API.
- Use `/sql/supabase_ddl.sql` to set up your tables in the Supabase Dashboard.
- **Why?**: It's a real-world production-grade database used by startups and enterprises.

### 2. Built-in: Interactive Studio (Browser)
Open `/app/index.html` using a local web server (e.g., Live Server in VS Code). 
- **Features**: SQL Editor, Schema Browser, and Scenario Lab.
- **Data**: Over 2,500 records across 4 core tables.

### 3. Local Big Data: DuckDB
For complex analytics (Window functions, Pivot, etc.):
- Run `/sql/duckdb_practice.py` to set up a local OLAP environment.
- **Why?**: DuckDB is the industry-leading free alternative to Databricks for fast local analysis.

## 📈 Practice Scenarios
Become an expert by solving these business problems:

| Category | Requirement | SQL Skill |
| :--- | :--- | :--- |
| **Growth** | Find countries where we have the highest concentration of employees. | Group By, Order By |
| **Risk** | Identify claims where 'Paid Amount' is 0 but status isn't 'DENIED'. | Troubleshooting / Data Quality |
| **Product** | Which Product Line has the highest average claim value? | Joins, Aggregation |
| **HR** | Calculate the average salary of employees per Industry. | Multi-level Joins |
| **Finance** | List top 5 employers by total premium revenue (Paid + Pending). | Complex Aggregates |

## 🔗 Technical Concepts Covered
- **MDM (Master Data Management)**: Managing Employers and Employees.
- **Claims Lifecycle**: Linking Products to Claims via Enrollments.
- **Global Operations**: Handling multiple countries and currencies (USD focus).
- **LOB Analysis**: Comparing Life, Dental, and Pet insurance performance.
