import json
import requests
from xml.sax.saxutils import escape
from datetime import datetime
import os
import re
import sys
import time

def clear_previous_sync_data():
    import shutil
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    
    # 1. Clear Reports folder
    reports_dir = os.path.join(base_dir, "Reports")
    if os.path.exists(reports_dir):
        for item in os.listdir(reports_dir):
            item_path = os.path.join(reports_dir, item)
            try:
                if os.path.isdir(item_path):
                    shutil.rmtree(item_path)
                elif os.path.isfile(item_path):
                    os.remove(item_path)
            except Exception as e:
                print(f"Error removing report item {item_path}: {e}")
        print("Cleared all files and folders inside Reports folder.")
        
    # 2. Clear Logs folder (preserving active process logs)
    logs_dir = os.path.join(base_dir, "Logs")
    if os.path.exists(logs_dir):
        for item in os.listdir(logs_dir):
            if item not in ["tally_sync_stdout.log", "tally_sync_stderr.log"]:
                item_path = os.path.join(logs_dir, item)
                try:
                    if os.path.isdir(item_path):
                        shutil.rmtree(item_path)
                    elif os.path.isfile(item_path):
                        os.remove(item_path)
                except Exception as e:
                    print(f"Error removing log item {item_path}: {e}")
        print("Cleared all non-active log files and folders inside Logs folder.")
        
        # 3. Truncate active process logs to 0 bytes so they only contain the latest run details
        for log_file in ["tally_sync_stdout.log", "tally_sync_stderr.log"]:
            log_path = os.path.join(logs_dir, log_file)
            if os.path.exists(log_path):
                try:
                    with open(log_path, "w", encoding="utf-8") as f:
                        f.truncate(0)
                except Exception:
                    pass

if os.environ.get("TALLY_SYNC_SCHEDULER") != "1":
    clear_previous_sync_data()

# Define working directory and log paths
working_dir = os.path.dirname(os.path.abspath(__file__))
logs_dir = os.path.abspath(os.path.join(working_dir, "..", "Logs"))
os.makedirs(logs_dir, exist_ok=True)

stdout_log_path = os.path.join(logs_dir, "tally_sync_stdout.log")
stderr_log_path = os.path.join(logs_dir, "tally_sync_stderr.log")

class TeeStdout:
    def __init__(self, original_stdout, log_file):
        self.original_stdout = original_stdout
        self.log_file = log_file

    def write(self, message):
        # 1. Write to original stdout (Console)
        if self.original_stdout:
            self.original_stdout.write(message)
            self.original_stdout.flush()
        # 2. Write/Append to log file directly
        try:
            with open(self.log_file, "a", encoding="utf-8") as f:
                f.write(message)
                f.flush()
        except Exception:
            pass

    def flush(self):
        if self.original_stdout:
            self.original_stdout.flush()

class TeeStderr:
    def __init__(self, original_stderr, log_file):
        self.original_stderr = original_stderr
        self.log_file = log_file

    def write(self, message):
        if message.strip():
            timestamp = time.strftime("[%Y-%m-%d %H:%M:%S] ")
            lines = message.splitlines()
            formatted = "\n".join([f"{timestamp}{line}" for line in lines if line])
            if message.endswith("\n"):
                formatted += "\n"
        else:
            formatted = message

        # 1. Write to original stderr (Console)
        if self.original_stderr:
            self.original_stderr.write(formatted)
            self.original_stderr.flush()
        # 2. Write/Append to log file directly
        try:
            with open(self.log_file, "a", encoding="utf-8") as f:
                f.write(formatted)
                f.flush()
        except Exception:
            pass

    def flush(self):
        if self.original_stderr:
            self.original_stderr.flush()

sys.stdout = TeeStdout(sys.stdout, stdout_log_path)
sys.stderr = TeeStderr(sys.stderr, stderr_log_path)

import socket
def check_tally_port(host, port):
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(2)
            s.connect((host, port))
            return True
    except Exception:
        return False

