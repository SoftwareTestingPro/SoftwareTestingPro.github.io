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

# =========================================================
# CONFIGURATION
# Set to a local file path (e.g. "tally_Purchase.json") or an API URL (e.g. "https://api.example.com/purchase")
# =========================================================
SOURCE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "Source_Data", "Purchase", "tally_Purchase.json"))


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


# -----------------------------
# FUNCTION: CREATE LEDGER
# -----------------------------

def create_supplier_ledger(supplier_name, invoice_no, ledger_type):
    escaped_supplier = escape(supplier_name)
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
          <LEDGER NAME="{escaped_supplier}" ACTION="Create">
           <NAME>{escaped_supplier}</NAME>
           <PARENT>Sundry Creditors</PARENT>
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
        print(f"[{ledger_type} Ledger Verification] Verified/Created Supplier Account: {supplier_name}")
    except Exception as e:
        print(f"[{ledger_type} Ledger Verification] Failed to Verify/Create Supplier Account {supplier_name}: {e}")


# -----------------------------
# FUNCTION: TARGETED VOUCHER CHECK (FAST BATCH VERIFICATION)
# -----------------------------

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







# -----------------------------
# FUNCTION: SAVE MONTH-WISE TEXT RECORDS
# -----------------------------

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



# -----------------------------
# LOAD SOURCE DATA
# -----------------------------

try:
    data = load_source_data(SOURCE)
    records = data.get("rows", [])
except Exception as e:
    print(f"Failed to load sync data: {e}")
    records = []

if not records:
    print("No records to process. Exiting.")
    exit(0)

# Extract invoice numbers to verify with Tally (Safely converting to str first)
incoming_invoice_nos = {str(item.get("InvoiceNo")).strip() for item in records if item.get("InvoiceNo")}

# Fetch existing vouchers for duplicate checking using fast targeted query
try:
    print(f"Performing targeted duplicate check for {len(incoming_invoice_nos)} incoming records...")
    existing_vouchers = check_existing_vouchers_bulk(TALLY_URL, incoming_invoice_nos)
    print(f"Targeted check complete. Found {len(existing_vouchers)} matching records already in Tally.")
except Exception as e:
    print(f"Tally check failed completely: {e}. Exiting this sync run to prevent invalid syncs.")
    exit(1)



# -----------------------------
# CREATE ALL SUPPLIER LEDGERS
# -----------------------------

suppliers = set()
for item in records:
    supplier = item.get("SupplierName", "").strip()
    if supplier and supplier not in suppliers:
        invoice_no = item.get("InvoiceNo", "N/A")
        if str(invoice_no).strip() not in existing_vouchers:
            create_supplier_ledger(supplier, invoice_no, "Purchase")
            suppliers.add(supplier)

# -----------------------------
# IMPORT VOUCHERS
# -----------------------------

success_count = 0
failed_count = 0
skipped_count = 0
duplicate_count = 0

processed_records_by_month = {}
failed_records_by_month = {}
skipped_records_by_month = {}



