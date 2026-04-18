/**
 * API & Data Management Module
 * Handles IndexedDB, MF API, and Cloud Synchronization
 */

// IndexedDB Configuration
const DB_NAME = 'MFTrackerDB';
const DB_VERSION = 2;
const STORE_NAME = 'masterData';
const NAV_STORE_NAME = 'navHistory';

/**
 * Initialize and get IndexedDB instance
 */
function getDB() {
    return new Promise((resolve, reject) => {
        const request = indexedDB.open(DB_NAME, DB_VERSION);
        request.onupgradeneeded = (e) => {
            const db = e.target.result;
            if (!db.objectStoreNames.contains(STORE_NAME)) {
                db.createObjectStore(STORE_NAME);
            }
            if (!db.objectStoreNames.contains(NAV_STORE_NAME)) {
                db.createObjectStore(NAV_STORE_NAME);
            }
        };
        request.onsuccess = (e) => resolve(e.target.result);
        request.onerror = (e) => reject(e.target.error);
    });
}

/**
 * Save data to IndexedDB
 */
async function saveToDB(key, data, storeName = STORE_NAME) {
    try {
        const db = await getDB();
        return new Promise((resolve, reject) => {
            const transaction = db.transaction(storeName, 'readwrite');
            const store = transaction.objectStore(storeName);
            store.put(data, key);
            transaction.oncomplete = () => resolve();
            transaction.onerror = (e) => reject(e.target.error);
        });
    } catch (err) {
        console.warn(`IndexedDB write failed for store ${storeName}`, err);
    }
}

/**
 * Retrieve data from IndexedDB
 */
async function getFromDB(key, storeName = STORE_NAME) {
    try {
        const db = await getDB();
        return new Promise((resolve, reject) => {
            const transaction = db.transaction(storeName, 'readonly');
            const store = transaction.objectStore(storeName);
            const request = store.get(key);
            request.onsuccess = () => resolve(request.result);
            request.onerror = (e) => reject(e.target.error);
        });
    } catch (err) {
        return null;
    }
}

/**
 * Centralized NAV Fetch Manager
 * Optimized with Promise Deduplication and Stale-While-Revalidate caching
 */
const NAVManager = {
    promises: new Map(),
    sessionCache: new Map(),
    queue: [],
    activeCount: 0,
    MAX_CONCURRENCY: 2, // Safe concurrency limit
    
    async getNAV(schemeCode, forceRefresh = false) {
        // 1. Session Memory Cache (Fastest) - 1 hour freshness
        if (!forceRefresh && this.sessionCache.has(schemeCode)) {
            const cached = this.sessionCache.get(schemeCode);
            if (Date.now() - cached.timestamp < 3600000) return cached.data;
        }

        // 2. Promise Deduplication
        if (this.promises.has(schemeCode)) return this.promises.get(schemeCode);

        const fetchPromise = (async () => {
            try {
                // 3. Persistent IndexedDB Cache - 4 hour freshness
                if (!forceRefresh) {
                    const dbData = await getFromDB(schemeCode, NAV_STORE_NAME);
                    if (dbData && (Date.now() - dbData.timestamp < 14400000)) {
                        this.sessionCache.set(schemeCode, dbData);
                        return dbData.data;
                    }
                }

                // 4. Concurrency Controlled Network Fetch
                return await this.enqueueRequest(schemeCode);
            } catch (err) {
                console.warn(`NAVManager: Using stale/fallback for ${schemeCode}`, err);
                const fallback = await getFromDB(schemeCode, NAV_STORE_NAME);
                if (fallback) return fallback.data;
                throw err;
            } finally {
                this.promises.delete(schemeCode);
            }
        })();

        this.promises.set(schemeCode, fetchPromise);
        return fetchPromise;
    },

    async enqueueRequest(schemeCode) {
        return new Promise((resolve, reject) => {
            this.queue.push({ schemeCode, resolve, reject });
            this.processQueue();
        });
    },

    async processQueue() {
        if (this.activeCount >= this.MAX_CONCURRENCY || this.queue.length === 0) return;

        const { schemeCode, resolve, reject } = this.queue.shift();
        this.activeCount++;

        try {
            // Safety delay between requests
            await new Promise(r => setTimeout(r, 350));

            const controller = new AbortController();
            const timer = setTimeout(() => controller.abort(), 12000);
            const response = await fetch(`https://api.mfapi.in/mf/${schemeCode}`, { signal: controller.signal });
            clearTimeout(timer);

            if (!response.ok) throw new Error(`API Error: ${response.status}`);
            const rawData = await response.json();
            
            if (!rawData.data || rawData.data.length === 0) throw new Error('Empty API Response');

            const result = {
                nav: parseFloat(rawData.data[0].nav),
                date: rawData.data[0].date,
                data: rawData.data
            };

            const payload = { data: result, timestamp: Date.now() };
            await saveToDB(schemeCode, payload, NAV_STORE_NAME);
            this.sessionCache.set(schemeCode, payload);
            resolve(result);
        } catch (err) {
            reject(err);
        } finally {
            this.activeCount--;
            this.processQueue();
        }
    }
};

/**
 * Get current NAV for a fund
 */
async function getCurrentNAV(schemeCode, isManualRefresh = false) {
    return await NAVManager.getNAV(schemeCode, isManualRefresh);
}

/**
 * Get NAV for a specific date using MF API
 */
