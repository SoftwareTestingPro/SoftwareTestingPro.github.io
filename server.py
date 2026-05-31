import http.server
import json
import os
import urllib.parse

class LibraryAPIRequestHandler(http.server.SimpleHTTPRequestHandler):
    BOOKS_PATH = os.path.join(os.path.dirname(__file__), 'library-api', 'api', 'v1', 'books.json')

    def load_books(self):
        try:
            with open(self.BOOKS_PATH, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception:
            return []

    def save_books(self, books):
        try:
            with open(self.BOOKS_PATH, 'w', encoding='utf-8') as f:
                json.dump(books, f, indent=2)
            return True
        except Exception:
            return False

    def handle_auth(self):
        auth_header = self.headers.get('Authorization')
        if not auth_header:
            return False
        
        # Validate credentials:
        # Basic Auth: library_admin:admin_secure_123 -> Basic bGlicmFyeV9hZG1pbjphZG1pbl9zZWN1cmVfMTIz
        # OAuth 2.0: lib_bearer_token_98765 -> Bearer lib_bearer_token_98765
        if auth_header == "Basic bGlicmFyeV9hZG1pbjphZG1pbl9zZWN1cmVfMTIz":
            return True
        if auth_header == "Bearer lib_bearer_token_98765":
            return True
        return False

    def send_json(self, status, data):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        # Add CORS headers
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-Custom-Client')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode('utf-8'))

    def do_OPTIONS(self):
        # Handle CORS preflight
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-Custom-Client')
        self.end_headers()

    def do_GET(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path
        
        # Route library API queries dynamically
        if path == '/library-api/api/v1/books.json':
            if not self.handle_auth():
                return self.send_json(401, {"error": "Unauthorized", "message": "Authentication failed."})
            
            books = self.load_books()
            
            # Support query filters
            query_params = urllib.parse.parse_qs(parsed_url.query)
            filtered_books = books
            
            subject = query_params.get('subject', [None])[0]
            author = query_params.get('author', [None])[0]
            min_pages = query_params.get('minPages', [None])[0]
            max_pages = query_params.get('maxPages', [None])[0]
            min_price = query_params.get('minPrice', [None])[0]
            max_price = query_params.get('maxPrice', [None])[0]
            min_year = query_params.get('minYear', [None])[0]
            max_year = query_params.get('maxYear', [None])[0]
            
            if subject:
                filtered_books = [b for b in filtered_books if b.get('subject') == subject]
            if author:
                filtered_books = [b for b in filtered_books if b.get('author') == author]
            if min_pages:
                filtered_books = [b for b in filtered_books if b.get('pages', 0) >= int(min_pages)]
            if max_pages:
                filtered_books = [b for b in filtered_books if b.get('pages', 0) <= int(max_pages)]
            if min_price:
                filtered_books = [b for b in filtered_books if b.get('price', 0.0) >= float(min_price)]
            if max_price:
                filtered_books = [b for b in filtered_books if b.get('price', 0.0) <= float(max_price)]
            if min_year:
                filtered_books = [b for b in filtered_books if b.get('published_year', 0) >= int(min_year)]
            if max_year:
                filtered_books = [b for b in filtered_books if b.get('published_year', 0) <= int(max_year)]
                
            return self.send_json(200, filtered_books)
            
        return super().do_GET()

    def do_POST(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path
        
        if path == '/library-api/api/v1/books.json':
            if not self.handle_auth():
                return self.send_json(401, {"error": "Unauthorized", "message": "Authentication failed."})
            
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            try:
                new_book = json.loads(post_data.decode('utf-8'))
            except Exception:
                return self.send_json(400, {"error": "Bad Request", "message": "Invalid JSON request body."})
                
            if not new_book.get('title') or not new_book.get('author') or not new_book.get('subject'):
                return self.send_json(400, {"error": "Bad Request", "message": "Missing book parameters."})
                
            books = self.load_books()
            new_id = max([b.get('id', 0) for b in books]) + 1 if books else 1
            new_book['id'] = new_id
            
            books.insert(0, new_book)
            self.save_books(books)
            
            return self.send_json(201, new_book)
            
        elif path == '/compiler/api/v1/compile-java':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            try:
                payload = json.loads(post_data.decode('utf-8'))
                code = payload.get('code', '')
            except Exception:
                return self.send_json(400, {"error": "Bad Request", "message": "Invalid JSON payload."})
            
            if not code:
                return self.send_json(400, {"error": "Bad Request", "message": "Code is required."})
            
            import re
            import subprocess
            class_name = "Main"
            match = re.search(r'public\s+class\s+([a-zA-Z0-9_$]+)', code)
            if not match:
                match = re.search(r'class\s+([a-zA-Z0-9_$]+)', code)
            if match:
                class_name = match.group(1)
                
            # Automatically inject common RestAssured/Hamcrest/Selenium imports if they are referenced but not imported
            injected_imports = []
            if "RestAssured" in code and "import io.restassured.RestAssured" not in code:
                injected_imports.append("import io.restassured.RestAssured;")
            if "Response" in code and "import io.restassured.response.Response" not in code:
                injected_imports.append("import io.restassured.response.Response;")
            if "RequestSpecification" in code and "import io.restassured.specification.RequestSpecification" not in code:
                injected_imports.append("import io.restassured.specification.RequestSpecification;")
            if any(term in code for term in ["equalTo", "hasItems", "Matchers"]) and "import static org.hamcrest.Matchers" not in code:
                injected_imports.append("import static org.hamcrest.Matchers.*;")
                
            # Selenium Auto-Imports
            if "WebDriver" in code and "import org.openqa.selenium.WebDriver" not in code:
                injected_imports.append("import org.openqa.selenium.WebDriver;")
            if "ChromeDriver" in code and "import org.openqa.selenium.chrome.ChromeDriver" not in code:
                injected_imports.append("import org.openqa.selenium.chrome.ChromeDriver;")
            if "ChromeOptions" in code and "import org.openqa.selenium.chrome.ChromeOptions" not in code:
                injected_imports.append("import org.openqa.selenium.chrome.ChromeOptions;")
            if "By" in code and "import org.openqa.selenium.By" not in code:
                injected_imports.append("import org.openqa.selenium.By;")
            if "WebElement" in code and "import org.openqa.selenium.WebElement" not in code:
                injected_imports.append("import org.openqa.selenium.WebElement;")
                
            if injected_imports:
                package_match = re.search(r'^\s*package\s+[\w.]+;', code, re.MULTILINE)
                if package_match:
                    pos = package_match.end()
                    code = code[:pos] + "\n" + "\n".join(injected_imports) + "\n" + code[pos:]
                else:
                    code = "\n".join(injected_imports) + "\n" + code

            compiler_dir = os.path.join(os.path.dirname(__file__), 'compiler')
            temp_dir = os.path.join(compiler_dir, 'temp')
            lib_dir = os.path.join(compiler_dir, 'lib')
            
            os.makedirs(temp_dir, exist_ok=True)
            os.makedirs(lib_dir, exist_ok=True)
            
            java_file = os.path.join(temp_dir, f"{class_name}.java")
            with open(java_file, 'w', encoding='utf-8') as f:
                f.write(code)
                
            classpath = f'"{lib_dir}/*";"{temp_dir}"'
            compile_cmd = f'javac -cp {classpath} -d "{temp_dir}" "{java_file}"'
            
            compile_proc = subprocess.run(compile_cmd, shell=True, capture_output=True, text=True)
            if compile_proc.returncode != 0:
                try: os.remove(java_file)
                except: pass
                return self.send_json(200, {
                    "status": "1",
                    "compiler_message": compile_proc.stderr,
                    "program_output": "",
                    "program_error": compile_proc.stderr
                })
                
            run_cmd = f'java -cp {classpath} {class_name}'
            run_proc = subprocess.run(run_cmd, shell=True, capture_output=True, text=True)
            
            try:
                os.remove(java_file)
                class_file = os.path.join(temp_dir, f"{class_name}.class")
                if os.path.exists(class_file):
                    os.remove(class_file)
            except:
                pass
                
            return self.send_json(200, {
                "status": str(run_proc.returncode),
                "compiler_message": "Compilation successful!\n" + compile_proc.stderr,
                "program_output": run_proc.stdout,
                "program_error": run_proc.stderr
            })
            
        elif path == '/compiler/api/v1/run-local':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            try:
                payload = json.loads(post_data.decode('utf-8'))
                language = payload.get('language', '')
                code = payload.get('code', '')
            except Exception:
                return self.send_json(400, {"error": "Bad Request", "message": "Invalid JSON payload."})
            
            if not code or not language:
                return self.send_json(400, {"error": "Bad Request", "message": "Language and Code are required."})
                
            compiler_dir = os.path.join(os.path.dirname(__file__), 'compiler')
            temp_dir = os.path.join(compiler_dir, 'temp')
            os.makedirs(temp_dir, exist_ok=True)
            
            import subprocess
            import uuid
            
            unique_id = str(uuid.uuid4())[:8]
            
            if language == 'javascript':
                file_ext = 'js'
                cmd = 'node'
                
                # Auto-inject Playwright require if referenced but not imported
                injected_js = []
                if any(term in code for term in ["chromium", "firefox", "webkit"]) and "require('playwright')" not in code and 'from "playwright"' not in code and 'from \'playwright\'' not in code:
                    injected_js.append("const { chromium, firefox, webkit } = require('playwright');")
                
                if injected_js:
                    code = "\n".join(injected_js) + "\n" + code
                    
                # Auto-invoke main() if defined but not called
                if ("function main(" in code or "async function main(" in code) and "main()" not in code:
                    code = code + "\n\nmain();\n"
            elif language == 'python':
                file_ext = 'py'
                cmd = 'python'
            else:
                return self.send_json(400, {"error": "Bad Request", "message": "Unsupported language for local runner."})
                
            temp_file = os.path.join(temp_dir, f"temp_{unique_id}.{file_ext}")
            
            with open(temp_file, 'w', encoding='utf-8') as f:
                f.write(code)
                
            run_cmd = f'{cmd} "{temp_file}"'
            run_proc = subprocess.run(run_cmd, shell=True, capture_output=True, text=True)
            
            try:
                os.remove(temp_file)
            except:
                pass
                
            program_error = run_proc.stderr
            if "is not recognized as an internal or external command" in program_error or "not found" in program_error.lower():
                if cmd == 'node':
                    program_error += "\n[DevCompiler Hint] Node.js was not found on your system. To execute JavaScript/TypeScript Playwright tests, please install Node.js (https://nodejs.org/) and add it to your system PATH."
                elif cmd == 'python':
                    program_error += "\n[DevCompiler Hint] Python was not found on your system. Please install Python (https://python.org/) and add it to your system PATH."
            
            return self.send_json(200, {
                "status": str(run_proc.returncode),
                "program_output": run_proc.stdout,
                "program_error": program_error
            })

        self.send_response(405)
        self.end_headers()

    def do_PUT(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path
        
        if path == '/library-api/api/v1/books.json':
            if not self.handle_auth():
                return self.send_json(401, {"error": "Unauthorized", "message": "Authentication failed."})
                
            query_params = urllib.parse.parse_qs(parsed_url.query)
            book_id = query_params.get('id', [None])[0]
            
            if not book_id:
                return self.send_json(400, {"error": "Bad Request", "message": "Book ID query parameter is required."})
                
            try:
                book_id = int(book_id)
            except ValueError:
                return self.send_json(400, {"error": "Bad Request", "message": "Book ID must be numeric."})
                
            content_length = int(self.headers.get('Content-Length', 0))
            put_data = self.rfile.read(content_length)
            
            try:
                updated_fields = json.loads(put_data.decode('utf-8'))
            except Exception:
                return self.send_json(400, {"error": "Bad Request", "message": "Invalid JSON request body."})
                
            books = self.load_books()
            book_index = next((i for i, b in enumerate(books) if b.get('id') == book_id), -1)
            
            if book_index == -1:
                return self.send_json(404, {"error": "Not Found", "message": f"Book with ID {book_id} not found."})
                
            original_book = books[book_index]
            updated_book = {
                "id": book_id,
                "title": updated_fields.get('title') or original_book.get('title'),
                "author": updated_fields.get('author') or original_book.get('author'),
                "subject": updated_fields.get('subject') or original_book.get('subject'),
                "pages": int(updated_fields.get('pages')) if updated_fields.get('pages') is not None else original_book.get('pages'),
                "price": float(updated_fields.get('price')) if updated_fields.get('price') is not None else original_book.get('price'),
                "published_year": int(updated_fields.get('published_year')) if updated_fields.get('published_year') is not None else original_book.get('published_year')
            }
            
            books[book_index] = updated_book
            self.save_books(books)
            
            return self.send_json(200, updated_book)
            
        self.send_response(405)
        self.end_headers()

    def do_DELETE(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path
        
        if path == '/library-api/api/v1/books.json':
            if not self.handle_auth():
                return self.send_json(401, {"error": "Unauthorized", "message": "Authentication failed."})
                
            query_params = urllib.parse.parse_qs(parsed_url.query)
            book_id = query_params.get('id', [None])[0]
            
            if not book_id:
                return self.send_json(400, {"error": "Bad Request", "message": "Book ID query parameter is required."})
                
            try:
                book_id = int(book_id)
            except ValueError:
                return self.send_json(400, {"error": "Bad Request", "message": "Book ID must be numeric."})
                
            books = self.load_books()
            book_index = next((i for i, b in enumerate(books) if b.get('id') == book_id), -1)
            
            if book_index == -1:
                return self.send_json(404, {"error": "Not Found", "message": f"Book with ID {book_id} not found."})
                
            deleted_book = books.pop(book_index)
            self.save_books(books)
            
            return self.send_json(200, {"message": f"Book ID {book_id} deleted successfully.", "deleted_book": deleted_book})
            
        self.send_response(405)
        self.end_headers()

if __name__ == '__main__':
    port = 8000
    server_address = ('', port)
    httpd = http.server.HTTPServer(server_address, LibraryAPIRequestHandler)
    print(f"Library API Playground server running on port {port} with fully functional CRUD endpoints!")
    httpd.serve_forever()