if not check_tally_port("localhost", 9000):
    sys.stderr.write("Tally API port 9000 is inactive. Please ensure Tally is running and the company is opened.\n")
    sys.exit(1)

TALLY_URL = "http://localhost:9000"

# Map operational transaction categories to proper financial ledger accounts
LEDGER_MAPPING = {
    "Pharmacy-Issue": "Pharmacy Sales",
    "Pharmacy-Return": "Pharmacy Returns"
}

def get_ledger_name(trans_type):
    return LEDGER_MAPPING.get(trans_type, trans_type)

# =========================================================
# CONFIGURATION
# Set to a local file path (e.g. "tally_sales1.json") or an API URL (e.g. "https://api.example.com/sales")
# =========================================================
SOURCE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "Source_Data", "Sales", "tally_sales.json"))


# -----------------------------
# FUNCTION: LOAD SOURCE DATA
# -----------------------------

def load_source_data(source):
    if source.startswith("http://") or source.startswith("https://"):
        print(f"Fetching source data from API: {source}")
        response = requests.get(source, timeout=30)
        response.raise_for_status()
        return response.json()
    else:
        print(f"Loading source data from local file: {source}")
        with open(source, "r", encoding="utf-8") as file:
            return json.load(file)


# =========================================================
# CREATE CUSTOMER LEDGER
# =========================================================

def create_customer_ledger(customer_name, receipt_no, ledger_type):
    ledger_xml = f"""
    <ENVELOPE>
     <HEADER>
      <TALLYREQUEST>Import Data</TALLYREQUEST>
     </HEADER>
     <BODY>
      <IMPORTDATA>
       <REQUESTDESC>
        <REPORTNAME>All Masters</REPORTNAME>
       </REQUESTDESC>
       <REQUESTDATA>
        <TALLYMESSAGE>
         <LEDGER NAME="{customer_name}" ACTION="Create">
          <NAME>{customer_name}</NAME>
          <PARENT>Sundry Debtors</PARENT>
         </LEDGER>
        </TALLYMESSAGE>
       </REQUESTDATA>
      </IMPORTDATA>
     </BODY>
    </ENVELOPE>
    """
    try:
        # Increased timeout to 30 seconds to handle busy Tally instances
        requests.post(TALLY_URL, data=ledger_xml.encode("utf-8"), timeout=30)
        print(f"[{ledger_type} Ledger Verification] Verified/Created Customer Account: {customer_name}")
    except Exception as e:
        print(f"[{ledger_type} Ledger Verification] Failed to Verify/Create Customer Account {customer_name}: {e}")


def create_sales_ledger(ledger_name, receipt_no, ledger_type):
    ledger_xml = f"""
    <ENVELOPE>
     <HEADER>
      <TALLYREQUEST>Import Data</TALLYREQUEST>
     </HEADER>
     <BODY>
      <IMPORTDATA>
       <REQUESTDESC>
        <REPORTNAME>All Masters</REPORTNAME>
       </REQUESTDESC>
       <REQUESTDATA>
        <TALLYMESSAGE>
         <LEDGER NAME="{ledger_name}" ACTION="Create">
          <NAME>{ledger_name}</NAME>
          <PARENT>Sales Accounts</PARENT>
         </LEDGER>
        </TALLYMESSAGE>
       </REQUESTDATA>
      </IMPORTDATA>
     </BODY>
    </ENVELOPE>
    """
    try:
        requests.post(TALLY_URL, data=ledger_xml.encode("utf-8"), timeout=30)
        print(f"[{ledger_type} Ledger Verification] Verified/Created Standard Sales Account: {ledger_name}")
    except Exception as e:
        print(f"[{ledger_type} Ledger Verification] Failed to Verify/Create Standard Sales Account {ledger_name}: {e}")


# =========================================================
# TARGETED VOUCHER CHECK (FAST BATCH VERIFICATION)
# =========================================================