async function getNAVForDate(schemeCode, date) {
    try {
        const result = await NAVManager.getNAV(schemeCode);
        const navData = result.data;

        // Find NAV for the specific date or closest previous date
        const [targetYear, targetMonth, targetDay] = date.split('-');
        const targetTimestamp = new Date(targetYear, targetMonth - 1, targetDay).getTime();

        let closestNAV = null;
        let closestTimestamp = null;

        for (const navRecord of navData) {
            const [d, m, y] = navRecord.date.split('-');
            const recordTimestamp = new Date(y, m - 1, d).getTime();

            if (recordTimestamp <= targetTimestamp) {
                if (closestTimestamp === null || recordTimestamp > closestTimestamp) {
                    closestTimestamp = recordTimestamp;
                    closestNAV = parseFloat(navRecord.nav);
                }
            }
        }

        if (closestNAV) return closestNAV;
        
        // If no record is found before the target date, it means the target date is before inception.
        // Return the first available NAV (oldest record) instead of the latest.
        const sorted = navData.sort((a, b) => {
            const [d1, m1, y1] = a.date.split('-');
            const [d2, m2, y2] = b.date.split('-');
            return new Date(y1, m1 - 1, d1) - new Date(y2, m2 - 1, d2);
        });
        return parseFloat(sorted[0].nav);
    } catch (error) {
        console.error('Error fetching historical NAV:', error);
        throw error;
    }
}

/**
 * Google Drive API Helpers
 */
async function fetchDriveAPI(url, options = {}) {
    if (!accessToken) throw new Error('Not authenticated');

    const headers = {
        'Authorization': `Bearer ${accessToken}`,
        ...(options.headers || {})
    };

    const fetchOptions = {
        cache: 'no-store',
        ...options,
        headers
    };

    const response = await fetch(url, fetchOptions);
    if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`Drive API error: ${response.status} ${errorText}`);
    }
    return response;
}

async function getDriveFileId(fileName) {
    const q = encodeURIComponent(`name='${fileName}' and 'appDataFolder' in parents and trashed=false`);
    const url = `https://www.googleapis.com/drive/v3/files?spaces=appDataFolder&q=${q}&fields=files(id)`;

    const response = await fetchDriveAPI(url);
    const data = await response.json();
    if (data.files && data.files.length > 0) return data.files[0].id;
    return null;
}

async function readDriveFile(fileId) {
    const url = `https://www.googleapis.com/drive/v3/files/${fileId}?alt=media`;
    const response = await fetchDriveAPI(url);
    return await response.json();
}

async function writeDriveFile(fileName, contentObj) {
    let fileId = await getDriveFileId(fileName);

    if (!fileId) {
        const createUrl = `https://www.googleapis.com/drive/v3/files`;
        const createResponse = await fetchDriveAPI(createUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name: fileName, parents: ['appDataFolder'] })
        });
        const createData = await createResponse.json();
        fileId = createData.id;
    }

    const fileContent = JSON.stringify(contentObj, null, 2);
    const url = `https://www.googleapis.com/upload/drive/v3/files/${fileId}?uploadType=media`;
    await fetchDriveAPI(url, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: fileContent
    });
}

// Cloud Synchronization Logic
async function getCloudInvestments() {
    try {
        const fileId = await getDriveFileId('mf_investments.json');
        if (fileId) {
            const content = await readDriveFile(fileId);
            return content.investments || [];
        }
    } catch (error) {
        console.error('Error getting investments from Drive:', error);
    }
    return [];
}

async function saveToCloud(investments) {
    try {
        await writeDriveFile('mf_investments.json', {
            investments: investments,
            lastSyncTime: new Date().toISOString()
        });
    } catch (error) {
        console.error('Failed to save to Google Drive:', error);
    }
}

async function getCloudFundGroups() {
    try {
        const fileId = await getDriveFileId('mf_groups.json');
        if (fileId) {
            const content = await readDriveFile(fileId);
            return content.fundGroups || [];
        }
    } catch (error) {
        console.error('Error getting fund groups from Drive:', error);
    }
    return [];
}

async function saveToCloudFundGroups(fundGroups) {
    try {
        await writeDriveFile('mf_groups.json', {
            fundGroups: fundGroups,
            lastSyncTime: new Date().toISOString()
        });
    } catch (error) {
        console.error('Failed to save fund groups to Google Drive:', error);
    }
}
/**
 * Search mutual funds from API or local cache
 */
async function searchMutualFunds(query) {
    if (allFundsCache) {
        return allFundsCache.filter(f => 
            f.schemeName.toLowerCase().includes(query.toLowerCase()) || 
            f.schemeCode.toString().includes(query)
        ).slice(0, 15);
    }
    
    const response = await fetch(`https://api.mfapi.in/mf/search?q=${encodeURIComponent(query)}`);
    const data = await response.json();
    return data.slice(0, 15);
}

// Ensure loadAllFundsCache is available
async function loadAllFundsCache() {
    if (allFundsCache || isFundsLoading) return;
    const CACHE_KEY = 'master_fund_list_cache';
    const CACHE_TTL = 7 * 24 * 60 * 60 * 1000;

    const cached = await getFromDB(CACHE_KEY);
    if (cached && (Date.now() - cached.timestamp < CACHE_TTL)) {
        allFundsCache = cached.data;
        return;
    }

    isFundsLoading = true;
    try {
        const response = await fetch('https://api.mfapi.in/mf');
        if (response.ok) {
            allFundsCache = await response.json();
            await saveToDB(CACHE_KEY, { data: allFundsCache, timestamp: Date.now() });
        }
    } catch (e) {
        console.warn('Master fund list fetch failed');
    } finally { isFundsLoading = false; }
}
