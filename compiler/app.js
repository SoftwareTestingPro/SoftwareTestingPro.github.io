// Default templates for each language
const TEMPLATES = {
    javascript: `// DevCompiler - JavaScript Playground
// Write your JavaScript code here and click "Run Code"

console.log("Hello from JavaScript!");

const numbers = [1, 2, 3, 4, 5];
const doubled = numbers.map(n => n * 2);
console.log("Doubled array:", doubled);

// Example of warnings and errors
console.warn("This is a warning log!");
console.error("This is an error log!");
`,
    typescript: `// DevCompiler - TypeScript Playground
// Fully supported transpilation and typing in the browser!

interface User {
    id: number;
    name: string;
    role: 'admin' | 'user';
}

class SystemManager {
    private users: User[] = [];

    addUser(user: User): void {
        this.users.push(user);
        console.log(\`Added user: \${user.name} (\${user.role})\`);
    }

    listAdmins(): string[] {
        return this.users
            .filter(u => u.role === 'admin')
            .map(u => u.name);
    }
}

const manager = new SystemManager();
manager.addUser({ id: 1, name: "Alice", role: "admin" });
manager.addUser({ id: 2, name: "Bob", role: "user" });

console.log("Admins on the system:", manager.listAdmins());
`,
    python: `# DevCompiler - Python 3 (Pyodide WebAssembly)
# True Python environment running fully locally in your browser!

print("Hello from WebAssembly-powered Python!")

# List comprehension
squared_evens = [x**2 for x in range(10) if x % 2 == 0]
print(f"Squared even numbers: {squared_evens}")

# Class and inheritance example
class Animal:
    def __init__(self, name):
        self.name = name
    def speak(self):
        return f"{self.name} makes a sound."

class Dog(Animal):
    def speak(self):
        return f"{self.name} barks!"

buddy = Dog("Buddy")
print(buddy.speak())
`,
    html: `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>DevCompiler HTML Preview</title>
    <style>
        body {
            font-family: 'Outfit', sans-serif;
            background: linear-gradient(135deg, #0f172a, #1e293b);
            color: white;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            overflow: hidden;
        }
        .card {
            background: rgba(255, 255, 255, 0.07);
            backdrop-filter: blur(10px);
            padding: 30px;
            border-radius: 16px;
            border: 1px solid rgba(255, 255, 255, 0.1);
            text-align: center;
            box-shadow: 0 10px 30px rgba(0,0,0,0.5);
            max-width: 400px;
        }
        h1 {
            color: #6366f1;
            margin-top: 0;
        }
        button {
            background: #6366f1;
            border: none;
            color: white;
            padding: 10px 20px;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
            transition: all 0.2s;
        }
        button:hover {
            background: #4f46e5;
            transform: scale(1.05);
        }
    </style>
</head>
<body>
    <div class="card">
        <h1>Hello World!</h1>
        <p>This is a live preview. Edit the HTML/CSS/JS and run it again to see real-time updates.</p>
        <button onclick="showAlert()">Click Me</button>
    </div>

    <script>
        function showAlert() {
            alert("Hello from interactive Live Preview!");
        }
    </script>
</body>
</html>
`,
    java: `// DevCompiler - Java (OpenJDK Compiler via Wandbox)
// Write your standard Java class here (usually public class Main)

public class Main {
    public static void main(String[] args) {
        System.out.println("Hello from real Java compiler running in the cloud!");
        
        int a = 15;
        int b = 30;
        int sum = a + b;
        System.out.printf("Sum of %d and %d is: %d\n", a, b, sum);
    }
}
`
};

// Global State
let editorInstance = null;
let currentLanguage = 'javascript';
let pyodideInstance = null;
let isPyodideLoading = false;

// Saved code sessions during switching
const sessions = { ...TEMPLATES };