def check_existing_vouchers(tally_url, voucher_numbers):
    if not voucher_numbers:
        return set()
        
    filter_conditions = " OR ".join([f'($VoucherNumber = "{num}" OR $Reference = "{num}")' for num in voucher_numbers])
    
    # Using a high-performance custom TDL Collection instead of the heavy "Voucher Register" report.
    # This avoids layout computations in Tally and queries the data layer directly, preventing timeouts.
    xml = f"""<ENVELOPE>
     <HEADER>
      <VERSION>1</VERSION>
      <TALLYREQUEST>Export</TALLYREQUEST>
      <TYPE>Collection</TYPE>
      <ID>CustomVoucherCollection</ID>
     </HEADER>
     <BODY>
      <DESC>
       <STATICVARIABLES>
        <SVEXPORTFORMAT>$$SysName:XML</SVEXPORTFORMAT>
       </STATICVARIABLES>
       <TDL>
        <TDLMESSAGE>
         <COLLECTION NAME="CustomVoucherCollection" ISINITIALIZE="Yes">
          <TYPE>Voucher</TYPE>
          <FETCH>VoucherNumber</FETCH>
          <FETCH>Reference</FETCH>
          <FILTER>VoucherFilter</FILTER>
         </COLLECTION>
         <SYSTEM TYPE="Formulae" NAME="VoucherFilter">
          {filter_conditions}
         </SYSTEM>
        </TDLMESSAGE>
       </TDL>
      </DESC>
     </BODY>
    </ENVELOPE>"""
    
    try:
        response = requests.post(tally_url, data=xml.encode("utf-8"), timeout=45)
        if response.status_code == 200:
            found = set(re.findall(r"<VOUCHERNUMBER>(.*?)</VOUCHERNUMBER>", response.text, re.IGNORECASE))
            if not found:
                found = set(re.findall(r"<VOUCHER_NUMBER>(.*?)</VOUCHER_NUMBER>", response.text, re.IGNORECASE))
            
            # Also capture reference numbers for duplicate checking
            references = set(re.findall(r"<REFERENCE>(.*?)</REFERENCE>", response.text, re.IGNORECASE))
            found.update(references)
            
            return {v.strip() for v in found}
    except Exception as e:
        print(f"Error checking existing vouchers: {e}")
        # Propagate the connection/timeout exception up so we can abort the bulk loop immediately
        raise e
    return set()


def check_existing_vouchers_bulk(tally_url, voucher_numbers):
    voucher_list = list(voucher_numbers)
    existing = set()
    chunk_size = 100
    for i in range(0, len(voucher_list), chunk_size):
        chunk = voucher_list[i:i+chunk_size]
        try:
            found = check_existing_vouchers(tally_url, chunk)
            existing.update(found)
        except Exception as e:
            print(f"Connection to Tally failed during duplicate check. Aborting remaining checks to prevent hang.")
            raise e
    return existing

def fetch_existing_receipts_from_tally(tally_url):
    xml = """<ENVELOPE>
     <HEADER>
      <VERSION>1</VERSION>
      <TALLYREQUEST>Export</TALLYREQUEST>
      <TYPE>Collection</TYPE>
      <ID>CustomNarrationCollection</ID>
     </HEADER>
     <BODY>
      <DESC>
       <STATICVARIABLES>
        <SVEXPORTFORMAT>$$SysName:XML</SVEXPORTFORMAT>
       </STATICVARIABLES>
       <TDL>
        <TDLMESSAGE>
         <COLLECTION NAME="CustomNarrationCollection" ISINITIALIZE="Yes">
          <TYPE>Voucher</TYPE>
          <FILTER>JournalFilter</FILTER>
          <FETCH>Narration</FETCH>
         </COLLECTION>
         <SYSTEM TYPE="Formulae" NAME="JournalFilter">
          $VoucherTypeName = "Journal"
         </SYSTEM>
        </TDLMESSAGE>
       </TDL>
      </DESC>
     </BODY>
    </ENVELOPE>"""
    existing_receipts = set()
    try:
        response = requests.post(tally_url, data=xml.encode("utf-8"), timeout=30)
        if response.status_code == 200:
            narrations = re.findall(r"<NARRATION[^>]*>(.*?)</NARRATION>", response.text, re.IGNORECASE)
            for narr in narrations:
                receipts = re.findall(r"[A-Z0-9-]{6,}", narr)
                for r in receipts:
                    if r not in ["DAILY", "AGGREGATED", "JOURNAL", "ENTRY", "RECEIPTS"]:
                        existing_receipts.add(r)
    except Exception as e:
        print(f"Error checking existing receipts in Tally: {e}")
    return existing_receipts

