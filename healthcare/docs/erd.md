# Entity Relationship Diagram (ERD) - Shukla Healthcare

```mermaid
erDiagram
    EMPLOYER ||--o{ EMPLOYEE : employs
    EMPLOYER ||--o{ GROUP_POLICY : contracts
    PRODUCT ||--o{ GROUP_POLICY : defines
    GROUP_POLICY ||--o{ ENROLLMENT : allows
    EMPLOYEE ||--o{ ENROLLMENT : chooses
    ENROLLMENT ||--o{ CLAIM : generates
    PROVIDER ||--o{ CLAIM : performs
    PRODUCT_ADMIN_SYSTEM ||--o{ PRODUCT : manages

    EMPLOYER {
        int employer_id PK
        string name
        string industry
        string country
        string tax_id
    }

    EMPLOYEE {
        int employee_id PK
        int employer_id FK
        string first_name
        string last_name
        string email
        date dob
        string ssn
    }

    PRODUCT {
        int product_id PK
        string product_name "Life, Dental, Pet, etc."
        string line_of_business
        string base_currency
    }

    GROUP_POLICY {
        int policy_id PK
        int employer_id FK
        int product_id FK
        date effective_date
        date expiry_date
        decimal premium_rate
    }

    ENROLLMENT {
        int enrollment_id PK
        int employee_id FK
        int policy_id FK
        date enrollment_date
        string status "Active/Terminated"
    }

    CLAIM {
        int claim_id PK
        int enrollment_id FK
        int provider_id FK
        date service_date
        decimal claim_amount
        decimal paid_amount
        string status "Pending/Approved/Denied"
    }

    PROVIDER {
        int provider_id PK
        string provider_name
        string specialty
        string network_status "In-Network/Out-of-Network"
    }
```

## Business Narrative
Shukla Healthcare operates by signing contracts with **Employers** (Groups). Each contract results in a **Group Policy** for a specific **Product** (e.g., Dental). Once the policy is active, **Employees** can register via the **Enrollment** system. When an employee visits a **Provider**, a **Claim** is generated and processed against their active enrollment.
