import time
import subprocess
import sys
import os
import socket

# Force Python to run completely unbuffered so console outputs show instantly
os.environ["PYTHONUNBUFFERED"] = "1"

# Define working directory and log paths
working_dir = os.path.dirname(os.path.abspath(__file__))
logs_dir = os.path.abspath(os.path.join(working_dir, "..", "Logs"))
os.makedirs(logs_dir, exist_ok=True)

stdout_log_path = os.path.join(logs_dir, "tally_sync_stdout.log")
stderr_log_path = os.path.join(logs_dir, "tally_sync_stderr.log")

# Truncate active process logs to 0 bytes at startup to clear previous executions
for log_path in [stdout_log_path, stderr_log_path]:
    if os.path.exists(log_path):
        try:
            with open(log_path, "w", encoding="utf-8") as f:
                f.truncate(0)
        except Exception:
            pass

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

# =========================================================
# CONFIGURATION
# =========================================================
TALLY_HOST = "localhost"
TALLY_PORT = 9000

# -----------------------------
# FUNCTION: CHECK IF PORT IS ACTIVE
# -----------------------------

def is_port_active(host, port):
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(2)
            s.connect((host, port))
            return True
    except Exception:
        return False


# -----------------------------
# FUNCTION: CHECK TALLY PORT
# -----------------------------

def check_tally_port(host, port):
    if is_port_active(host, port):
        print(f"Tally API port {port} is active and listening.")
        return True
        
    sys.stderr.write(f"Tally API port {port} is inactive. Please ensure Tally is running and the company is opened.\n")
    return False


# -----------------------------
# MAIN SERVICE LOOP
# -----------------------------

def clear_previous_sync_data():
    import shutil
    base_dir = os.path.abspath(os.path.join(working_dir, ".."))
    
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


if __name__ == "__main__":
    startup_time = time.strftime('%Y-%m-%d %H:%M:%S')
    print(f"[{startup_time}] Tally Sync Started successfully.")
    print(f"[{startup_time}] Working Directory: {working_dir}")

    # Verify Tally is active before proceeding
    if check_tally_port(TALLY_HOST, TALLY_PORT):
        # Clear previous sync data at the beginning of a fresh successful sync cycle
        clear_previous_sync_data()

        # 1. Run Purchase Sync
        try:
            print("Executing purchase_sync.py...")
            env = os.environ.copy()
            env["TALLY_SYNC_SCHEDULER"] = "1"
            subprocess.run(
                [sys.executable, "purchase_sync.py"], 
                cwd=working_dir, 
                env=env,
                check=True
            )
        except subprocess.CalledProcessError as e:
            sys.stderr.write(f"Error running purchase_sync.py (Exit code {e.returncode})\n")
        except Exception as e:
            sys.stderr.write(f"Unexpected error running purchase_sync.py: {e}\n")
            
        # 2. Run Sales Sync
        try:
            print("Executing sales_sync.py...")
            env = os.environ.copy()
            env["TALLY_SYNC_SCHEDULER"] = "1"
            subprocess.run(
                [sys.executable, "sales_sync.py"], 
                cwd=working_dir, 
                env=env,
                check=True
            )
        except subprocess.CalledProcessError as e:
            sys.stderr.write(f"Error running sales_sync.py (Exit code {e.returncode})\n")
        except Exception as e:
            sys.stderr.write(f"Unexpected error running sales_sync.py: {e}\n")
            
        cycle_end_time = time.strftime('%Y-%m-%d %H:%M:%S')
        print(f"[{cycle_end_time}] Sync Complete.")
    else:
        sys.stderr.write("Skipping sync cycle. PLEASE LAUNCH TALLY PRIME TO INITIATE SYNCHRONIZATION.\n")
        sys.exit(1)