def load_already_synced_receipts():
    synced_receipts = set()
    processed_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "Reports", "processed_records"))
    if os.path.exists(processed_dir):
        for file in os.listdir(processed_dir):
            if file.startswith("processed_journals_") and file.endswith(".txt"):
                try:
                    with open(os.path.join(processed_dir, file), "r", encoding="utf-8") as f:
                        for line in f:
                            match = re.search(r"Receipts:\s*(.*)", line)
                            if match:
                                receipts = [r.strip() for r in match.group(1).split(",") if r.strip()]
                                synced_receipts.update(receipts)
                except Exception:
                    pass
    return synced_receipts







# =========================================================
# SAVE MONTH-WISE TEXT RECORDS
# =========================================================

def save_month_wise_records(records_by_month, folder, prefix, identifier_key):
    if not records_by_month:
        return
    os.makedirs(folder, exist_ok=True)
    for month_year, items in records_by_month.items():
        file_name = f"{prefix}{month_year}.txt"
        file_path = os.path.join(folder, file_name)
        
        try:
            with open(file_path, "w", encoding="utf-8") as f:
                for idx, item in enumerate(items):
                    sn = idx + 1
                    ref_no = item.get("id") or "N/A"
                    reason = item.get("reason", "")
                    timestamp = item.get("timestamp") or datetime.now().strftime("%d %m %Y %H:%M:%S")
                    
                    line = f"{sn} [{timestamp}] {identifier_key}: {ref_no}"
                    if item.get("receipt_nos"):
                        line += f" | Receipts: {', '.join(item.get('receipt_nos'))}"
                    if reason:
                        line += f" | Reason: {reason}"
                    f.write(line + "\n")
            print(f"Wrote {len(items)} records to {file_path}")
        except Exception as e:
            print(f"Error saving to {file_path}: {e}")





# =========================================================
# LOAD SOURCE DATA
# =========================================================

try:
    data = load_source_data(SOURCE)
    records = data.get("rows", [])
except Exception as e:
    print(f"Failed to load sync data: {e}")
    records = []

if not records:
    print("No records to process. Exiting.")
    exit(0)


# =========================================================
# LEDGER CREATION HELPER
# =========================================================

def create_tally_ledger(ledger_name, parent_name):
    escaped_ledger = escape(str(ledger_name).strip())
    escaped_parent = escape(str(parent_name).strip())
    ledger_xml = f"""
    <ENVELOPE>
     <HEADER>
      <TALLYREQUEST>Import Data</TALLYREQUEST>
     </HEADER>
     <BODY>
      <IMPORTDATA>
       <REQUESTDESC>
        <REPORTNAME>All Masters</REPORTNAME>
       </REQUESTDESC>
       <REQUESTDATA>
        <TALLYMESSAGE>
         <LEDGER NAME="{escaped_ledger}" ACTION="Create">
          <NAME>{escaped_ledger}</NAME>
          <PARENT>{escaped_parent}</PARENT>
         </LEDGER>
        </TALLYMESSAGE>
       </REQUESTDATA>
      </IMPORTDATA>
     </BODY>
    </ENVELOPE>
    """
    try:
        response = requests.post(TALLY_URL, data=ledger_xml.encode("utf-8"), timeout=30)
        print(f"[Ledger Verification] Verified/Created Ledger: {ledger_name} (Parent: {parent_name})")
    except Exception as e:
        print(f"[Ledger Verification] Failed to Verify/Create Ledger {ledger_name}: {e}")

