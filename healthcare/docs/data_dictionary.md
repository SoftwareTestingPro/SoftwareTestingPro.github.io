# Data Dictionary & Source-to-Target Mapping (STM)

This document outlines the schema for the practice database and how data flows from source application systems to the analytical warehouse (Azure Synapse).

## 1. Table: dim_employers (Source: Customer Onboarding App)
| Field Name | Data Type | Description | Mapping Logic |
| :--- | :--- | :--- | :--- |
| employer_id | INT | Unique PK for the company | MD5 Hash of Business License No |
| employer_name | VARCHAR(255) | Legal name of the entity | Trim(SRC_NAME) |
| industry | VARCHAR(100) | Sector (Tech, Finance, etc) | Classify based on NAICS code |
| country_code | CHAR(2) | Primary operating country | ISO 3166-1 alpha-2 |
| onboarding_date | DATE | Date the group joined | First record in Onboarding DB |

## 2. Table: dim_employees (Source: Enrollment App)
| Field Name | Data Type | Description | Mapping Logic |
| :--- | :--- | :--- | :--- |
| employee_id | INT | Unique PK for employee | System Generated |
| employer_id | INT | FK to dim_employers | Lookup via Group ID |
| full_name | VARCHAR(255) | Concatenated First + Last | CONCAT(F_NAME, ' ', L_NAME) |
| gender | CHAR(1) | M/F/O | Map system codes to M/F/O |
| hire_date | DATE | Employment start date | Direct from HR Source |

## 3. Table: fact_claims (Source: Product Admin Systems)
| Field Name | Data Type | Description | Mapping Logic |
| :--- | :--- | :--- | :--- |
| claim_id | BIGINT | Unique PK for claim | Batch ID + Seq |
| enrollment_id | INT | FK to Enrollment | JOIN dim_enrollments on MemberID |
| claim_amount | DECIMAL(18,2) | Total billed amount | Direct from Claims App |
| paid_amount | DECIMAL(18,2) | Amount paid by Shukla | Calculation: claim - adjustment |
| status | VARCHAR(20) | Process status | One of: 'PAID', 'DENIED', 'VOID' |

## 4. Source Application Systems
- **Onboarding App**: Main capture for B2B client contracts.
- **Enrollment App**: Self-service portal for employees to choose benefits.
- **PAS (Product Admin Systems)**: Individual legacy systems for Life vs Dental vs Pet.
- **Global Claims Engine**: Unified system that processes JSON payloads from various PAS.
