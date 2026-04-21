/**
 * Main Application Orchestrator
 * State management, auth flow, and event bridging
 */

// Global State
var allFunds = [];
var userInvestments = [];
var fundGroups = [];
var selectedFund = null;
var allFundsCache = null;
var isFundsLoading = false;
var editingInvestmentId = null;
var pendingDeleteId = null;
var pendingDeleteType = 'fund'; // 'fund' or 'group'
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
        populateFundHouses();

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
        
        // Default View State
        switchMainView('individual');
    } else {
        if (mainContent) mainContent.style.display = 'none';
        if (loginContent) loginContent.style.display = 'flex';
    }
}

/**
 * Handle Tab Switching in Navigation Hub
 */
function switchMainView(targetView) {
    currentView = targetView;
    
    // Update active pill UI
    document.querySelectorAll('.nav-v2-pill').forEach(btn => {
        btn.classList.toggle('active', btn.getAttribute('data-view') === targetView);
    });

    // Toggle Content Containers
    const containers = {
        individual: document.getElementById('fundsContainer'),
        groups: document.getElementById('groupsContainer'),
        research: document.getElementById('researchContainer'),
        explore: document.getElementById('exploreContainer'),
        summary: document.getElementById('summaryStatsContainer'),
        addFund: document.getElementById('addFundCard'),
        addGroup: document.getElementById('addGroupCard')
    };
    const masterGrid = document.getElementById('masterGrid');

    // Update Grid Density Class (Standardized to 4 columns everywhere)
    if (masterGrid) {
        masterGrid.classList.remove('grid-4-col', 'grid-3-col');
        masterGrid.classList.add('grid-4-col');
    }

    // Helper to hide all
    Object.values(containers).forEach(c => { if(c) c.style.display = 'none'; });

    const explorerFilters = document.getElementById('explorerFilters');

    if (targetView === 'individual') {
        if (containers.individual) containers.individual.style.display = 'contents';
        if (containers.summary) containers.summary.style.display = 'contents';
        if (containers.addFund) containers.addFund.style.display = 'flex';
        
        // Only show explorer results if there's actual content (more than the placeholder search icon/text)
        const hasResults = document.getElementById('discoveryResults')?.children.length > 1;
        if (containers.explore && hasResults) {
            containers.explore.style.display = 'contents';
            if (explorerFilters) explorerFilters.style.display = 'none';
        }
        
        displayFunds();
        updateSummary();
        displayExplore(); // Ensure it's rendered at least once
    } else if (targetView === 'groups') {
        if (containers.groups) containers.groups.style.display = 'contents';
        if (containers.addGroup) containers.addGroup.style.display = 'flex';
        displayGroups();
    } else if (targetView === 'research') {
        if (containers.research) containers.research.style.display = 'contents';
        
        const hasResults = document.getElementById('discoveryResults')?.children.length > 1;
        if (containers.explore && hasResults) {
            containers.explore.style.display = 'contents';
            if (explorerFilters) explorerFilters.style.display = 'none';
        }
        
        displayResearch();
        displayExplore(); 
    } else if (targetView === 'explore') {
        if (containers.explore) containers.explore.style.display = 'contents';
        if (explorerFilters) explorerFilters.style.display = 'block'; // Show filters in explore view
        displayExplore();
    } else {
        showInfo(`${targetView.charAt(0).toUpperCase() + targetView.slice(1)} module coming soon!`);
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
    
    const houseSelect = document.getElementById('fundHouseSelect');
    if (houseSelect) {
        houseSelect.addEventListener('change', () => {
            document.getElementById('fundSearchContainer').style.display = 'block';
            document.getElementById('fundSearch').value = '';
            document.getElementById('fundRadioContainer').style.display = 'none';
            selectedFund = null;
        });
    }

    document.addEventListener('click', (e) => {
        if (!e.target.closest('.search-container')) {
            const sd = document.getElementById('searchDropdown');
            if (sd) sd.style.display = 'none';
            const hd = document.getElementById('houseDropdown');
            if (hd) hd.style.display = 'none';
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
 * Helpers
 */
function getBaseMFName(name) {
    let n = name;
    const lower = n.toLowerCase();
    const markers = [' - direct', ' - regular', ' direct', ' regular'];
    let minIdx = n.length;
    markers.forEach(m => {
        const idx = lower.indexOf(m);
        if (idx !== -1 && idx < minIdx) minIdx = idx;
    });
    const sub = n.substring(0, minIdx).trim();
    return sub.length > 0 ? sub : n;
}

async function populateFundHouses() {
    const dropdown = document.getElementById('houseDropdown');
    if (!dropdown || !allFundsCache) return;

    const houses = new Map();
    const knownMultiWords = {
        "aditya": "Aditya Birla", "icici": "ICICI Prudential", "kotak": "Kotak Mahindra",
        "canara": "Canara Robeco", "mirae": "Mirae Asset", "motilal": "Motilal Oswal",
        "nippon": "Nippon India", "parag": "Parag Parikh", "pgim": "PGIM India",
        "franklin": "Franklin Templeton", "whiteoak": "WhiteOak", "baroda": "Baroda BNP Paribas",
        "jioblackrock": "JioBlackrock", "jio": "JioBlackrock", "bandhan": "Bandhan"
    };

    allFundsCache.forEach(f => {
        try {
            if (!f || !f.schemeName) return;
            let fw = f.schemeName.trim().split(/\s+/)[0].replace(/[^a-zA-Z]/g, '').toLowerCase();
            if (!fw || fw.length < 2) return;
            let dName = knownMultiWords[fw] || (fw.charAt(0).toUpperCase() + fw.slice(1).toLowerCase());
            houses.set(dName, (houses.get(dName) || 0) + 1);
        } catch(e) {}
    });

    const houseList = Array.from(houses.entries())
        .filter(([n, c]) => c > 5 && n !== 'The' && n !== 'Fund')
        .map(([n]) => n)
        .sort((a,b) => a.localeCompare(b));

    dropdown.innerHTML = houseList.map(h => `
        <div class="search-dropdown-item" onclick="selectHouse('${h.replace(/'/g, "\\'")}', '${h.split(' ')[0]}')">
            ${h}
        </div>
    `).join('');
}

function selectHouse(displayName, searchKey) {
    document.getElementById('fundHouseInput').value = displayName;
    document.getElementById('houseDropdown').style.display = 'none';
    
    // Setup next step
    document.getElementById('fundSearch').value = '';
    document.getElementById('fundSearch').setAttribute('data-house', searchKey);
    document.getElementById('fundSearchContainer').style.display = 'block';
    document.getElementById('fundRadioContainer').style.display = 'none';
    
    setTimeout(() => document.getElementById('fundSearch').focus(), 100);
}

function filterHouses() {
    const query = document.getElementById('fundHouseInput').value.toLowerCase();
    const dropdown = document.getElementById('houseDropdown');
    const items = dropdown.querySelectorAll('.search-dropdown-item');
    
    let visibleCount = 0;
    items.forEach(it => {
        const txt = it.textContent.toLowerCase();
        const matches = query === '' || txt.includes(query);
        it.style.display = matches ? 'block' : 'none';
        if (matches) visibleCount++;
    });
    
    // Always show if there are items and the field is focused
    dropdown.style.display = visibleCount > 0 ? 'block' : 'none';
}

/**
 * Search Logic
 */
async function handleSearch() {
    const searchInput = document.getElementById('fundSearch');
    const query = searchInput.value.trim();
    const dropdown = document.getElementById('searchDropdown');
    const houseKey = searchInput.getAttribute('data-house');
    
    if (query.length < 2 || !houseKey) { 
        dropdown.style.display = 'none'; 
        return; 
    }

    showLoading();
    try {
        if (!allFundsCache) await loadAllFundsCache();
        
        let funds = allFundsCache.filter(f => 
            f.schemeName.toLowerCase().includes(houseKey.toLowerCase()) && 
            f.schemeName.toLowerCase().includes(query.toLowerCase())
        );

        const grouped = {};
        funds.forEach(f => {
            const base = getBaseMFName(f.schemeName);
            if (!grouped[base]) grouped[base] = [];
            grouped[base].push(f);
        });

        const topGroups = Object.keys(grouped).slice(0, 10);
        
        dropdown.innerHTML = topGroups.map(gName => `
            <div class="search-dropdown-item" onclick="selectFundBase('${gName.replace(/'/g, "\\'")}', '${houseKey}')">
                <strong>${gName}</strong>
            </div>`).join('');
            
        dropdown.style.display = 'block';
    } finally { hideLoading(); }
}

function selectFundBase(baseName, houseStr) {
    document.getElementById('fundSearch').value = baseName;
    document.getElementById('searchDropdown').style.display = 'none';
    
    selectedFund = null;
    
    const funds = allFundsCache.filter(f => f.schemeName.toLowerCase().includes(houseStr.toLowerCase()) && getBaseMFName(f.schemeName) === baseName);
    
    const optsContainer = document.getElementById('fundRadioContainer');
    const radiosObj = document.getElementById('fundRadioOptions');
    
    radiosObj.innerHTML = funds.map((f, idx) => {
        const nameLower = f.schemeName.toLowerCase();
        
        let planType = nameLower.includes('direct') ? 'Direct' : 'Regular';
        let planOption = 'Growth';
        
        if (nameLower.includes('idcw')) planOption = 'IDCW';
        else if (nameLower.includes('dividend')) planOption = 'Dividend';
        else if (nameLower.includes('payout')) planOption = 'Payout';
        
        const shortName = `${planType} - ${planOption}`;
        
        return `
        <div style="display: flex; align-items: center; gap: 5px; white-space: nowrap; overflow: hidden;">
            <input type="radio" id="f_opt_${f.schemeCode}" name="selectedSchemeCode" value="${f.schemeCode}" 
                   data-name="${f.schemeName.replace(/'/g, "\\'")}" ${idx === 0 ? 'checked' : ''} 
                   style="margin: 0; width: 14px; height: 14px; cursor: pointer;">
            <label for="f_opt_${f.schemeCode}" title="${f.schemeName}" 
                   style="font-size: 11px; cursor: pointer; color: rgba(255,255,255,0.9); margin: 0; line-height: 1.2; text-overflow: ellipsis; overflow: hidden;">
                ${shortName}
            </label>
        </div>`;
    }).join('');
    
    optsContainer.style.display = 'block';
}

/**
 * Fund Management
 */
/**
 * Fund Management
 */
async function handleAddFund(e) {
    e.preventDefault();
    
    const selectedRadio = document.querySelector('input[name="selectedSchemeCode"]:checked');
    if (!selectedRadio && !selectedFund) {
        return showError('Please select a specific fund option.');
    }
    
    const code = selectedRadio ? selectedRadio.value : selectedFund?.schemeCode;
    const finalName = selectedRadio ? selectedRadio.getAttribute('data-name') : selectedFund?.schemeName;
    
    const date = document.getElementById('investmentDate').value;
    const amount = parseFloat(document.getElementById('investmentAmount').value);

    if (!code || !date || isNaN(amount)) return showError('Please fill all fields correctly.');

    showLoading();
    try {
        const nav = await getNAVForDate(code, date);
        const units = amount / nav;

        const investment = { id: editingInvestmentId || Date.now(), schemeCode: code, schemeName: finalName, investmentDate: date, investmentAmount: amount, nav, category: 'N/A', units, addedDate: new Date().toISOString() };

        if (editingInvestmentId) {
            const idx = userInvestments.findIndex(i => String(i.id) === String(editingInvestmentId));
            if (idx !== -1) userInvestments[idx] = investment;
        } else {
            userInvestments.push(investment);
        }

        syncAutomatedGroups();
        await saveToCloud(userInvestments);
        clearForm();
        displayFunds();
        displayGroups();
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
    document.getElementById('fundHouseInput').value = '';
    document.getElementById('fundSearch').value = '';
    document.getElementById('fundSearchContainer').style.display = 'none';
    document.getElementById('fundRadioContainer').style.display = 'none';
    document.getElementById('submitBtn').innerHTML = '<i class="bi bi-plus-lg"></i> Add';
}

async function editFund(id) {
    const inv = userInvestments.find(i => String(i.id) === String(id));
    if (!inv) return;

    window.scrollTo({ top: 0, behavior: 'smooth' });
    editingInvestmentId = inv.id;
    document.getElementById('submitBtn').innerHTML = '<i class="bi bi-check-lg"></i> Update';

    // 1. Populate House
    const houseName = inv.schemeName.trim().split(/\s+/)[0];
    document.getElementById('fundHouseInput').value = houseName;
    selectHouse(houseName, houseName); // Trigger dropdown logic

    // 2. Populate Fund Base Name
    const baseName = getBaseMFName(inv.schemeName);
    document.getElementById('fundSearch').value = baseName;
    selectFundBase(baseName, houseName); // Populate radios

    // 3. Select correct radio
    setTimeout(() => {
        const radio = document.querySelector(`input[name="selectedSchemeCode"][value="${inv.schemeCode}"]`);
        if (radio) radio.checked = true;
    }, 100);

    // 4. Populate Date & Amount
    document.getElementById('investmentDate').value = inv.investmentDate;
    document.getElementById('investmentAmount').value = inv.investmentAmount;
}

async function removeFund(id) {
    const inv = userInvestments.find(i => String(i.id) === String(id));
    if (!inv) return;
    
    pendingDeleteId = id;
    pendingDeleteType = 'fund';
    const nameEl = document.getElementById('deleteFundName');
    if (nameEl) nameEl.textContent = inv.schemeName;
    
    document.getElementById('deleteConfirmModal').classList.add('show');
}

async function confirmDeleteFund() {
    if (!pendingDeleteId) return;
    
    // Hide confirmation modal
    document.getElementById('deleteConfirmModal').classList.remove('show');
    
    // Show global processing spinner
    showLoading();
    
    try {
        const id = pendingDeleteId;
        if (pendingDeleteType === 'fund') {
            userInvestments = userInvestments.filter(i => String(i.id) !== String(id));
            fundGroups = fundGroups.map(g => ({ ...g, fundIds: g.fundIds.filter(fid => String(fid) !== String(id)) }));
            syncAutomatedGroups();
            await saveToCloud(userInvestments);
            await saveToCloudFundGroups(fundGroups);
        } else {
            fundGroups = fundGroups.filter(g => String(g.id) !== String(id));
            await saveToCloudFundGroups(fundGroups);
        }
        
        displayFunds();
        displayGroups();
        updateSummary();
        showSuccess(pendingDeleteType === 'fund' ? 'Fund removed' : 'Group deleted');
    } catch (err) {
        showError('Failed: ' + err.message);
    } finally {
        pendingDeleteId = null;
        hideLoading();
    }
}



/**
 * Group Logic
 */
function syncAutomatedGroups() {
    // Strip automated groups - user requested purely manual control
    fundGroups = fundGroups.filter(g => !g.isAutomated);

    // Clean manual groups: remove stale fund IDs and delete empty groups
    fundGroups = fundGroups.map(g => {
        g.fundIds = g.fundIds.filter(fid => userInvestments.some(inv => String(inv.id) === String(fid)));
        return g;
    }).filter(g => g.fundIds.length > 0);
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

    // Hide edit modal
    document.getElementById('editGroupModal').classList.remove('show');

    // Show custom confirm modal
    pendingDeleteId = currentEditingGroupId;
    pendingDeleteType = 'group';
    const nameEl = document.getElementById('deleteFundName');
    if (nameEl) nameEl.textContent = `Group: ${group.name}`;
    
    document.getElementById('deleteConfirmModal').classList.add('show');
}

/**
 * Data Refresh
 */
async function refreshAllData() {
    const btn = document.getElementById('syncBtn');
    const label = document.getElementById('lastSyncLabel');
    if (btn.classList.contains('sync-btn-disabled')) return;

    btn.classList.add('sync-btn-disabled');
    try {
        NAVManager.sessionCache.clear();
        const codes = [...new Set(userInvestments.map(i => i.schemeCode))];
        
        // Batch Processing (Safe Queueing)
        const BATCH_SIZE = 3;
        for (let i = 0; i < codes.length; i += BATCH_SIZE) {
            const batch = codes.slice(i, i + BATCH_SIZE);
            if (label) label.textContent = `Syncing ${i + batch.length}/${codes.length}...`;
            await Promise.all(batch.map(c => NAVManager.getNAV(c, true)));
            
            // Tiny rest between batches
            if (i + BATCH_SIZE < codes.length) await new Promise(r => setTimeout(r, 200));
        }

        localStorage.setItem('last_global_sync', Date.now().toString());
        updateSyncUI();
        syncAutomatedGroups(); 
        displayFunds();
        displayGroups();
        updateSummary();
        showSuccess('Portfolio Synced Successfully');
    } catch (err) { 
        showError('Sync partially failed'); 
        updateSyncUI();
    }
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

/**
 * Global Loader Management
 */
async function showGlobalLoader(title = 'Loading', subtext = 'Please wait...') {
    const loader = document.getElementById('loadingScreen');
    if (!loader) return;
    
    loader.querySelector('.loading-text').textContent = title;
    loader.querySelector('.loading-subtext').textContent = subtext;
    loader.style.display = 'flex';
    document.body.classList.add('loading-lock');
}

function updateLoadingText(subtext) {
    const sub = document.querySelector('#loadingScreen .loading-subtext');
    if (sub) sub.textContent = subtext;
}

function hideGlobalLoader() {
    const loader = document.getElementById('loadingScreen');
    if (!loader) return;
    
    loader.style.opacity = '0';
    setTimeout(() => {
        loader.style.display = 'none';
        loader.style.opacity = '1';
        document.body.classList.remove('loading-lock');
    }, 400);
}