# =========================================================
# LOAD SOURCE DATA
# =========================================================

try:
    data = load_source_data(SOURCE)
    records = data.get("rows", [])
except Exception as e:
    print(f"Failed to load sync data: {e}")
    records = []

if not records:
    print("No records to process. Exiting.")
    exit(0)

# Create SALES IMPEREST A/C ledger
create_tally_ledger("SALES IMPEREST A/C", "Sundry Debtors")

# Dynamic verification/creation of sales/GST ledgers based on GSTPer in incoming data
created_ledgers = set()
for item in records:
    gst_per_val = item.get("GSTPer")
    if gst_per_val is None:
        continue
    try:
        gst_per = float(gst_per_val)
    except ValueError:
        continue
        
    if gst_per <= 0:
        sales_ledger = "SALES GST EXEMPTED"
        if sales_ledger not in created_ledgers:
            create_tally_ledger(sales_ledger, "Sales Accounts")
            created_ledgers.add(sales_ledger)
    else:
        sales_ledger = f"SALES GST @ {int(gst_per)}%"
        gst_ledger = f"GST OUTPUT @ {int(gst_per)}%"
        if sales_ledger not in created_ledgers:
            create_tally_ledger(sales_ledger, "Sales Accounts")
            created_ledgers.add(sales_ledger)
        if gst_ledger not in created_ledgers:
            create_tally_ledger(gst_ledger, "Duties & Taxes")
            created_ledgers.add(gst_ledger)

# Extract unique dates and map them to their formatted Journal voucher number JRN-YYYYMMDD
records_by_date = {}
for item in records:
    sales_date_str = item.get("SalesTranDate")
    if not sales_date_str:
        continue
    sales_date = str(sales_date_str).strip()
    records_by_date.setdefault(sales_date, []).append(item)

incoming_voucher_nos = {f"JRN-{date}" for date in records_by_date.keys()}

# Fetch existing vouchers for duplicate checking
try:
    print(f"Performing targeted duplicate check for {len(incoming_voucher_nos)} aggregated daily journals...")
    existing_vouchers = check_existing_vouchers_bulk(TALLY_URL, incoming_voucher_nos)
    print(f"Targeted check complete. Found {len(existing_vouchers)} matching records already in Tally.")
except Exception as e:
    print(f"Tally check failed completely: {e}. Exiting this sync run to prevent invalid syncs.")
    exit(1)

# Fetch existing receipts to prevent duplicate syncs
try:
    print("Fetching already synced receipt numbers from Tally and local logs...")
    existing_receipts = fetch_existing_receipts_from_tally(TALLY_URL)
    existing_receipts.update(load_already_synced_receipts())
    print(f"Loaded {len(existing_receipts)} unique receipt numbers already in Tally/logs.")
except Exception as e:
    print(f"Warning: failed to load existing receipt numbers: {e}")
    existing_receipts = set()

# =========================================================
# COUNTERS & MONTHLY STORAGE
# =========================================================

records_success = 0
records_skipped = 0
journal_success = 0
journal_failed = 0
journal_skipped = 0
journal_duplicate = 0

processed_journals_by_month = {}
failed_journals_by_month = {}
skipped_journals_by_month = {}

# =========================================================
# PROCESS DAILY AGGREGATIONS
# =========================================================

