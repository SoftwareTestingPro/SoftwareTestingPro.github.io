# SQL Dialect Compatibility Guide

The Shukla Healthcare platform uses **SQLite** (via the browser) for the Web Playground and **Postgres/MySQL** for external tools. 

While 95% of standard SQL is identical, here are the key differences to keep in mind when switching between the **Web Studio** and **MySQL Workbench**.

## 1. Core SQL (Works in Both)
These commands are standard across ALL platforms:
- `SELECT`, `FROM`, `JOIN` (INNER, LEFT)
- `WHERE`, `GROUP BY`, `HAVING`, `ORDER BY`
- `COUNT()`, `SUM()`, `AVG()`, `MIN()`, `MAX()`
- `DISTINCT`, `LIMIT`, `IN`, `BETWEEN`, `LIKE`
- `CASE WHEN ... THEN ... ELSE END`
- `WITH` (Common Table Expressions)

## 2. Key Differences

| Feature | Web Studio (SQLite) | External (MySQL) |
| :--- | :--- | :--- |
| **Current Date** | `date('now')` | `CURDATE()` or `NOW()` |
| **Date Formatting** | `strftime('%Y-%m', date)` | `DATE_FORMAT(date, '%Y-%m')` |
| **Concatenation** | `'A' \|\| 'B'` | `CONCAT('A', 'B')` |
| **Auto-Increment** | `INTEGER PRIMARY KEY` | `INT PRIMARY KEY AUTO_INCREMENT` |
| **Case Sensitivity** | Usually case-insensitive | Configuration dependent (usually case-sensitive on Linux) |

## 3. Which one should I use?
- **Web Studio (SQLite)**: Best for learning **logic**, **reporting**, and **joining** data. This is what you'll encounter in most data analyst interviews.
- **MySQL/Postgres**: Best for learning **performance tuning**, **indexing**, and **database administration** (DBA roles).

## 4. Pro Tip: Standard SQL
To keep your queries compatible with *both* places, try to use **Standard SQL**:
Instead of platform-specific shortcuts, use standard syntax like:
```sql
SELECT employer_name FROM dim_employers WHERE country_code = 'US'; -- Works Everywhere
```
