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

# Extract invoice/receipt numbers to verify with Tally (Safely converting to str first)
incoming_receipt_nos = {str(item.get("ReceiptNo")).strip() for item in records if item.get("ReceiptNo")}

# Fetch existing vouchers for duplicate checking using fast targeted query
try:
    print(f"Performing targeted duplicate check for {len(incoming_receipt_nos)} incoming records...")
    existing_vouchers = check_existing_vouchers_bulk(TALLY_URL, incoming_receipt_nos)
    print(f"Targeted check complete. Found {len(existing_vouchers)} matching records already in Tally.")
except Exception as e:
    print(f"Tally check failed completely: {e}. Exiting this sync run to prevent invalid syncs.")
    exit(1)


# =========================================================
# CREATE CUSTOMER LEDGERS
# =========================================================

customers = set()
for item in records:
    patient_name = item.get("PatientName")
    if patient_name is None:
        continue
    customer = escape(str(patient_name).strip())
    if customer not in customers:
        receipt_no = item.get("ReceiptNo", "N/A")
        if str(receipt_no).strip() not in existing_vouchers:
            is_credit_note = (item.get("TransType") == "Pharmacy-Return")
            ledger_type = "Credit Note" if is_credit_note else "Sales"
            create_customer_ledger(customer, receipt_no, ledger_type)
            customers.add(customer)

# =========================================================
# CREATE SALES/RETURN LEDGERS (DYNAMIC TRANS-TYPES)
# =========================================================

sales_ledgers = set()
for item in records:
    trans_type_val = item.get("TransType")
    if trans_type_val is None:
        continue
    ledger_name = escape(str(get_ledger_name(trans_type_val)).strip())
    if ledger_name not in sales_ledgers:
        receipt_no = item.get("ReceiptNo", "N/A")
        if str(receipt_no).strip() not in existing_vouchers:
            is_credit_note = (trans_type_val == "Pharmacy-Return")
            ledger_type = "Credit Note" if is_credit_note else "Sales"
            create_sales_ledger(ledger_name, receipt_no, ledger_type)
            sales_ledgers.add(ledger_name)

# =========================================================
# COUNTERS & MONTHLY STORAGE
# =========================================================

sales_success = 0
sales_failed = 0
sales_skipped = 0
sales_duplicate = 0

credit_success = 0
credit_failed = 0
credit_skipped = 0
credit_duplicate = 0

processed_sales_by_month = {}
failed_sales_by_month = {}
skipped_sales_by_month = {}

processed_credit_by_month = {}
failed_credit_by_month = {}
skipped_credit_by_month = {}



# =========================================================
# PROCESS RECORDS
# =========================================================