// DOM Elements
const languageSelect = document.getElementById('language-select');
const themeSelect = document.getElementById('theme-select');
const runBtn = document.getElementById('run-btn');
const clearBtn = document.getElementById('clear-btn');
const resetBtn = document.getElementById('reset-btn');
const editorStatus = document.getElementById('editor-status');
const consoleLogs = document.getElementById('console-logs');
const execTimeText = document.getElementById('exec-time');
const tabButtons = document.querySelectorAll('.tab-btn');
const tabContents = document.querySelectorAll('.tab-content');
const previewTabBtn = document.getElementById('preview-tab-btn');
const previewFrame = document.getElementById('preview-frame');
const paneResizer = document.getElementById('pane-resizer');
const editorPane = document.querySelector('.editor-pane');
const outputPane = document.querySelector('.output-pane');

// Setup Monaco Editor loader
require.config({ paths: { vs: 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.39.0/min/vs' } });

require(['vs/editor/editor.main'], function() {
    // Create the Monaco Editor
    editorInstance = monaco.editor.create(document.getElementById('monaco-editor-container'), {
        value: sessions[currentLanguage],
        language: currentLanguage,
        theme: 'vs-dark',
        fontSize: 14,
        fontFamily: "'Fira Code', monospace",
        automaticLayout: true,
        minimap: { enabled: true },
        scrollbar: {
            verticalScrollbarSize: 8,
            horizontalScrollbarSize: 8
        },
        padding: { top: 12 }
    });

    editorStatus.textContent = 'Ready';
});

// Switch Editor Language
function switchLanguage(newLang) {
    if (!editorInstance) return;

    // Save current session code
    sessions[currentLanguage] = editorInstance.getValue();

    currentLanguage = newLang;

    // Set value and language model
    editorInstance.setValue(sessions[currentLanguage]);
    
    // Map UI language strings to Monaco language strings
    let monacoLanguage = currentLanguage;
    if (currentLanguage === 'html') monacoLanguage = 'html';
    if (currentLanguage === 'java') monacoLanguage = 'java';

    monaco.editor.setModelLanguage(editorInstance.getModel(), monacoLanguage);

    // Auto toggle tab preview-tab if user chooses HTML
    if (newLang === 'html') {
        previewTabBtn.style.display = 'flex';
        switchTab('preview-tab');
    } else {
        switchTab('console-tab');
    }
}

// Switch Tabs UI/Logic
function switchTab(tabId) {
    tabButtons.forEach(btn => {
        if (btn.getAttribute('data-tab') === tabId) {
            btn.classList.add('active');
        } else {
            btn.classList.remove('active');
        }
    });

    tabContents.forEach(content => {
        if (content.id === tabId) {
            content.classList.add('active');
        } else {
            content.classList.remove('active');
        }
    });
}

// Append custom messages to console element
function appendLog(content, type = 'log') {
    const entry = document.createElement('div');
    entry.className = `log-entry ${type}`;
    
    const prefix = document.createElement('span');
    prefix.className = 'prefix';
    prefix.textContent = `[${type}]`;
    
    const textNode = document.createTextNode(typeof content === 'object' ? JSON.stringify(content) : content);
    
    entry.appendChild(prefix);
    entry.appendChild(textNode);
    consoleLogs.appendChild(entry);
    
    // Keep scroll to bottom
    consoleLogs.scrollTop = consoleLogs.scrollHeight;
}

// Clean/Clear standard logger screen
function clearLogs() {
    consoleLogs.innerHTML = '';
    appendLog('Console cleared. DevCompiler is ready.', 'system');
}

// Intercept window console logs inside sandbox environments
function buildConsoleInterceptor() {
    return `
        const _logs = [];
        const captureLog = (type) => (...args) => {
            _logs.push({ type, message: args.map(arg => typeof arg === 'object' ? JSON.stringify(arg) : String(arg)).join(' ') });
        };
        window.console = {
            log: captureLog('log'),
            error: captureLog('error'),
            warn: captureLog('warn'),
            info: captureLog('info')
        };
    `;
}

// Execute Code Action logic
async function runCode() {
    if (!editorInstance) return;
    
    const code = editorInstance.getValue();
    const startTime = performance.now();
    
    editorStatus.textContent = 'Running...';
    editorStatus.className = 'status-indicator loading';
    runBtn.disabled = true;

    try {
        if (currentLanguage === 'javascript') {
            executeJS(code);
        } else if (currentLanguage === 'typescript') {
            executeTS(code);
        } else if (currentLanguage === 'python') {
            await executePython(code);
        } else if (currentLanguage === 'html') {
            executeHTML(code);
        } else if (currentLanguage === 'java') {
            executeJava(code);
        }
    } catch (err) {
        appendLog(err.message || err, 'error');
    } finally {
        const endTime = performance.now();
        const duration = (endTime - startTime).toFixed(1);
        execTimeText.textContent = `Done in ${duration}ms`;
        
        editorStatus.textContent = 'Ready';
        editorStatus.className = 'status-indicator';
        runBtn.disabled = false;
    }
}

// Javascript sandbox execution engine
function executeJS(code) {
    switchTab('console-tab');
    clearLogs();
    
    appendLog('Executing JavaScript...', 'system');
    
    try {
        // Intercept standard output by overriding function arguments
        const customLogs = [];
        const customConsole = {
            log: (...args) => customLogs.push({ type: 'log', text: args.join(' ') }),
            error: (...args) => customLogs.push({ type: 'error', text: args.join(' ') }),
            warn: (...args) => customLogs.push({ type: 'warn', text: args.join(' ') }),
            info: (...args) => customLogs.push({ type: 'info', text: args.join(' ') })
        };
        
        const sandboxFunction = new Function('console', code);
        sandboxFunction(customConsole);
        
        if (customLogs.length === 0) {
            appendLog('Execution completed. No output logged.', 'system');
        } else {
            customLogs.forEach(entry => appendLog(entry.text, entry.type));
        }
    } catch (err) {
        appendLog(err, 'error');
    }
}

// Typescript compiler execution engine
function executeTS(code) {
    switchTab('console-tab');
    clearLogs();
    
    appendLog('Compiling TypeScript in browser...', 'system');
    
    try {
        if (!window.ts) {
            throw new Error("TypeScript transpiler CDN failed to load.");
        }
        
        const compiledJS = window.ts.transpileModule(code, {
            compilerOptions: { 
                target: window.ts.ScriptTarget.ES2015,
                module: window.ts.ModuleKind.None 
            }
        }).outputText;
        
        appendLog('Compilation successful! Executing...', 'system');
        executeJS(compiledJS);
    } catch (err) {
        appendLog(err, 'error');
    }
}

// WebAssembly Python runner engine
async function executePython(code) {
    switchTab('console-tab');
    
    if (!pyodideInstance) {
        if (isPyodideLoading) {
            appendLog('Python runner is loading. Please wait...', 'warn');
            return;
        }
        
        isPyodideLoading = true;
        appendLog('Downloading Pyodide WebAssembly runtime (approx. 7MB). Please stand by...', 'system');
        
        try {
            pyodideInstance = await loadPyodide({
                indexURL: "https://cdn.jsdelivr.net/pyodide/v0.26.1/full/"
            });
            appendLog('Python Pyodide runtime loaded successfully!', 'system');
        } catch (err) {
            isPyodideLoading = false;
            appendLog('Failed to load Pyodide runtime: ' + err.message, 'error');
            return;
        } finally {
            isPyodideLoading = false;
        }
    }
    
    clearLogs();
    appendLog('Executing Python code via Pyodide...', 'system');
    
    try {
        // Intercept Python print output to stdout
        pyodideInstance.setStdout({
            write: (text) => {
                if (text.trim()) {
                    appendLog(text.trim(), 'log');
                }
                return text.length;
            }
        });
        
        pyodideInstance.setStderr({
            write: (text) => {
                if (text.trim()) {
                    appendLog(text.trim(), 'error');
                }
                return text.length;
            }
        });
        
        await pyodideInstance.runPythonAsync(code);
    } catch (err) {
        appendLog(err.message, 'error');
    }
}

// HTML Sandbox Iframe loader
function executeHTML(code) {
    switchTab('preview-tab');
    appendLog('Updating preview frame...', 'system');
    
    try {
        previewFrame.srcdoc = code;
    } catch (err) {
        appendLog('Error updating iframe: ' + err.message, 'error');
    }
}

// Real Java Compilation and Execution via Wandbox API
async function executeJava(code) {
    switchTab('console-tab');
    clearLogs();
    
    appendLog('Sending code to OpenJDK cloud compiler...', 'system');
    
    try {
        const payload = {
            compiler: "openjdk-head",
            code: code,
            codes: [
                {
                    file: "Main.java",
                    code: code
                }
            ]
        };
        
        const response = await fetch('https://wandbox.org/api/compile.json', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });
        
        if (!response.ok) {
            throw new Error(`Compiler API returned HTTP status ${response.status}`);
        }
        
        const result = await response.json();
        
        // Output compilation messages (warnings or syntax errors)
        if (result.compiler_message) {
            const hasErrors = result.status !== "0";
            appendLog(result.compiler_message, hasErrors ? 'error' : 'info');
        }
        
        // Output runtime standard outputs
        if (result.program_output) {
            // Split output by newlines and print
            const lines = result.program_output.split('\n');
            lines.forEach(line => {
                if (line) appendLog(line, 'log');
            });
        }
        
        if (result.program_error) {
            appendLog(result.program_error, 'error');
        }
        
        if (result.status === "0") {
            appendLog('Java execution completed successfully!', 'system');
        } else {
            appendLog(`Execution completed with exit code: ${result.status}`, 'error');
        }
    } catch (err) {
        appendLog('Java Compiler Error: ' + err.message, 'error');
    }
}

// Event Listeners
languageSelect.addEventListener('change', (e) => {
    switchLanguage(e.target.value);
});

themeSelect.addEventListener('change', (e) => {
    const selectedTheme = e.target.value;
    if (editorInstance) {
        editorInstance.updateOptions({ theme: selectedTheme });
    }
    
    // Update main background CSS themes
    if (selectedTheme === 'vs-light') {
        document.body.classList.add('vs-light-theme');
    } else {
        document.body.classList.remove('vs-light-theme');
    }
});

runBtn.addEventListener('click', runCode);
clearBtn.addEventListener('click', clearLogs);

resetBtn.addEventListener('click', () => {
    if (confirm('Are you sure you want to reset this code template? Your changes will be lost.')) {
        sessions[currentLanguage] = TEMPLATES[currentLanguage];
        if (editorInstance) {
            editorInstance.setValue(sessions[currentLanguage]);
        }
        clearLogs();
    }
});

// Output Pane Tabs switching
tabButtons.forEach(btn => {
    btn.addEventListener('click', () => {
        const tabId = btn.getAttribute('data-tab');
        switchTab(tabId);
    });
});

// Pane Resizer Logic (Drag to resize Left & Right panes)
let isResizing = false;

paneResizer.addEventListener('mousedown', (e) => {
    isResizing = true;
    document.body.style.cursor = 'col-resize';
    document.body.style.userSelect = 'none';
});

document.addEventListener('mousemove', (e) => {
    if (!isResizing) return;
    
    const containerWidth = document.querySelector('.ide-layout').clientWidth;
    const leftWidth = e.clientX;
    const rightWidth = containerWidth - leftWidth;
    
    if (leftWidth > 200 && rightWidth > 200) {
        editorPane.style.flex = 'none';
        editorPane.style.width = `${leftWidth}px`;
        outputPane.style.flex = 'none';
        outputPane.style.width = `${rightWidth}px`;
    }
});

document.addEventListener('mouseup', () => {
    if (isResizing) {
        isResizing = false;
        document.body.style.cursor = 'default';
        document.body.style.userSelect = 'auto';
        if (editorInstance) {
            editorInstance.layout();
        }
    }
});
