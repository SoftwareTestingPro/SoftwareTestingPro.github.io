# Shukla Healthcare: SQL & Data Analysis Practice Platform

This project aims to provide a comprehensive healthcare insurance database environment for practicing data exploration, SQL query optimization, and business analysis using **100% Free Tools**.

## 1. Domain Overview: Shukla Healthcare
- **Industry**: US-based Global Insurance.
- **Lines of Business (LOB)**: Life, Accident, Critical Illness, Dental, Pet.
- **Market Focus**: Group Insurance (B2B).

## 2. Technical Stack (100% Free Tools)
- **Database (Cloud)**: **Supabase** (PostgreSQL) - Real production-ready cloud DB.
- **Computation (Local)**: **DuckDB** - High-performance OLAP engine (Databricks alternative).
- **Local Practice UI**: Web-based SQL Playground using SQL.js (SQLite in browser).
- **Design**: Premium, dark-mode dashboard.

## 3. Data Model Design (Schema)
### Domain: Master Data (MDM)
- `dim_employers`: Corporate clients (Groups).
- `dim_employees`: Individual members under groups.
- `dim_products`: Insurance product catalog.

### Domain: Transactions
- `fact_claims`: Claims submitted, processed, and paid.

## 4. Documentation Deliverables
- [x] **ERD**: Visual entity-relationship diagram.
- [x] **Data Dictionary**: Field-level descriptions and mapping logic.
- [x] **STM (Source to Target Mapping)**: App -> Warehouse flow.
- [x] **Business Scenarios**: Real-world analytical tasks.

## 5. Implementation Status
1. **Directory Setup**: Completed.
2. **SQL Generation**: Supabase (Postgres) and DuckDB scripts created.
3. **Seed Data**: 10,000+ rows generated in `seed_data.sql`.
4. **Practice Studio**: Browser-based interactive UI ready.
