import duckdb
import pandas as pd

# DuckDB is the free 'Local Databricks' alternative for OLAP analysis
# This script demonstrates how to analyze Shukla Healthcare data using DuckDB

def practice_duckdb():
    print("--- Shukla Healthcare DuckDB Analytics Studio ---")
    
    # 1. Connect to DuckDB (creates a local file healthcare.db)
    con = duckdb.connect('healthcare.db')
    
    # 2. Create tables from our CSV/Seed data (simulated here)
    # In a real scenario, you would do: 
    # con.execute("CREATE TABLE claims AS SELECT * FROM read_csv_auto('claims.csv')")
    
    # Let's create a sample view for the user to see how fast it is
    con.execute("CREATE TABLE IF NOT EXISTS practice_log (event_time TIMESTAMP, action TEXT)")
    con.execute("INSERT INTO practice_log VALUES (now(), 'DuckDB Studio Started')")
    
    # Example Analytical Query (Window Functions - Hard to do in simple tools, great for DuckDB)
    # This query finds the 'Running Total' of claim amounts per employee
    print("\n[Scenario] Running Window Functions for Trend Analysis:")
    # (Assuming tables exist, otherwise we show the syntax)
    print("""
    -- Practice this SQL in DuckDB:
    SELECT 
        employee_id,
        service_date,
        claim_amount,
        SUM(claim_amount) OVER (PARTITION BY employee_id ORDER BY service_date) as running_total
    FROM fact_claims;
    """)

    con.close()
    print("\nDuckDB environment ready. Practice file: healthcare.db created.")

if __name__ == "__main__":
    practice_duckdb()
