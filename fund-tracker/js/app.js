/**
 * Main Application Orchestrator
 * State management, auth flow, and event bridging
 */

// Global State
let allFunds = [];
let userInvestments = [];
let fundGroups = [];
let selectedFund = null;
let allFundsCache = null;
let isFundsLoading = false;
let editingInvestmentId = null;
let currentView = 'individual';
let currentGroupFilter = 'all';
let currentUser = null;
let isSignedIn = false;
let accessToken = null;
let tokenClient;

const SYNC_COOLDOWN_MS = 15 * 60 * 1000;

/**
 * Initialize Application
 */
async function initApp() {
    await showGlobalLoader('Mutual Fund Tracker', 'Restoring your secure session...');
    checkAuthState();

    if (isSignedIn) {
        updateAuthUI();
        updateSyncUI();
        updateLoadingText('Fetching your groups...');
        fundGroups = await getCloudFundGroups();
        updateLoadingText('Synchronizing investments...');
        userInvestments = await getCloudInvestments();
        updateLoadingText('Verifying fund database...');
        await loadAllFundsCache();

        syncAutomatedGroups(); // Apply heuristic grouping
        showMainContent();
    } else {
        showMainContent();
    }
    hideGlobalLoader();
}

/**
 * Auth State Checker
 */
function checkAuthState() {
    const authData = localStorage.getItem('mf_auth');
    if (authData) {
        try {
            const parsed = JSON.parse(authData);
            if (parsed.expiry > Date.now() && parsed.accessToken && parsed.user) {
                accessToken = parsed.accessToken;
                currentUser = parsed.user;
                isSignedIn = true;

                // Legacy Cleanup
                Object.keys(localStorage).forEach(key => {
                    if (key.startsWith('nav_cache_') || key.startsWith('nav_')) localStorage.removeItem(key);
                });
                return;
            }
        } catch (e) { localStorage.removeItem('mf_auth'); }
    }
    isSignedIn = false;
}

/**
 * UI State Orchestration
 */
function showMainContent() {
    const mainContent = document.getElementById('mainContent');
    const loginContent = document.getElementById('loginContent');
    if (isSignedIn) {
        if (mainContent) mainContent.style.display = 'block';
        if (loginContent) loginContent.style.display = 'none';
        displayFunds();
        updateSummary();
    } else {
        if (mainContent) mainContent.style.display = 'none';
        if (loginContent) loginContent.style.display = 'flex';
    }
}

/**
 * Sync UI Logic
 */
