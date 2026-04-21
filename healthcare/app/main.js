let db;
const editor = document.getElementById('sql-editor');
const resultContainer = document.getElementById('result-container');
const dbStatus = document.getElementById('db-status');
let lobChart, trendChart;

// 1. App Initialization
async function init() {
    try {
        const SQL = await initSqlJs({
            locateFile: file => `https://cdnjs.cloudflare.com/ajax/libs/sql.js/1.8.0/${file}`
        });
        db = new SQL.Database();
        dbStatus.innerText = "Provisioning Schema...";
        
        await bootstrapDB();
        dbStatus.innerText = "System Live";
    } catch (err) {
        dbStatus.innerText = "Offline";
        console.error("Initialization error:", err);
    }
}

async function bootstrapDB() {
    const ddl = `
        CREATE TABLE dim_employers (employer_id INT, employer_name TEXT, industry TEXT, hq_country TEXT, onboarding_date DATE);
        CREATE TABLE dim_products (product_id INT, product_name TEXT, line_of_business TEXT, risk_profile TEXT);
        CREATE TABLE dim_employees (employee_id INT, employer_id INT, full_name TEXT, birth_date DATE, enrollment_status TEXT, monthly_salary DECIMAL);
        CREATE TABLE dim_providers (provider_id INT, provider_name TEXT, specialty TEXT, network_status TEXT);
        CREATE TABLE fact_enrollments (enrollment_id INT, employee_id INT, product_id INT, enrollment_date DATE, status TEXT);
        CREATE TABLE fact_claims (claim_id INT, employee_id INT, product_id INT, provider_id INT, service_date DATE, claim_amount DECIMAL, paid_amount DECIMAL, claim_status TEXT);
        CREATE TABLE fact_claim_history (history_id INT, claim_id INT, old_status TEXT, new_status TEXT, updated_at TIMESTAMP);
    `;
    db.run(ddl);

    try {
        dbStatus.innerText = "Loading Enterprise Data...";
        
        // Use the SEED_DATA variable defined in ../sql/data.js
        if (typeof SEED_DATA !== 'undefined' && SEED_DATA.length > 100) {
            db.run(SEED_DATA);
            console.log("SQL Bootstrap: Data loaded successfully. Chars:", SEED_DATA.length);
            dbStatus.innerText = "1,500+ Records Live";
        } else {
            console.error("SEED_DATA is empty or missing.");
            dbStatus.innerText = "Data Load Failed - Please Refresh";
        }
    } catch (e) {
        console.error("Data Load Error:", e);
        dbStatus.innerText = "Data Load Failed";
    }
    
    // Final Trigger
    updateDashboard();
    initCharts();
}

// 2. Tab Management
function switchTab(tabId) {
    document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
    
    document.getElementById(`tab-${tabId}`).classList.add('active');
    event.currentTarget.classList.add('active');
    
    if(tabId === 'dashboard') updateDashboard();
}

// 3. SQL Engine
function runQuery() {
    const query = editor.value.trim();
    const isDML = /^(UPDATE|INSERT|DELETE|CREATE|DROP|ALTER)/i.test(query);

    try {
        if (isDML) {
            db.run(query);
            resultContainer.innerHTML = `<div class="empty-state" style="color: var(--success)">Query executed successfully. Changes applied to the database.</div>`;
            updateDashboard(); // Live update of Dashboard KPIs
            return;
        }

        const res = db.exec(query);
        if (res.length === 0) {
            resultContainer.innerHTML = '<div class="empty-state">No records found.</div>';
            return;
        }
        renderTable(res[0], 'result-container');
    } catch (err) {
        resultContainer.innerHTML = `<div class="empty-state" style="color: var(--danger)">${err.message}</div>`;
    }
}

function renderTable(data, containerId) {
    const { columns, values } = data;
    let html = '<table><thead><tr>';
    columns.forEach(c => html += `<th>${c}</th>`);
    html += '</tr></thead><tbody>';
    
    // Performance: Limit display to 500 rows for UI stability, show all in export
    const displayValues = values.slice(0, 500);
    displayValues.forEach(row => {
        html += '<tr>';
        row.forEach(cell => html += `<td>${cell === null ? '-' : cell}</td>`);
        html += '</tr>';
    });
    
    html += '</tbody></table>';
    if(values.length > 500) html += `<div style="padding: 15px; text-align: center; color: var(--text-secondary)">Showing 500 of ${values.length} records. Export for full data.</div>`;
    
    document.getElementById(containerId).innerHTML = html;
}