for sales_date, group_records in sorted(records_by_date.items()):
    voucher_no = f"JRN-{sales_date}"
    
    # Determine month for record partitioning
    month_str = "Unknown"
    try:
        dt = datetime.strptime(sales_date, "%Y%m%d")
        month_str = dt.strftime("%b_%Y")
    except Exception:
        pass

    # Duplicate check
    if voucher_no in existing_vouchers:
        print(f"[Journal Sync] DUPLICATE (Reason: Record already exists in Tally): {voucher_no}")
        records_skipped += len(group_records)
        timestamp = datetime.now().strftime("%d %m %Y %H:%M:%S")
        skipped_journals_by_month.setdefault(month_str, []).append({
            "id": voucher_no,
            "timestamp": timestamp,
            "reason": "Record already exists in Tally"
        })
        continue

    # Accumulators for this day's entries
    issues_by_ledger = {}   # ledger_name -> {"sales_amount": 0.0, "gst_amount": 0.0}
    returns_by_ledger = {}  # ledger_name -> {"sales_amount": 0.0, "gst_amount": 0.0}
    total_issues_paid = 0.0
    total_returns_paid = 0.0
    processed_receipts = []

    valid_record_count = 0
    for item in group_records:
        receipt_no = item.get("ReceiptNo")
        if receipt_no and receipt_no in existing_receipts:
            reason = f"Already exists in Tally."
            print(f"[Journal Sync] Record SKIPPED (Reason: {reason}): {item.get('PatientName') or 'Unknown'}")
            records_skipped += 1
            timestamp = datetime.now().strftime("%d %m %Y %H:%M:%S")
            skipped_journals_by_month.setdefault(month_str, []).append({
                "id": receipt_no,
                "timestamp": timestamp,
                "reason": reason
            })
            continue

        if item.get("ReceiptNo") is None or item.get("AmountPaid") is None:
            reason = f"Missing mandatory field(s): ReceiptNo={item.get('ReceiptNo')}, AmountPaid={item.get('AmountPaid')}"
            print(f"[Journal Sync] Record SKIPPED (Reason: {reason}): {item.get('PatientName') or 'Unknown'}")
            records_skipped += 1
            
            # Record to skipped logs
            timestamp = datetime.now().strftime("%d %m %Y %H:%M:%S")
            skipped_journals_by_month.setdefault(month_str, []).append({
                "id": item.get('ReceiptNo') or "N/A",
                "timestamp": timestamp,
                "reason": reason
            })
            continue
        
        is_return = (item.get("TransType") == "Pharmacy-Return")
        
        try:
            gst_per = float(item.get("GSTPer") or 0.0)
            total = round(float(item.get("AmountPaid") or 0.0), 2)
            cgst = round(float(item.get("CGSTAmt") or 0.0), 2)
            sgst = round(float(item.get("SGSTAmt") or 0.0), 2)
            igst = round(float(item.get("IGSTAmt") or 0.0), 2)
            
            # Calculate taxable sales and GST amount directly from JSON values
            gst_amount = round(abs(cgst) + abs(sgst) + abs(igst), 2)
            sales_amount = round(abs(total) - gst_amount, 2)
            
            if sales_amount < 0:
                reason = f"Invalid GST calculation (Sales Amount is negative: {sales_amount})"
                print(f"[Journal Sync] Record SKIPPED (Reason: {reason}): {item.get('PatientName') or 'Unknown'} (Receipt No: {item.get('ReceiptNo') or 'N/A'})")
                
                # Record to skipped logs
                timestamp = datetime.now().strftime("%d %m %Y %H:%M:%S")
                skipped_journals_by_month.setdefault(month_str, []).append({
                    "id": item.get('ReceiptNo') or "N/A",
                    "timestamp": timestamp,
                    "reason": reason
                })
                records_skipped += 1
                continue
                
            # Determine ledger names
            if gst_per <= 0:
                sales_ledger = "SALES GST EXEMPTED"
                gst_ledger = None
            else:
                sales_ledger = f"SALES GST @ {int(gst_per)}%"
                gst_ledger = f"GST OUTPUT @ {int(gst_per)}%"
                
            if is_return:
                total_returns_paid += abs(total)
                r_data = returns_by_ledger.setdefault(sales_ledger, {"sales_amount": 0.0, "gst_amount": 0.0})
                r_data["sales_amount"] += abs(total)
                if gst_ledger:
                    rg_data = returns_by_ledger.setdefault(gst_ledger, {"sales_amount": 0.0, "gst_amount": 0.0})
                    rg_data["gst_amount"] += gst_amount
            else:
                total_issues_paid += abs(total)
                i_data = issues_by_ledger.setdefault(sales_ledger, {"sales_amount": 0.0, "gst_amount": 0.0})
                i_data["sales_amount"] += abs(total)
                if gst_ledger:
                    ig_data = issues_by_ledger.setdefault(gst_ledger, {"sales_amount": 0.0, "gst_amount": 0.0})
                    ig_data["gst_amount"] += gst_amount
                    
            processed_receipts.append(item.get("ReceiptNo"))
            valid_record_count += 1
        except Exception as e:
            print(f"[Journal Sync] Warning: failed to parse record in date {sales_date}: {e}")
            continue

    if valid_record_count == 0:
        print(f"[Journal Sync] SKIPPED (Reason: No valid records to aggregate): {voucher_no}")
        journal_skipped += 1
        continue

    # Filter, group and sort returns (Debits)
    sales_returns = []
    gst_returns = []
    exempt_returns = []
    for ledger_name, data in returns_by_ledger.items():
        val = round(data["sales_amount"] + data["gst_amount"], 2)
        if val > 0:
            if ledger_name.startswith("SALES GST @"):
                sales_returns.append((ledger_name, val))
            elif ledger_name.startswith("GST OUTPUT @"):
                gst_returns.append((ledger_name, val))
            elif ledger_name == "SALES GST EXEMPTED":
                exempt_returns.append((ledger_name, val))

    def get_gst_rate(item):
        name = item[0]
        match = re.search(r"@\s*(\d+)%", name)
        return int(match.group(1)) if match else 0

    sales_returns.sort(key=get_gst_rate)
    gst_returns.sort(key=get_gst_rate)
    ordered_returns = sales_returns + gst_returns + exempt_returns

    # Filter, group and sort issues (Credits)
    sales_issues = []
    gst_issues = []
    exempt_issues = []
    for ledger_name, data in issues_by_ledger.items():
        val = round(data["sales_amount"] + data["gst_amount"], 2)
        if val > 0:
            if ledger_name.startswith("SALES GST @"):
                sales_issues.append((ledger_name, val))
            elif ledger_name.startswith("GST OUTPUT @"):
                gst_issues.append((ledger_name, val))
            elif ledger_name == "SALES GST EXEMPTED":
                exempt_issues.append((ledger_name, val))

    sales_issues.sort(key=get_gst_rate)
    gst_issues.sort(key=get_gst_rate)
    ordered_issues = sales_issues + gst_issues + exempt_issues

    # Construct the ledger entries in the exact required sequence
    ledger_xml_entries = []

    # 1. Debit entries (By) - returns
    total_debits = 0.0
    for ledger_name, val in ordered_returns:
        total_debits += val
        ledger_xml_entries.append(f"""
              <ALLLEDGERENTRIES.LIST>
               <LEDGERNAME>{escape(ledger_name)}</LEDGERNAME>
               <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>
               <AMOUNT>-{val}</AMOUNT>
              </ALLLEDGERENTRIES.LIST>
            """)

    # 2. Credit entries (To) - issues
    total_credits = 0.0
    for ledger_name, val in ordered_issues:
        total_credits += val
        ledger_xml_entries.append(f"""
              <ALLLEDGERENTRIES.LIST>
               <LEDGERNAME>{escape(ledger_name)}</LEDGERNAME>
               <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>
               <AMOUNT>{val}</AMOUNT>
              </ALLLEDGERENTRIES.LIST>
            """)

    # 3. SALES IMPEREST A/C entries (Self-balancing) - last
    if total_credits > 0:
        # Debit SALES IMPEREST A/C for total issues
        ledger_xml_entries.append(f"""
              <ALLLEDGERENTRIES.LIST>
               <LEDGERNAME>SALES IMPEREST A/C</LEDGERNAME>
               <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>
               <AMOUNT>-{round(total_credits, 2)}</AMOUNT>
              </ALLLEDGERENTRIES.LIST>
        """)
    if total_debits > 0:
        # Credit SALES IMPEREST A/C for total returns
        ledger_xml_entries.append(f"""
              <ALLLEDGERENTRIES.LIST>
               <LEDGERNAME>SALES IMPEREST A/C</LEDGERNAME>
               <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>
               <AMOUNT>{round(total_debits, 2)}</AMOUNT>
              </ALLLEDGERENTRIES.LIST>
        """)

    # Combine ledger list into string
    ledger_entries_str = "\n".join(ledger_xml_entries)

    # GENERATE JOURNAL VOUCHER XML
    voucher_xml = f"""
    <ENVELOPE>
     <HEADER>
      <TALLYREQUEST>Import Data</TALLYREQUEST>
     </HEADER>
     <BODY>
      <IMPORTDATA>
       <REQUESTDESC>
        <REPORTNAME>Vouchers</REPORTNAME>
       </REQUESTDESC>
       <REQUESTDATA>
        <TALLYMESSAGE>
         <VOUCHER VCHTYPE="Journal" ACTION="Create">
          <ISOPTIONAL>No</ISOPTIONAL>
          <DATE>{sales_date}</DATE>
          <VOUCHERNUMBER>{voucher_no}</VOUCHERNUMBER>
          <REFERENCE>{voucher_no}</REFERENCE>
          <VOUCHERTYPENAME>Journal</VOUCHERTYPENAME>
          <PARTYLEDGERNAME>SALES IMPEREST A/C</PARTYLEDGERNAME>
          <NARRATION>Daily Aggregated Journal Entry. Receipts: {', '.join(processed_receipts)}</NARRATION>
          {ledger_entries_str}
         </VOUCHER>
        </TALLYMESSAGE>
       </REQUESTDATA>
      </IMPORTDATA>
     </BODY>
    </ENVELOPE>
    """

    # SEND XML TO TALLY
    timestamp = datetime.now().strftime("%d %m %Y %H:%M:%S")
    log_entry = {"id": voucher_no, "timestamp": timestamp}
    
    try:
        response = requests.post(TALLY_URL, data=voucher_xml.encode("utf-8"), timeout=15)
        response_text = response.text

        if "<CREATED>1</CREATED>" in response_text:
            existing_vouchers.add(voucher_no)
            journal_success += 1
            records_success += valid_record_count
            # Add processed receipt numbers list to the processed log
            log_entry["receipt_nos"] = processed_receipts
            processed_journals_by_month.setdefault(month_str, []).append(log_entry)
            print(f"[Journal Sync] SUCCESS (Journal successfully pushed to Tally): {voucher_no}")
        else:
            err_match = re.search(r"<LINEERROR>(.*?)</LINEERROR>", response_text, re.IGNORECASE)
            err_msg = err_match.group(1) if err_match else "Import failed (unspecified Tally error)"
            log_entry["reason"] = err_msg
            journal_failed += 1
            records_skipped += valid_record_count
            skipped_journals_by_month.setdefault(month_str, []).append(log_entry)
            print(f"[Journal Sync] FAILED ({err_msg}): {voucher_no}")
            print(response_text)
    except Exception as e:
        log_entry["reason"] = str(e)
        journal_failed += 1
        records_skipped += valid_record_count
        skipped_journals_by_month.setdefault(month_str, []).append(log_entry)
        print(f"[Journal Sync] FAILED (Exception: {e}): {voucher_no}")

reports_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "Reports"))
save_month_wise_records(processed_journals_by_month, os.path.join(reports_dir, "processed_records"), "processed_journals_", "JournalNo")
save_month_wise_records(skipped_journals_by_month, os.path.join(reports_dir, "skipped_records"), "skipped_journals_", "JournalNo")

# =========================================================
# FINAL SUMMARY
# =========================================================
print("\n====================================")
print("JOURNAL SYNC SUMMARY")
print("====================================")
print(f"SUCCESS   : {records_success}")
print(f"SKIPPED   : {records_skipped}")
print("====================================")