for item in records:
    is_credit_note = (item.get("TransType") == "Pharmacy-Return")
    sales_date_str = item.get("SalesTranDate")

    # Determine month for record partitioning
    month_str = "Unknown"
    if sales_date_str:
        try:
            dt = datetime.strptime(str(sales_date_str).strip(), "%Y%m%d")
            month_str = dt.strftime("%b_%Y")
        except Exception:
            pass

    # SKIP INVALID RECORDS
    if (
        item.get("ReceiptNo") is None
        or item.get("AmountPaid") is None
        or item.get("PatientName") is None
    ):
        missing_fields = []
        if item.get("ReceiptNo") is None: missing_fields.append("ReceiptNo")
        if item.get("AmountPaid") is None: missing_fields.append("AmountPaid")
        if item.get("PatientName") is None: missing_fields.append("PatientName")
        reason = f"Missing mandatory field(s): {', '.join(missing_fields)}"
        
        timestamp = datetime.now().strftime("%d %m %Y %H:%M:%S")
        log_entry = {"id": item.get("ReceiptNo") or "N/A", "reason": reason, "timestamp": timestamp}
        
        if is_credit_note:
            credit_skipped += 1
            skipped_credit_by_month.setdefault(month_str, []).append(log_entry)
            print(f"[Credit Note Sync] SKIPPED (Reason: {reason}): {item.get('PatientName') or 'Unknown'} (Receipt No: {item.get('ReceiptNo') or 'N/A'})")
        else:
            sales_skipped += 1
            skipped_sales_by_month.setdefault(month_str, []).append(log_entry)
            print(f"[Sales Sync] SKIPPED (Reason: {reason}): {item.get('PatientName') or 'Unknown'} (Receipt No: {item.get('ReceiptNo') or 'N/A'})")
        continue

    try:
        # SAFE FIELD EXTRACTION
        receipt_no = escape(str(item.get("ReceiptNo")).strip())
        sales_date = escape(str(item.get("SalesTranDate")).strip())
        customer = escape(str(item.get("PatientName")).strip())
        
        trans_type = escape(str(item.get("TransType") or "Sales").strip())
        sales_ledger = escape(str(get_ledger_name(item.get("TransType") or "Sales")).strip())
        original_narration = escape(str(item.get("Narration") or "").strip())
        
        # Combine TransType and original Narration
        narration = f"TransType: {trans_type}"
        if original_narration:
            narration += f" | {original_narration}"
        
        total = round(float(item.get("AmountPaid") or 0), 2)
        cgst = round(float(item.get("CGSTAmt") or 0), 2)
        sgst = round(float(item.get("SGSTAmt") or 0), 2)
        igst = round(float(item.get("IGSTAmt") or 0), 2)

        # CALCULATE SALES AMOUNT
        sales_amount = round(abs(total) - abs(cgst) - abs(sgst) - abs(igst), 2)

        timestamp = datetime.now().strftime("%d %m %Y %H:%M:%S")
        log_entry = {"id": receipt_no, "timestamp": timestamp}

        # INVALID GST VALIDATION
        if sales_amount < 0:
            reason = f"Invalid GST calculation (Sales Amount is negative: {sales_amount})"
            log_entry["reason"] = reason
            if is_credit_note:
                credit_skipped += 1
                skipped_credit_by_month.setdefault(month_str, []).append(log_entry)
                print(f"[Credit Note Sync] SKIPPED (Reason: {reason}): {customer} (Receipt No: {receipt_no})")
            else:
                sales_skipped += 1
                skipped_sales_by_month.setdefault(month_str, []).append(log_entry)
                print(f"[Sales Sync] SKIPPED (Reason: {reason}): {customer} (Receipt No: {receipt_no})")
            continue

        # DUPLICATE CHECK (Safely converting to str)
        receipt_str = str(receipt_no).strip()
        
        if receipt_str in existing_vouchers:
            log_entry["reason"] = "Record already exists in Tally"
            if is_credit_note:
                credit_duplicate += 1
                skipped_credit_by_month.setdefault(month_str, []).append(log_entry)
                print(f"[Credit Note Sync] DUPLICATE (Reason: Record already exists in Tally): {customer} (Receipt No: {receipt_no})")
            else:
                sales_duplicate += 1
                skipped_sales_by_month.setdefault(month_str, []).append(log_entry)
                print(f"[Sales Sync] DUPLICATE (Reason: Record already exists in Tally): {customer} (Receipt No: {receipt_no})")
            continue

        # DETERMINE VOUCHER TYPE
        if is_credit_note:
            voucher_type = "Credit Note"
            customer_amount = abs(total)
            sales_ledger_amount = -abs(sales_amount)
            cgst_amount = -abs(cgst)
            sgst_amount = -abs(sgst)
        else:
            voucher_type = "Sales"
            customer_amount = -abs(total)
            sales_ledger_amount = abs(sales_amount)
            cgst_amount = abs(cgst)
            sgst_amount = abs(sgst)

        # GENERATE XML
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
             <VOUCHER VCHTYPE="{voucher_type}" ACTION="Create">
              <ISOPTIONAL>No</ISOPTIONAL>
              <DATE>{sales_date}</DATE>
              <VOUCHERNUMBER>{receipt_no}</VOUCHERNUMBER>
              <REFERENCE>{receipt_no}</REFERENCE>
              <VOUCHERTYPENAME>{voucher_type}</VOUCHERTYPENAME>
              <PARTYLEDGERNAME>{customer}</PARTYLEDGERNAME>
              <NARRATION>{narration}</NARRATION>
              
              <!-- CUSTOMER -->
              <ALLLEDGERENTRIES.LIST>
               <LEDGERNAME>{customer}</LEDGERNAME>
               <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>
               <AMOUNT>{customer_amount}</AMOUNT>
              </ALLLEDGERENTRIES.LIST>
              
              <!-- SALES / RETURN LEDGER -->
              <ALLLEDGERENTRIES.LIST>
               <LEDGERNAME>{sales_ledger}</LEDGERNAME>
               <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>
               <AMOUNT>{sales_ledger_amount}</AMOUNT>
              </ALLLEDGERENTRIES.LIST>
              
              <!-- CGST -->
              <ALLLEDGERENTRIES.LIST>
               <LEDGERNAME>CGST</LEDGERNAME>
               <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>
               <AMOUNT>{cgst_amount}</AMOUNT>
              </ALLLEDGERENTRIES.LIST>
              
              <!-- SGST -->
              <ALLLEDGERENTRIES.LIST>
               <LEDGERNAME>SGST</LEDGERNAME>
               <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>
               <AMOUNT>{sgst_amount}</AMOUNT>
              </ALLLEDGERENTRIES.LIST>
             </VOUCHER>
            </TALLYMESSAGE>
           </REQUESTDATA>
          </IMPORTDATA>
         </BODY>
        </ENVELOPE>
        """

        # SEND XML TO TALLY
        response = requests.post(TALLY_URL, data=voucher_xml.encode("utf-8"), timeout=15)
        response_text = response.text

        exec_timestamp = datetime.now().strftime("%d %m %Y %H:%M:%S")
        log_entry["timestamp"] = exec_timestamp

        # SUCCESS
        if "<CREATED>1</CREATED>" in response_text:
            existing_vouchers.add(receipt_str)
            if is_credit_note:
                credit_success += 1
                processed_credit_by_month.setdefault(month_str, []).append(log_entry)
                print(f"[Credit Note Sync] SUCCESS (Credit Note successfully pushed to Tally): {customer} (Receipt No: {receipt_no})")
            else:
                sales_success += 1
                processed_sales_by_month.setdefault(month_str, []).append(log_entry)
                print(f"[Sales Sync] SUCCESS (Receipt successfully pushed to Tally): {customer} (Receipt No: {receipt_no})")
        else:
            err_match = re.search(r"<LINEERROR>(.*?)</LINEERROR>", response_text, re.IGNORECASE)
            err_msg = err_match.group(1) if err_match else "Import failed (unspecified Tally error)"
            log_entry["reason"] = err_msg
            
            if is_credit_note:
                credit_failed += 1
                failed_credit_by_month.setdefault(month_str, []).append(log_entry)
                print(f"[Credit Note Sync] FAILED ({err_msg}): {customer} (Receipt No: {receipt_no})")
            else:
                sales_failed += 1
                failed_sales_by_month.setdefault(month_str, []).append(log_entry)
                print(f"[Sales Sync] FAILED ({err_msg}): {customer} (Receipt No: {receipt_no})")
            print(response_text)

    except Exception as e:
        log_entry["reason"] = str(e)
        if is_credit_note:
            credit_failed += 1
            failed_credit_by_month.setdefault(month_str, []).append(log_entry)
            print(f"[Credit Note Sync] FAILED (Exception: {e}): {customer} (Receipt No: {receipt_no})")
        else:
            sales_failed += 1
            failed_sales_by_month.setdefault(month_str, []).append(log_entry)
            print(f"[Sales Sync] FAILED (Exception: {e}): {customer} (Receipt No: {receipt_no})")

reports_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "Reports"))
save_month_wise_records(processed_sales_by_month, os.path.join(reports_dir, "processed_records"), "processed_sale_receipts_", "ReceiptNo")
save_month_wise_records(failed_sales_by_month, os.path.join(reports_dir, "failed_records"), "failed_sale_receipts_", "ReceiptNo")
save_month_wise_records(skipped_sales_by_month, os.path.join(reports_dir, "skipped_records"), "skipped_sale_receipts_", "ReceiptNo")

save_month_wise_records(processed_credit_by_month, os.path.join(reports_dir, "processed_records"), "processed_credit_note_receipts_", "ReceiptNo")
save_month_wise_records(failed_credit_by_month, os.path.join(reports_dir, "failed_records"), "failed_credit_note_receipts_", "ReceiptNo")
save_month_wise_records(skipped_credit_by_month, os.path.join(reports_dir, "skipped_records"), "skipped_credit_note_receipts_", "ReceiptNo")



# =========================================================
# FINAL SUMMARY
# =========================================================
print("\n====================================")
print("SALES SUMMARY")
print("====================================")
print(f"SUCCESS   : {sales_success}")
print(f"FAILED    : {sales_failed}")
print(f"SKIPPED   : {sales_skipped}")
print(f"DUPLICATE : {sales_duplicate}")

print("\n====================================")
print("CREDIT NOTE SUMMARY")
print("====================================")
print(f"SUCCESS   : {credit_success}")
print(f"FAILED    : {credit_failed}")
print(f"SKIPPED   : {credit_skipped}")
print(f"DUPLICATE : {credit_duplicate}")
print("====================================")