// 4. Dashboard Engine
function updateDashboard() {
    try {
        // Total Claims Value
        const totalVal = db.exec("SELECT SUM(claim_amount) FROM fact_claims")[0].values[0][0];
        document.getElementById('kpi-total-claims').innerText = `$${Math.round(totalVal/1000).toLocaleString()}K`;

        // Denial Rate
        const denials = db.exec("SELECT COUNT(*) FROM fact_claims WHERE claim_status = 'DENIED'")[0].values[0][0];
        const totalCount = db.exec("SELECT COUNT(*) FROM fact_claims")[0].values[0][0];
        document.getElementById('kpi-denial-rate').innerText = `${((denials/totalCount)*100).toFixed(1)}%`;

        // Active Members
        const members = db.exec("SELECT COUNT(*) FROM dim_employees WHERE enrollment_status = 'ACTIVE'")[0].values[0][0];
        document.getElementById('kpi-active-employees').innerText = members.toLocaleString();

        // New KPIs
        const avgPaid = db.exec("SELECT AVG(paid_amount) FROM fact_claims WHERE paid_amount > 0")[0].values[0][0];
        document.getElementById('kpi-avg-payout').innerText = `$${Math.round(avgPaid).toLocaleString()}`;

        const networkStats = db.exec("SELECT COUNT(*) FROM dim_providers WHERE network_status = 'IN-NETWORK'")[0].values[0][0];
        const totalProviders = db.exec("SELECT COUNT(*) FROM dim_providers")[0].values[0][0];
        document.getElementById('kpi-network-index').innerText = `${((networkStats/totalProviders)*100).toFixed(0)}%`;

        const products = db.exec("SELECT COUNT(*) FROM dim_products")[0].values[0][0];
        document.getElementById('kpi-product-count').innerText = products;

    } catch (e) {
        console.warn("Dashboard update failed", e);
    }
}

function initCharts() {
    // 1. Pie Chart: Claims by LOB
    const lobData = db.exec(`
        SELECT p.line_of_business, SUM(c.claim_amount) 
        FROM fact_claims c JOIN dim_products p ON c.product_id = p.product_id 
        GROUP BY 1
    `)[0];
    
    const ctxLob = document.getElementById('lobChart');
    if(lobChart) lobChart.destroy();
    lobChart = new Chart(ctxLob, {
        type: 'doughnut',
        data: {
            labels: lobData.values.map(v => v[0]),
            datasets: [{
                data: lobData.values.map(v => v[1]),
                backgroundColor: ['#3b82f6', '#8b5cf6', '#10b981', '#f59e0b', '#ef4444'],
                borderWidth: 0
            }]
        },
        options: { plugins: { legend: { position: 'bottom', labels: { color: '#9ca3af' } } }, cutout: '70%'}
    });

    // 2. Line Chart: Trend
    const trendData = db.exec(`
        SELECT SUBSTR(service_date, 1, 7) as mo, SUM(claim_amount) 
        FROM fact_claims GROUP BY 1 ORDER BY 1
    `)[0];

    const ctxTrend = document.getElementById('trendChart');
    if(trendChart) trendChart.destroy();
    trendChart = new Chart(ctxTrend, {
        type: 'line',
        data: {
            labels: trendData.values.map(v => v[0]),
            datasets: [{
                label: 'Claims Volume ($)',
                data: trendData.values.map(v => v[1]),
                borderColor: '#3b82f6',
                backgroundColor: 'rgba(59, 130, 246, 0.1)',
                fill: true,
                tension: 0.4
            }]
        },
        options: {
            scales: {
                y: { grid: { color: '#1f2937' }, ticks: { color: '#9ca3af' } },
                x: { grid: { display: false }, ticks: { color: '#9ca3af' } }
            },
            plugins: { legend: { display: false } }
        }
    });
}

// 5. Explorer
function loadTable(tableName, element) {
    // UI Cleanup
    document.querySelectorAll('.menu-item').forEach(m => m.classList.remove('active'));
    if(element) element.classList.add('active');
    
    const container = document.getElementById('explorer-table-container');
    container.innerHTML = '<div class="empty-state">Loading data...</div>';

    setTimeout(() => {
        try {
            const res = db.exec(`SELECT * FROM ${tableName} LIMIT 1000`);
            if (res.length > 0) {
                renderTable(res[0], 'explorer-table-container');
            } else {
                container.innerHTML = '<div class="empty-state">No records in this table.</div>';
            }
        } catch (e) {
            container.innerHTML = `<div class="empty-state" style="color: var(--danger)">Table error: ${e.message}</div>`;
        }
    }, 50);
}

function exportCSV() {
    alert("Exporting current query to CSV... (Simulation)");
}

init();