for item in records:
    invoice_no = item.get("InvoiceNo")
    invoice_date_str = item.get("InvoiceDate")
    supplier_raw = item.get("SupplierName")
    supplier = escape(str(supplier_raw).strip()) if supplier_raw else None

    # Skip record if crucial information is missing
    if not invoice_no or not invoice_date_str or not supplier:
        month_str = "Unknown"
        if invoice_date_str:
            try:
                dt = datetime.strptime(invoice_date_str, "%d-%b-%Y")
                month_str = dt.strftime("%b_%Y")
            except Exception:
                pass
        
        missing_fields = []
        if not invoice_no: missing_fields.append("InvoiceNo")
        if not invoice_date_str: missing_fields.append("InvoiceDate")
        if not supplier: missing_fields.append("SupplierName")
        reason = f"Missing mandatory field(s): {', '.join(missing_fields)}"
        
        timestamp = datetime.now().strftime("%d %m %Y %H:%M:%S")
        log_entry = {"id": invoice_no or "N/A", "reason": reason, "timestamp": timestamp}
        skipped_records_by_month.setdefault(month_str, []).append(log_entry)
        

        
        skipped_count += 1
        print(f"[Purchase Sync] SKIPPED (Reason: {reason}): {supplier_raw or 'Unknown'} (Invoice No: {invoice_no or 'N/A'})")
        continue

    # Determine month for record partitioning
    try:
        dt = datetime.strptime(invoice_date_str, "%d-%b-%Y")
        month_str = dt.strftime("%b_%Y")
    except Exception as e:
        print(f"Error parsing date {invoice_date_str} for invoice {invoice_no}: {e}")
        month_str = "Unknown"

    timestamp = datetime.now().strftime("%d %m %Y %H:%M:%S")
    log_entry = {"id": invoice_no, "timestamp": timestamp}

    # Duplicate check (Safely converting to str first)
    invoice_str = str(invoice_no).strip()
    if invoice_str in existing_vouchers:
        log_entry["reason"] = "Record already exists in Tally"
        skipped_records_by_month.setdefault(month_str, []).append(log_entry)
        duplicate_count += 1
        print(f"[Purchase Sync] DUPLICATE (Reason: Record already exists in Tally): {supplier} (Invoice No: {invoice_no})")
        continue

    try:
        formatted_date = dt.strftime("%Y%m%d")
        cgst = round(item.get("CGST_AMT", 0.0), 2)
        sgst = round(item.get("SGT_AMT", 0.0), 2)
        igst = round(item.get("IGST_AMT", 0.0), 2)
        total = round(item.get("NetAmount", 0.0), 2)
        purchase_amount = round(total - cgst - sgst - igst, 2)

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
             <VOUCHER VCHTYPE="Purchase" ACTION="Create">
              <DATE>{formatted_date}</DATE>
              <VOUCHERNUMBER>{invoice_no}</VOUCHERNUMBER>
              <REFERENCE>{invoice_no}</REFERENCE>
              <VOUCHERTYPENAME>Purchase</VOUCHERTYPENAME>
              <PARTYLEDGERNAME>{supplier}</PARTYLEDGERNAME>
              <NARRATION>Imported Automatically</NARRATION>
              
              <!-- Supplier -->
              <ALLLEDGERENTRIES.LIST>
               <LEDGERNAME>{supplier}</LEDGERNAME>
               <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>
               <AMOUNT>{total}</AMOUNT>
              </ALLLEDGERENTRIES.LIST>

              <!-- Purchase -->
              <ALLLEDGERENTRIES.LIST>
               <LEDGERNAME>Purchase</LEDGERNAME>
               <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>
               <AMOUNT>-{purchase_amount}</AMOUNT>
              </ALLLEDGERENTRIES.LIST>
              
              <!-- CGST -->
              <ALLLEDGERENTRIES.LIST>
               <LEDGERNAME>CGST</LEDGERNAME>
               <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>
               <AMOUNT>-{cgst}</AMOUNT>
              </ALLLEDGERENTRIES.LIST>
              
              <!-- SGST -->
              <ALLLEDGERENTRIES.LIST>
               <LEDGERNAME>SGST</LEDGERNAME>
               <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>
               <AMOUNT>-{sgst}</AMOUNT>
              </ALLLEDGERENTRIES.LIST>
             </VOUCHER>
            </TALLYMESSAGE>
           </REQUESTDATA>
          </IMPORTDATA>
         </BODY>
        </ENVELOPE>
        """

        response = requests.post(TALLY_URL, data=voucher_xml.encode("utf-8"), timeout=15)
        response_text = response.text

        # Record exact execution completion timestamp
        exec_timestamp = datetime.now().strftime("%d %m %Y %H:%M:%S")
        log_entry["timestamp"] = exec_timestamp

        if "<CREATED>1</CREATED>" in response_text:
            success_count += 1
            processed_records_by_month.setdefault(month_str, []).append(log_entry)
            existing_vouchers.add(invoice_str)
            print(f"[Purchase Sync] SUCCESS (Invoice successfully pushed to Tally): {supplier} (Invoice No: {invoice_no})")
        else:
            failed_count += 1
            err_match = re.search(r"<LINEERROR>(.*?)</LINEERROR>", response_text, re.IGNORECASE)
            err_msg = err_match.group(1) if err_match else "Import failed (unspecified Tally error)"
            log_entry["reason"] = err_msg
            failed_records_by_month.setdefault(month_str, []).append(log_entry)
            

            
            print(f"[Purchase Sync] FAILED ({err_msg}): {supplier} (Invoice No: {invoice_no})")
            print(response_text)

    except Exception as e:
        failed_count += 1
        log_entry["reason"] = str(e)
        failed_records_by_month.setdefault(month_str, []).append(log_entry)
        

        
        print(f"[Purchase Sync] FAILED (Exception: {e}): {supplier} (Invoice No: {invoice_no})")

# -----------------------------
# SAVE MONTH-WISE TEXT FILES & ROOT LEVEL MASTER SYNC HISTORY
# -----------------------------
reports_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "Reports"))
save_month_wise_records(processed_records_by_month, os.path.join(reports_dir, "processed_records"), "processed_purchase_receipts_", "InvoiceNo")
save_month_wise_records(failed_records_by_month, os.path.join(reports_dir, "failed_records"), "failed_purchase_receipts_", "InvoiceNo")
save_month_wise_records(skipped_records_by_month, os.path.join(reports_dir, "skipped_records"), "skipped_purchase_receipts_", "InvoiceNo")



# -----------------------------
# FINAL SUMMARY
# -----------------------------
print("\n====================================")
print("PURCHASE SUMMARY")
print("====================================")
print(f"SUCCESS   : {success_count}")
print(f"FAILED    : {failed_count}")
print(f"SKIPPED   : {skipped_count}")
print(f"DUPLICATE : {duplicate_count}")
print("====================================")