function updateSyncUI() {
    const label = document.getElementById('lastSyncLabel');
    const syncBtn = document.getElementById('syncBtn');
    if (!label || !syncBtn) return;

    const lastSync = localStorage.getItem('last_global_sync');
    if (lastSync) {
        label.textContent = `Synced at ${new Date(parseInt(lastSync)).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
    }

    const now = Date.now();
    if (lastSync && (now - parseInt(lastSync)) < SYNC_COOLDOWN_MS) {
        syncBtn.classList.add('sync-btn-disabled');
        syncBtn.title = 'Data is fresh. Cooldown in progress.';
    } else {
        syncBtn.classList.remove('sync-btn-disabled');
        syncBtn.title = 'Refresh all NAVs';
    }
}

/**
 * Export/Import Logic
 */
function exportToJSON() {
    const data = { investments: userInvestments, exportDate: new Date().toISOString() };
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `mf-portfolio-${new Date().toISOString().split('T')[0]}.json`;
    a.click();
}

/**
 * App initialization
 */
document.addEventListener('DOMContentLoaded', () => {
    initApp();

    // Set max date for form
    const today = new Date().toISOString().split('T')[0];
    const dateInput = document.getElementById('investmentDate');
    if (dateInput) {
        dateInput.max = today;
        dateInput.value = today;
    }

    setupEventListeners();
    initializeGoogleAuth();
});

/**
 * Event Listeners
 */
function setupEventListeners() {
    const form = document.getElementById('addFundForm');
    if (form) form.addEventListener('submit', handleAddFund);

    const clearBtn = document.getElementById('clearForm');
    if (clearBtn) clearBtn.addEventListener('click', clearForm);

    const searchInput = document.getElementById('fundSearch');
    if (searchInput) {
        searchInput.addEventListener('input', debounce(handleSearch, 300));
        searchInput.addEventListener('focus', () => { if (searchInput.value.length > 2) handleSearch(); });
    }

    document.addEventListener('click', (e) => {
        if (!e.target.closest('.search-container')) {
            const dropdown = document.getElementById('searchDropdown');
            if (dropdown) dropdown.style.display = 'none';
        }
    });

    // Modal helpers
    document.querySelectorAll('[data-bs-dismiss="modal"]').forEach(btn => {
        btn.addEventListener('click', () => {
            const modal = btn.closest('.modal');
            if (modal) modal.classList.remove('show');
        });
    });
}

/**
 * Search Logic
 */
async function handleSearch() {
    const query = document.getElementById('fundSearch').value.trim();
    const dropdown = document.getElementById('searchDropdown');
    if (query.length < 2) { dropdown.style.display = 'none'; return; }

    showLoading();
    try {
        const funds = await searchMutualFunds(query);
        dropdown.innerHTML = funds.map(f => `
            <div class="search-dropdown-item" onclick="selectFund('${f.schemeCode}', '${f.schemeName.replace(/'/g, "\\'")}', '${f.fundType || f.category || 'N/A'}')">
                <div class="d-flex justify-content-between align-items-start">
                    <div class="flex-grow-1">
                        <div><strong>${f.schemeName}</strong></div>
                        <small class="text-muted">Code: ${f.schemeCode} | ${f.fundType || f.category || 'N/A'}</small>
                    </div>
                    <span class="badge ${f.schemeName.toLowerCase().includes('direct') ? 'bg-primary' : 'bg-success'} ms-2">
                        ${f.schemeName.toLowerCase().includes('direct') ? 'Direct' : 'Regular'}
                    </span>
                </div>
            </div>`).join('');
        dropdown.style.display = 'block';
    } finally { hideLoading(); }
}

function selectFund(code, name, cat) {
    selectedFund = { schemeCode: code, schemeName: name, category: cat };
    document.getElementById('fundSearch').value = name;
    document.getElementById('searchDropdown').style.display = 'none';
}

/**
 * Fund Management
 */
async function handleAddFund(e) {
    e.preventDefault();
    const code = selectedFund?.schemeCode;
    const date = document.getElementById('investmentDate').value;
    const amount = parseFloat(document.getElementById('investmentAmount').value);

    if (!code || !date || isNaN(amount)) return showError('Please fill all fields correctly.');

    showLoading();
    try {
        const nav = await getNAVForDate(code, date);
        const units = amount / nav;

        const investment = { id: editingInvestmentId || Date.now(), schemeCode: code, schemeName: selectedFund.schemeName, investmentDate: date, investmentAmount: amount, nav, category: selectedFund.category, units, addedDate: new Date().toISOString() };

        if (editingInvestmentId) {
            const idx = userInvestments.findIndex(i => String(i.id) === String(editingInvestmentId));
            if (idx !== -1) userInvestments[idx] = investment;
        } else {
            userInvestments.push(investment);
        }

        syncAutomatedGroups();
        await saveToCloud(userInvestments);
        clearForm();
        currentView === 'individual' ? displayFunds() : displayGroups();
        updateSummary();
        showSuccess(editingInvestmentId ? 'Fund updated' : 'Fund added');
        editingInvestmentId = null;
    } catch (err) { showError('Failed to add fund: ' + err.message); }
    finally { hideLoading(); }
}

function clearForm() {
    document.getElementById('addFundForm').reset();
    selectedFund = null;
    editingInvestmentId = null;
    document.getElementById('submitBtn').innerHTML = '<i class="bi bi-plus-lg"></i> Add Fund';
}

async function removeFund(id) {
    if (!confirm('Remove this investment?')) return;
    userInvestments = userInvestments.filter(i => String(i.id) !== String(id));
    fundGroups = fundGroups.map(g => ({ ...g, fundIds: g.fundIds.filter(fid => String(fid) !== String(id)) }));
    syncAutomatedGroups();
    await saveToCloud(userInvestments);
    await saveToCloudFundGroups(fundGroups);
    currentView === 'individual' ? displayFunds() : displayGroups();
    updateSummary();
}

function editFund(id) {
    const inv = userInvestments.find(i => String(i.id) === String(id));
    if (!inv) return;
    editingInvestmentId = id;
    selectedFund = { schemeCode: inv.schemeCode, schemeName: inv.schemeName, category: inv.category };
    document.getElementById('fundSearch').value = inv.schemeName;
    document.getElementById('investmentDate').value = inv.investmentDate;
    document.getElementById('investmentAmount').value = inv.investmentAmount;
    document.getElementById('submitBtn').innerHTML = '<i class="bi bi-check-lg"></i> Update Fund';
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

/**
 * View Management
 */
function switchView(view) {
    currentView = view;
    document.getElementById('individualViewBtn').classList.toggle('active', view === 'individual');
    document.getElementById('groupsViewBtn').classList.toggle('active', view === 'groups');
    document.getElementById('groupControls').style.display = view === 'groups' ? 'block' : 'none';
    if (view === 'groups') updateGroupFilterUI();
    view === 'individual' ? displayFunds() : displayGroups();
}

function switchGroupFilter(filter) {
    currentGroupFilter = filter;
    updateGroupFilterUI();
    displayGroups();
}

/**
 * Group Logic
 */
function syncAutomatedGroups() {
    if (userInvestments.length === 0) {
        fundGroups = fundGroups.filter(g => !g.isAutomated);
        return;
    }

    // Filter and clean manual groups: remove stale fund IDs and delete empty groups
    const manualGroups = fundGroups.filter(g => !g.isAutomated).map(g => {
        // Only keep IDs that still exist in userInvestments
        g.fundIds = g.fundIds.filter(fid => userInvestments.some(inv => String(inv.id) === String(fid)));
        return g;
    }).filter(g => g.fundIds.length > 0);

    const automatedGroups = [];

    // Base System Groups: Only add if funds exist
    const directFids = userInvestments.filter(i => i.schemeName.toLowerCase().includes('direct')).map(i => String(i.id));
    const regularFids = userInvestments.filter(i => !i.schemeName.toLowerCase().includes('direct')).map(i => String(i.id));

    if (directFids.length > 0) {
        automatedGroups.push({ id: 'auto-direct', name: 'Direct Funds', autoType: 'direct', isAutomated: true, fundIds: directFids });
    }
    if (regularFids.length > 0) {
        automatedGroups.push({ id: 'auto-regular', name: 'Regular Funds', autoType: 'regular', isAutomated: true, fundIds: regularFids });
    }

    // Heuristic Grouping: Fund Houses
    const houses = {};
    const houseStopWords = ["Small", "Mid", "Large", "Flexi", "Multi", "Index", "Nifty", "ELSS", "Tax", "Equity", "Liquid", "Debt", "Hybrid", "Fund", "Balanced", "Opportunities", "Emerging", "Contra", "Value", "Focused", "Bluechip", "Aggressive", "Conservative", "Dynamic", "Arbitrage"];

    userInvestments.forEach(inv => {
        const words = inv.schemeName.split(' ');
        let stopIndex = words.length;
        for (let i = 0; i < words.length; i++) {
            const cleanWord = words[i].toLowerCase().replace(/[^a-z]/g, '');
            if (houseStopWords.some(sw => cleanWord.includes(sw.toLowerCase()))) {
                stopIndex = i; break;
            }
        }
        let house = words.slice(0, Math.max(1, stopIndex)).join(' ');
        house = house.replace(/\s+(Mutual|AMC|MF|Asset|Management)$/i, '').trim() + " Funds";
        if (!houses[house]) houses[house] = [];
        houses[house].push(String(inv.id));
    });

    for (const [house, ids] of Object.entries(houses)) {
        if (ids.length > 0) {
            automatedGroups.push({ id: `house-${house.replace(/\s+/g, '-')}`, name: house, autoType: 'house', isAutomated: true, fundIds: ids });
        }
    }

    // Heuristic Grouping: Categories/Types/Sectors (Industry Standard)
    const typeKeywords = [
        // Market Cap
        { name: "Small Cap Funds", patterns: [/small\s*cap/i], cat: 'cap' },
        { name: "Mid Cap Funds", patterns: [/mid\s*cap/i], cat: 'cap' },
        { name: "Large Cap Funds", patterns: [/large\s*cap/i], cat: 'cap' },
        { name: "Flexi Cap Funds", patterns: [/flexi\s*cap/i], cat: 'cap' },
        { name: "Multi Cap Funds", patterns: [/multi\s*cap/i], cat: 'cap' },

        // Asset Class & Solution
        { name: "ELSS Funds", patterns: [/elss/i, /tax\s*saver/i], cat: 'strategy' },
        { name: "Index Funds", patterns: [/index/i, /nifty/i, /sensex/i, /etf/i, /passive/i], cat: 'strategy' },
        { name: "Liquid Funds", patterns: [/liquid/i, /overnight/i, /money\s*market/i], cat: 'asset' },
        { name: "Debt Funds", patterns: [/debt/i, /gilt/i, /corporate/i, /treasury/i, /short\s*term/i, /duration/i], cat: 'asset' },
        { name: "Hybrid Funds", patterns: [/hybrid/i, /balanced/i, /arbitrage/i, /multi\s*asset/i, /equity\s*savings/i], cat: 'asset' },
        { name: "Equity Funds", patterns: [/equity/i, /growth/i, /opportunit/i, /focused/i, /alpha/i, /bluechip/i], cat: 'asset' },
        { name: "Gold & Silver Funds", patterns: [/gold/i, /silver/i, /commodity/i], cat: 'asset' },
        { name: "International Funds", patterns: [/international/i, /global/i, /us\s*equity/i, /nasdaq/i, /world/i, /greater\s*china/i, /emerging\s*markets/i], cat: 'asset' },

        // Sectoral & Thematic
        { name: "Banking & Financial Funds", patterns: [/bank/i, /psu/i, /financial/i, /fsi/i], cat: 'sector' },
        { name: "IT & Tech Funds", patterns: [/it/i, /tech/i, /digital/i], cat: 'sector' },
        { name: "Healthcare & Pharma Funds", patterns: [/pharma/i, /health/i], cat: 'sector' },
        { name: "Infrastructure Funds", patterns: [/infra/i, /energy/i, /power/i, /realestate/i], cat: 'sector' },
        { name: "Consumption Funds", patterns: [/consum/i, /fmcg/i, /retail/i], cat: 'sector' },

        // Strategy & Style
        { name: "Value & Contra Funds", patterns: [/value/i, /contra/i, /dividend/i, /yield/i], cat: 'strategy' },
        { name: "Focused Funds", patterns: [/focused/i, /top\s*\d+/i], cat: 'strategy' },
        { name: "Momentum & Quant Funds", patterns: [/momentum/i, /quant/i, /factor/i, /alpha/i], cat: 'strategy' },
        { name: "Opportunity Funds", patterns: [/opportunit/i, /special/i, /thematic/i, /tactical/i], cat: 'strategy' },
        { name: "ESG & Sustainability Funds", patterns: [/esg/i, /responsible/i, /sustainable/i], cat: 'strategy' },
        { name: "Retirement & Children Funds", patterns: [/retirement/i, /pension/i, /children/i, /solution/i], cat: 'strategy' }
    ];

    const typedFunds = {};
    userInvestments.forEach(inv => {
        let matches = new Set();
        typeKeywords.forEach(cfg => {
            if (cfg.patterns.some(p => p.test(inv.schemeName))) {
                matches.add(JSON.stringify({ name: cfg.name, cat: cfg.cat }));
            }
        });

        // Logical inference remains for core asset classes
        const matchesArr = [...matches].map(m => JSON.parse(m));
        const isEquity = matchesArr.some(m => m.cat === 'cap' || m.cat === 'sector' || ['ELSS Funds', 'Index Funds', 'Equity Funds'].includes(m.name));
        const isHybrid = matchesArr.some(m => m.name === "Hybrid Funds");
        
        if (isEquity) matches.add(JSON.stringify({ name: "Equity Funds", cat: 'asset' }));
        if (matchesArr.some(m => m.name.includes("Debt Funds") || m.name === "Liquid Funds")) matches.add(JSON.stringify({ name: "Debt Funds", cat: 'asset' }));

        // Ensure every Equity/Hybrid fund has a Strategy group (Catch-all for Diversified funds)
        const hasStrategy = matchesArr.some(m => m.cat === 'strategy');
        if (!hasStrategy && (isEquity || isHybrid)) {
            matches.add(JSON.stringify({ name: "Core & Diversified Funds", cat: 'strategy' }));
        }

        matches.forEach(mJson => {
            const m = JSON.parse(mJson);
            if (!typedFunds[m.name]) typedFunds[m.name] = { ids: [], cat: m.cat };
            typedFunds[m.name].ids.push(String(inv.id));
        });
    });

    for (const [name, data] of Object.entries(typedFunds)) {
        if (data.ids.length > 0) {
            automatedGroups.push({ id: `type-${name.replace(/\s+/g, '-')}`, name, autoType: data.cat, isAutomated: true, fundIds: data.ids });
        }
    }

    fundGroups = [...manualGroups, ...automatedGroups];
}

let currentEditingGroupId = null;

function openCreateGroupModal() {
    const container = document.getElementById('createGroupFundList');
    container.innerHTML = userInvestments.map(inv => `
        <div class="fund-assignment-item">
            <input type="checkbox" class="form-check-input" id="create-fund-${inv.id}" value="${inv.id}">
            <label class="form-check-label" for="create-fund-${inv.id}">${inv.schemeName}</label>
        </div>`).join('');
    document.getElementById('createGroupModal').classList.add('show');
}

async function createGroup() {
    const name = document.getElementById('groupName').value.trim();
    const fids = Array.from(document.querySelectorAll('#createGroupFundList input:checked')).map(cb => cb.value);
    if (!name || fids.length === 0) return showError('Enter name and select funds');

    fundGroups.push({ id: 'custom-' + Date.now(), name, fundIds: fids, isAutomated: false });
    await saveToCloudFundGroups(fundGroups);
    document.getElementById('createGroupModal').classList.remove('show');
    displayGroups();
}

/**
 * Group Management Logic
 */
function editGroupModal(groupId) {
    const group = fundGroups.find(g => String(g.id) === String(groupId));
    if (!group) return;

    currentEditingGroupId = groupId;
    document.getElementById('editGroupName').value = group.name;

    const assignmentList = document.getElementById('fundAssignmentList');
    assignmentList.innerHTML = userInvestments.map(inv => {
        const isSelected = group.fundIds.some(id => String(id) === String(inv.id));
        return `
            <div class="fund-assignment-item">
                <input type="checkbox" class="form-check-input" id="edit-fund-${inv.id}" value="${inv.id}" ${isSelected ? 'checked' : ''}>
                <label class="form-check-label" for="edit-fund-${inv.id}">${inv.schemeName}</label>
            </div>`;
    }).join('');

    document.getElementById('editGroupModal').classList.add('show');
}

async function updateGroup() {
    const groupName = document.getElementById('editGroupName').value.trim();
    const fids = Array.from(document.querySelectorAll('#fundAssignmentList input:checked')).map(cb => cb.value);

    if (!groupName || fids.length === 0) return showError('Enter name and select funds');

    const group = fundGroups.find(g => String(g.id) === String(currentEditingGroupId));
    if (group) {
        group.name = groupName;
        group.fundIds = fids;
        await saveToCloudFundGroups(fundGroups);
        document.getElementById('editGroupModal').classList.remove('show');
        displayGroups();
        showSuccess('Group updated');
    }
}

async function deleteGroup() {
    const group = fundGroups.find(g => String(g.id) === String(currentEditingGroupId));
    if (!group) return;

    if (confirm(`Delete group "${group.name}"?`)) {
        fundGroups = fundGroups.filter(g => String(g.id) !== String(currentEditingGroupId));
        await saveToCloudFundGroups(fundGroups);
        document.getElementById('editGroupModal').classList.remove('show');
        displayGroups();
        showSuccess('Group deleted');
    }
}

/**
 * Data Refresh
 */
async function refreshAllData() {
    const btn = document.getElementById('syncBtn');
    if (btn.classList.contains('sync-btn-disabled')) return;

    btn.classList.add('sync-btn-disabled');
    try {
        NAVManager.sessionCache.clear();
        const codes = [...new Set(userInvestments.map(i => i.schemeCode))];
        await Promise.all(codes.map(c => NAVManager.getNAV(c, true)));
        localStorage.setItem('last_global_sync', Date.now().toString());
        updateSyncUI();
        syncAutomatedGroups(); // Force refresh automated groups
        currentView === 'individual' ? displayFunds() : displayGroups();
        updateSummary();
        showSuccess('Data refreshed');
    } catch (err) { showError('Sync failed'); }
    finally { btn.classList.remove('sync-btn-disabled'); }
}

/**
 * Auth Logic
 */
function initializeGoogleAuth() {
    if (typeof google === 'undefined') { setTimeout(initializeGoogleAuth, 500); return; }
    tokenClient = google.accounts.oauth2.initTokenClient({
        client_id: '648600237663-25le2m3002pk7si6g511k7dssrsnv1i8.apps.googleusercontent.com',
        scope: 'https://www.googleapis.com/auth/drive.appdata email profile',
        callback: async (res) => {
            if (res.access_token) {
                accessToken = res.access_token;
                showGlobalLoader('Signing in...', 'Retrieving profile...');
                const userRes = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', { headers: { Authorization: `Bearer ${accessToken}` } });
                const userData = await userRes.json();
                currentUser = { name: userData.name || userData.email, email: userData.email, avatar: userData.picture };
                isSignedIn = true;
                localStorage.setItem('mf_auth', JSON.stringify({ accessToken, user: currentUser, expiry: Date.now() + 3600000 }));
                await initApp();
            }
        }
    });
}

function signInWithGoogle() { tokenClient?.requestAccessToken(); }
function signOut() {
    isSignedIn = false; currentUser = null; accessToken = null;
    localStorage.removeItem('mf_auth');
    showMainContent();
}

function updateAuthUI() {
    const userInfo = document.getElementById('userInfo');
    if (isSignedIn && currentUser) {
        userInfo.style.display = 'flex';
        document.getElementById('userName').textContent = currentUser.name;
        document.getElementById('userAvatar').src = currentUser.avatar;
        document.getElementById('loginContent').style.display = 'none';
        document.getElementById('mainContent').style.display = 'block';
    } else {
        userInfo.style.display = 'none';
        document.getElementById('loginContent').style.display = 'flex';
        document.getElementById('mainContent').style.display = 'none';
    }
}

// Utility
function debounce(fn, ms) {
    let t;
    return (...args) => { clearTimeout(t); t = setTimeout(() => fn(...args), ms); };
}
