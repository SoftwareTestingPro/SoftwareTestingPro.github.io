/**
 * UI Rendering Module
 * Handles DOM manipulation, templates, and toast notifications
 */

/**
 * Format date to a readable string (e.g. 15 Apr 2026)
 */
function formatDate(dateString) {
    if (!dateString || dateString === 'N/A') return 'N/A';
    const date = new Date(dateString);
    if (isNaN(date)) return dateString;
    return date.toLocaleDateString('en-IN', {
        day: 'numeric',
        month: 'short',
        year: 'numeric'
    });
}

/**
 * Unified Card Template Generator
 * Handles both summary-card and minicard visuals
 */
function generateCardHTML(title, valueHTML, options = {}) {
    const {
        status = 'neutral', // 'positive', 'negative', 'neutral'
        id = '',
        valueId = '',
        extraClass = ''
    } = options;

    const statusClass = `status-${status}`;
    const borderClass = (status === 'positive' || status === 'neutral') ? 'border-positive' : (status === 'negative' ? 'border-negative' : '');

    return `
        <div class="minicard ${statusClass} ${borderClass} ${extraClass}" ${id ? `id="${id}"` : ''}>
            <div class="minicard-value" ${valueId ? `id="${valueId}"` : ''}>${valueHTML}</div>
            <div class="minicard-label">${title}</div>
        </div>
    `;
}



/**
 * Standardized Summary Card Template
 */
function getSummaryCardHTML(title, subLabel, percentage, amount, options = {}) {
    const { isNeutral = false, id = '', valueId = '', extraClass = '' } = options;
    const effectivePct = options.percentage !== undefined ? options.percentage : percentage;
    const isPositive = effectivePct >= 0 || (effectivePct === undefined && (amount >= 0 || amount === undefined));
    const status = isNeutral ? 'neutral' : (isPositive ? 'positive' : 'negative');

    let valueHTML = '';
    const displaySign = isPositive ? '+' : '-';
    const absAmt = amount !== undefined ? Math.abs(amount).toLocaleString(undefined, { maximumFractionDigits: 0 }) : '';
    const absPct = percentage !== undefined ? Math.abs(percentage).toFixed(2) : '';

    if (percentage !== undefined && amount !== undefined) {
        valueHTML = `${displaySign}${absPct}% (₹${displaySign}${absAmt})`;
    } else if (amount !== undefined) {
        valueHTML = `₹${absAmt}`;
    } else if (percentage !== undefined) {
        valueHTML = `${displaySign}${absPct}%`;
    }

    return generateCardHTML(title, valueHTML, { status, id, valueId, extraClass });
}



/**
 * Standardized Mini-Card Template (for Fund Details)
 */
function getMiniCardHTML(title, amount, options = {}) {
    const { percentage, themePercentage } = options;
    const statePct = themePercentage !== undefined ? themePercentage : (percentage !== undefined ? percentage : 0);
    const isPositive = statePct >= 0;
    const status = isPositive ? 'positive' : 'negative';
    const displaySign = isPositive ? '+' : '-';

    const absAmt = amount !== undefined ? Math.abs(amount).toLocaleString(undefined, { maximumFractionDigits: 0 }) : '';
    const absPct = percentage !== undefined ? Math.abs(percentage).toFixed(2) : '';

    let valueHTML = '';
    if (percentage !== undefined && amount !== undefined) {
        valueHTML = `${displaySign}${absPct}% (₹${displaySign}${absAmt})`;
    } else if (amount !== undefined) {
        valueHTML = `₹${absAmt}`;
    } else if (percentage !== undefined) {
        valueHTML = `${displaySign}${absPct}%`;
    }

    return generateCardHTML(title, valueHTML, { type: 'minicard', status });
}


// Global UI Helpers
function showLoading() { const el = document.getElementById('loadingSpinner'); if (el) el.style.display = 'block'; }
function hideLoading() { const el = document.getElementById('loadingSpinner'); if (el) el.style.display = 'none'; }

function showToast(message, type = 'info') {
    const toastContainer = document.getElementById('toastContainer');
    if (!toastContainer) return;
    const toastId = 'toast-' + Date.now();
    const toastHTML = `<div id="${toastId}" class="toast ${type}"><div class="toast-message">${message}</div></div>`;
    toastContainer.insertAdjacentHTML('beforeend', toastHTML);
    const toastElement = document.getElementById(toastId);
    requestAnimationFrame(() => toastElement.classList.add('show'));
    setTimeout(() => {
        if (toastElement) {
            toastElement.classList.remove('show');
            setTimeout(() => toastElement.remove(), 400);
        }
    }, 2000);
}

function showError(m) { showToast(m, 'error'); }
function showSuccess(m) { showToast(m, 'success'); }
function showInfo(m) { showToast(m, 'info'); }

async function showGlobalLoader(text = 'Loading...', subtext = '') {
    return new Promise(resolve => {
        const screen = document.getElementById('loadingScreen');
        const mainContainer = document.querySelector('.main-container');

        if (screen) {
            screen.querySelector('.loading-text').textContent = text;
            if (subtext) updateLoadingText(subtext);
            screen.style.display = 'flex';
        }

        if (mainContainer) {
            mainContainer.classList.add('blurred');
        }

        // Double requestAnimationFrame ensures the browser has rendered the state change
        requestAnimationFrame(() => requestAnimationFrame(resolve));
    });
}

function hideGlobalLoader() {
    const screen = document.getElementById('loadingScreen');
    const mainContainer = document.querySelector('.main-container');

    if (screen) {
        screen.style.display = 'none';
    }

    if (mainContainer) {
        mainContainer.classList.remove('blurred');
    }
}

function updateLoadingText(text) {
    const subtext = document.querySelector('.loading-subtext');
    if (subtext) {
        subtext.textContent = text;
    }
}

/**
 * Handle card expansion
 */
function togglePerformanceGrid(id) {
    const grid = document.getElementById(id);
    const trigger = event.currentTarget || document.querySelector(`[onclick*="${id}"]`);

    if (grid) grid.classList.toggle('collapsed');
    if (trigger) {
        trigger.classList.toggle('collapsed');
        const icon = trigger.querySelector('.expand-toggle-btn');
        if (icon) icon.classList.toggle('collapsed');
    }
}

/**
 * Render all individual fund cards
 */
async function displayFunds() {
    const container = document.getElementById('fundsContainer');
    if (userInvestments.length === 0) {
        container.innerHTML = `
            <div class="empty-state" style="width: 100%; text-align: center; padding: 40px; opacity: 0.6;">
                <i class="bi bi-inbox" style="font-size: 3rem; margin-bottom: 16px; display: block;"></i>
                <h4>No Funds Added Yet</h4>
                <p>Add your first investment above to start tracking performance.</p>
            </div>`;
        return;
    }

    showLoading();
    try {
        const sorted = [...userInvestments].sort((a, b) => new Date(b.investmentDate) - new Date(a.investmentDate));
        const fundsHTML = await Promise.all(sorted.map(async (investment) => {
            try {
                const navDataRes = await getCurrentNAV(investment.schemeCode);
                const currentNAV = navDataRes.nav;

                // Effective logic for pre-inception funds
                let effectiveUnits = investment.units;
                let effectiveNavStr = investment.nav;
                let effectiveDateStr = investment.investmentDate;

                try {
                    const history = await NAVManager.getNAV(investment.schemeCode);
                    if (history?.data?.length > 0) {
                        const sortedHistory = history.data.sort((a, b) => {
                            const [d1, m1, y1] = a.date.split('-');
                            const [d2, m2, y2] = b.date.split('-');
                            return new Date(y1, m1 - 1, d1) - new Date(y2, m2 - 1, d2);
                        });
                        const [fd, fm, fy] = sortedHistory[0].date.split('-');
                        const firstNavDate = new Date(fy, fm - 1, fd);
                        const invDate = new Date(investment.investmentDate);

                        if (invDate < firstNavDate) {
                            const inceptionNav = parseFloat(sortedHistory[0].nav);
                            effectiveUnits = investment.investmentAmount / inceptionNav;
                            effectiveNavStr = inceptionNav;
                            effectiveDateStr = sortedHistory[0].date.split('-').reverse().join('-');
                        }
                    }
                } catch (e) { }

                const currentValue = effectiveUnits * currentNAV;
                const returns = currentValue - investment.investmentAmount;
                const returnsPct = (returns / investment.investmentAmount) * 100;

                const cagr = await calculateFundCAGR(investment, currentNAV);
                const performance = await calculatePerformance(investment, currentNAV);

                const performanceItems = [];
                const labels = { daily: 'Yesterday', weekly: 'Last 7 Days', fifteenDays: 'Last 15 Days', monthly: 'Last 1 Month', quarterly: 'Last 3 Months', halfYearly: 'Last 6 Months', yearly: 'Last 1 Year' };

                if (performance?.periodic) {
                    Object.entries(labels).forEach(([key, label]) => {
                        const data = performance.periodic[key];
                        if (data) {
                            const startD = formatDate(data.startDate.split('-').reverse().join('-'));
                            const endD = formatDate(data.endDate.split('-').reverse().join('-'));
                            let finalLabel = label;
                            if (key === 'daily') {
                                const monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                const eParts = data.endDate.split('-');
                                finalLabel = `Last change(${eParts[0]} ${monthsShort[parseInt(eParts[1], 10) - 1]})`;
                            }
                            performanceItems.push({ label: finalLabel, subLabel: key === 'daily' ? `(${endD})` : `(Since ${startD})`, value: data.value, startNAV: data.startNAV, endNAV: data.endNAV });
                        }
                    });
                }

                if (performance?.yearlyBreakdown) {
                    const curYearStr = String(new Date().getFullYear());
                    Object.entries(performance.yearlyBreakdown).sort((a, b) => b[0] - a[0]).forEach(([year, data]) => {
                        const label = year === curYearStr ? 'Current Year' : year;
                        performanceItems.push({ label: label, subLabel: `(${formatDate(data.startDate)} - ${formatDate(data.endDate)})`, value: data.value, startNAV: data.startNAV, endNAV: data.endNAV });
                    });
                }

                const nameLower = investment.schemeName.toLowerCase();
                let planType = nameLower.includes('direct') ? 'Direct' : 'Regular';
                let planOption = 'Growth';
                if (nameLower.includes('idcw')) planOption = 'IDCW';
                else if (nameLower.includes('dividend')) planOption = 'Dividend';
                else if (nameLower.includes('payout')) planOption = 'Payout';

                const planInfo = `${planType} - ${planOption}`;
                const cleanTitle = investment.schemeName
                    .replace(/([-\s]+(Direct|Regular|Growth|IDCW|Dividend|Payout|Plan|Option))+.*/gi, '')
                    .trim();

                return `
                    <div class="playing-card ${returns >= 0 ? 'card-positive' : 'card-negative'}">
                        <div class="card-content">
                            <h5 class="card-title-v2" title="${investment.schemeName}">${cleanTitle}</h5>
                            <div class="card-meta-v2 text-muted-v2">
                                ${formatDate(investment.investmentDate)} • ${investment.units.toFixed(2)} Units • ${planInfo}
                            </div>
                            
                            <div class="card-stats-grid">
                                <div class="stat-box">
                                    <span class="stat-label">Invested</span>
                                    <span class="stat-value">₹${investment.investmentAmount.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                                </div>
                                <div class="stat-box">
                                    <span class="stat-label">Value</span>
                                    <span class="stat-value text-primary">₹${currentValue.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                                </div>
                            </div>
                            
                            <div class="card-main-stat">
                                <div class="profit-amount ${returns >= 0 ? 'text-success' : 'text-danger'}">
                                    ${returns >= 0 ? '+' : '-'}₹${Math.abs(returns).toLocaleString(undefined, { maximumFractionDigits: 0 })}
                                </div>
                                <div class="profit-badges">
                                    <span class="modern-badge-v2 ${returns >= 0 ? 'success' : 'danger'}">${returns >= 0 ? '+' : ''}${returnsPct.toFixed(2)}%</span>
                                    <span class="modern-badge-v2 info">XIRR ${cagr.toFixed(2)}%</span>
                                </div>
                            </div>
                            
                            <div class="card-periodic-list">
                                ${performanceItems.map(item => `
                                    <div class="periodic-row-v2">
                                        <span class="period-lbl">${item.label}</span>
                                        <span class="period-val ${item.value >= 0 ? 'pos' : 'neg'}">${item.value > 0 ? '+' : ''}${item.value.toFixed(2)}%</span>
                                    </div>
                                `).join('')}
                            </div>
                            
                            <div class="card-actions-v2">
                                <button class="btn-action-v2 view" onclick="editFund('${investment.id}')">Edit</button>
                                <button class="btn-action-v2 delete" onclick="removeFund('${investment.id}')">Delete</button>
                            </div>
                        </div>
                    </div>`;
            } catch (err) {
                return `<div class="fund-card"><h5>${investment.schemeName}</h5><div class="error-badge">Error: ${err.message}</div></div>`;
            }
        }));
        container.innerHTML = fundsHTML.join('');
    } finally {
        hideLoading();
    }
}

/**
 * Update global portfolio summary statistics
 */
let isSummaryUpdating = false;
async function updateSummary() {
    if (isSummaryUpdating) return;
    isSummaryUpdating = true;

    try {
        let totalInv = 0, totalVal = 0, totalYTDStart = 0, flows = [];
        const curYear = new Date().getFullYear();
        const jan1 = new Date(curYear, 0, 1);

        const navResults = await Promise.all(userInvestments.map(async (inv) => {
            try {
                const navData = await getCurrentNAV(inv.schemeCode);
                return { id: inv.id, nav: navData.nav, date: navData.date };
            } catch (err) { return { id: inv.id, nav: 0, date: 'N/A' }; }
        }));

        for (const inv of userInvestments) {
            const res = navResults.find(r => String(r.id) === String(inv.id));
            const cNav = res ? res.nav : 0;

            let effectiveUnits = inv.units;
            let historyData = null;
            try {
                const history = await NAVManager.getNAV(inv.schemeCode);
                historyData = history?.data || [];
                if (historyData.length > 0) {
                    const sorted = [...historyData].sort((a, b) => {
                        const [d1, m1, y1] = a.date.split('-');
                        const [d2, m2, y2] = b.date.split('-');
                        return new Date(y1, m1 - 1, d1) - new Date(y2, m2 - 1, d2);
                    });
                    const [fd, fm, fy] = sorted[0].date.split('-');
                    const firstDate = new Date(fy, fm - 1, fd);
                    if (new Date(inv.investmentDate) < firstDate) {
                        effectiveUnits = inv.investmentAmount / parseFloat(sorted[0].nav);
                    }
                }
            } catch (e) { }

            totalInv += inv.investmentAmount;
            totalVal += effectiveUnits * cNav;

            // Global YTD Calculation - Ensures Parity
            const invDate = new Date(inv.investmentDate);
            if (invDate >= jan1) {
                totalYTDStart += inv.investmentAmount;
            } else if (historyData) {
                // Find NAV on or before Jan 1
                let jan1Nav = 0;
                const sorted = [...historyData].sort((a, b) => {
                    const [d1, m1, y1] = a.date.split('-');
                    const [d2, m2, y2] = b.date.split('-');
                    return new Date(y1, m1 - 1, d1) - new Date(y2, m2 - 1, d2);
                });
                for (const h of sorted) {
                    const [d, m, y] = h.date.split('-');
                    if (new Date(y, m - 1, d) <= jan1) jan1Nav = parseFloat(h.nav);
                }
                if (jan1Nav === 0 && sorted.length > 0) jan1Nav = parseFloat(sorted[0].nav);
                totalYTDStart += jan1Nav * effectiveUnits;
            } else {
                totalYTDStart += inv.investmentAmount;
            }

            const [y, m, d] = inv.investmentDate.split('-');
            flows.push({ date: new Date(y, m - 1, d), amount: -inv.investmentAmount });
        }

        const profit = totalVal - totalInv;
        const profitPct = totalInv > 0 ? (profit / totalInv) * 100 : 0;
        const xirr = calculatePortfolioXIRR(flows, totalVal);

        // Contextual Dates
        const latestNAVDateRaw = navResults.reduce((latest, res) => {
            if (!res.date || res.date === 'N/A') return latest;
            const [d, m, y] = res.date.split('-');
            const current = `${y}-${m}-${d}`;
            return (latest === 'N/A' || current > latest) ? current : latest;
        }, 'N/A');
        const numDate = latestNAVDateRaw !== 'N/A' ? latestNAVDateRaw.split('-').reverse().join('-') : 'N/A';

        // Periodic Portfolio Performance
        const results = await Promise.all(userInvestments.map(async (inv) => {
            const navRes = navResults.find(r => String(r.id) === String(inv.id));
            if (navRes && navRes.nav > 0) {
                let eUnits = inv.units;
                try {
                    const history = await NAVManager.getNAV(inv.schemeCode);
                    if (history?.data?.length > 0) {
                        const sorted = history.data.sort((a, b) => {
                            const [d1, m1, y1] = a.date.split('-');
                            const [d2, m2, y2] = b.date.split('-');
                            return new Date(y1, m1 - 1, d1) - new Date(y2, m2 - 1, d2);
                        });
                        const [fd, fm, fy] = sorted[0].date.split('-');
                        const fDate = new Date(fy, fm - 1, fd);
                        if (new Date(inv.investmentDate) < fDate) {
                            eUnits = inv.investmentAmount / parseFloat(sorted[0].nav);
                        }
                    }
                } catch (e) { }

                return { inv, eUnits, val: eUnits * navRes.nav, data: await calculatePerformance(inv, navRes.nav) };
            }
            return null;
        }));

        // Find absolute latest NAV date across all results
        let globalLatestDate = null;
        let globalLatestDateStr = 'N/A';
        results.forEach(res => {
            if (res?.data?.periodic?.daily?.endDate) {
                const [d, m, y] = res.data.periodic.daily.endDate.split('-');
                const dt = new Date(y, m - 1, d);
                if (!globalLatestDate || dt > globalLatestDate) {
                    globalLatestDate = dt;
                    globalLatestDateStr = res.data.periodic.daily.endDate;
                }
            }
        });

        const monthsS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        let lastChangeLabel = 'N/A';
        if (globalLatestDateStr !== 'N/A') {
            const parts = globalLatestDateStr.split('-');
            lastChangeLabel = `${parts[0]} ${monthsS[parseInt(parts[1], 10) - 1]}`;
        }

        const periods = [
            { key: 'daily', id: `Last change(${lastChangeLabel})` },
            { key: 'weekly', id: 'Last 7 Days' },
            { key: 'fifteenDays', id: 'Last 15 Days' },
            { key: 'monthly', id: 'Last 1 Month' },
            { key: 'quarterly', id: 'Last 3 Months' },
            { key: 'halfYearly', id: 'Last 6 Months' },
            { key: 'yearly', id: 'Last 1 Year' }
        ];

        const generatedPills = [];
        periods.forEach(p => {
            let totalDiff = 0, totalStartVal = 0;
            results.forEach(res => {
                const item = res?.data?.periodic?.[p.key];
                if (item) {
                    totalDiff += (item.endNAV - item.startNAV) * res.eUnits;
                    totalStartVal += item.startNAV * res.eUnits;
                }
            });

            if (totalStartVal > 0) {
                const weightedPct = (totalDiff / totalStartVal) * 100;
                generatedPills.push(`
                    <div class="periodic-row-v2">
                        <span class="period-lbl">${p.id}</span>
                        <span class="period-val ${weightedPct >= 0 ? 'pos' : 'neg'}">${weightedPct > 0 ? '+' : ''}${weightedPct.toFixed(2)}%</span>
                    </div>
                `);
            }
        });

        // Unified Yearly Breakdown (Current Year handled separately for 100% parity)
        const yearlyData = {};
        results.forEach(res => {
            if (res?.data?.yearlyBreakdown) {
                Object.entries(res.data.yearlyBreakdown).forEach(([year, data]) => {
                    if (year === String(curYear)) return; // Skip current year, we have it already
                    if (!yearlyData[year]) yearlyData[year] = { totalDiff: 0, totalStartVal: 0 };
                    yearlyData[year].totalDiff += (data.endNAV - data.startNAV) * res.eUnits;
                    yearlyData[year].totalStartVal += data.startNAV * res.eUnits;
                });
            }
        });

        // Add Current Year separately using global logic
        const ytdReturnPct = totalYTDStart > 0 ? ((totalVal - totalYTDStart) / totalYTDStart) * 100 : 0;
        generatedPills.push(`
            <div class="periodic-row-v2">
                <span class="period-lbl">Current Year</span>
                <span class="period-val ${ytdReturnPct >= 0 ? 'pos' : 'neg'}">${ytdReturnPct > 0 ? '+' : ''}${ytdReturnPct.toFixed(2)}%</span>
            </div>
        `);

        Object.keys(yearlyData).sort((a, b) => b - a).forEach(year => {
            const data = yearlyData[year];
            if (data.totalStartVal > 0) {
                const weightedPct = (data.totalDiff / data.totalStartVal) * 100;
                generatedPills.push(`
                    <div class="periodic-row-v2">
                        <span class="period-lbl">${year}</span>
                        <span class="period-val ${weightedPct >= 0 ? 'pos' : 'neg'}">${weightedPct > 0 ? '+' : ''}${weightedPct.toFixed(2)}%</span>
                    </div>
                `);
            }
        });

        const oldestDate = userInvestments.reduce((min, inv) => {
            const d = new Date(inv.investmentDate);
            return d < min ? d : min;
        }, new Date());
        const monthsL = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        const oldestDateStr = `${oldestDate.getDate()} ${monthsL[oldestDate.getMonth()]} ${oldestDate.getFullYear()}`;

        const uniqueFundCount = new Set(userInvestments.map(i => i.schemeCode)).size;

        const summaryHTML = `
            <div class="playing-card ${profit >= 0 ? 'card-positive' : 'card-negative'}" style="width: 280px; margin: 0;">
                <div class="card-content">
                    <h5 class="card-title-v2" title="Portfolio Summary">Portfolio Summary</h5>
                    <div class="card-meta-v2 text-muted-v2" style="white-space: normal; height: auto;">
                        Investment Since: ${oldestDateStr} • ${uniqueFundCount} Funds
                    </div>
                    
                    <div class="card-stats-grid">
                        <div class="stat-box">
                            <span class="stat-label">Invested</span>
                            <span class="stat-value">₹${totalInv.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                        </div>
                        <div class="stat-box">
                            <span class="stat-label">Value</span>
                            <span class="stat-value text-primary">₹${totalVal.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                        </div>
                    </div>
                    
                    <div class="card-main-stat">
                        <div class="profit-amount ${profit >= 0 ? 'text-success' : 'text-danger'}">
                            ${profit >= 0 ? '+' : '-'}₹${Math.abs(profit).toLocaleString(undefined, { maximumFractionDigits: 0 })}
                        </div>
                        <div class="profit-badges">
                            <span class="modern-badge-v2 ${profit >= 0 ? 'success' : 'danger'}">${profit >= 0 ? '+' : ''}${profitPct.toFixed(2)}%</span>
                            <span class="modern-badge-v2 info">XIRR ${xirr.toFixed(2)}%</span>
                        </div>
                    </div>
                    
                    <div class="card-periodic-list">
                        ${generatedPills.join('')}
                    </div>
                </div>
            </div>`;


        const summaryContainer = document.getElementById('summaryStatsContainer');
        if (summaryContainer) {
            summaryContainer.innerHTML = summaryHTML;
        }
    } finally {
        isSummaryUpdating = false;
    }
}

/**
 * Render groups view
 */
async function displayGroups() {
    const container = document.getElementById('groupsContainer');
    if (fundGroups.length === 0) {
        container.innerHTML = '';
        return;
    }

    try {
        showLoading();
        let filteredGroups = [...fundGroups].sort((a, b) => a.name.localeCompare(b.name));


        const groupsHTML = await Promise.all(filteredGroups.map(async (group) => {
            const stats = await calculateGroupStats(group.fundIds);
            const displayName = group.name.charAt(0).toUpperCase() + group.name.slice(1);

            // Aggregate funds by schemeCode for the group view
            const aggregatedFunds = {};
            group.fundIds.forEach(fundId => {
                const investment = userInvestments.find(inv => String(inv.id) === String(fundId));
                if (investment) {
                    if (!aggregatedFunds[investment.schemeCode]) {
                        aggregatedFunds[investment.schemeCode] = {
                            schemeCode: investment.schemeCode, schemeName: investment.schemeName,
                            investmentAmount: 0, units: 0, count: 0, ids: []
                        };
                    }
                    aggregatedFunds[investment.schemeCode].investmentAmount += investment.investmentAmount;
                    aggregatedFunds[investment.schemeCode].units += investment.units;
                    aggregatedFunds[investment.schemeCode].count++;
                    aggregatedFunds[investment.schemeCode].ids.push(investment.id);
                }
            });

            const groupFundsHTML = await Promise.all(Object.values(aggregatedFunds).map(async (agg) => {
                try {
                    const navData = await getCurrentNAV(agg.schemeCode);
                    const fundStats = await calculateGroupStats(agg.ids);
                    const returns = fundStats.totalReturns;
                    const returnsPct = fundStats.totalInvestment > 0 ? (returns / fundStats.totalInvestment * 100) : 0;

                    const nameLower = agg.schemeName.toLowerCase();
                    let pType = nameLower.includes('direct') ? 'Direct' : 'Regular';
                    let pOption = 'Growth';
                    if (nameLower.includes('idcw')) pOption = 'IDCW';
                    else if (nameLower.includes('dividend')) pOption = 'Dividend';
                    else if (nameLower.includes('payout')) pOption = 'Payout';

                    const cleanT = agg.schemeName
                        .replace(/([-\s]+(Direct|Regular|Growth|IDCW|Dividend|Payout|Plan|Option))+.*/gi, '')
                        .trim();

                    return `
                        <div class="group-fund-mini" style="margin-bottom: 8px; padding-bottom: 8px; border-bottom: 1px solid rgba(255,255,255,0.05);">
                            <div style="font-size: 0.8rem; font-weight: 600; text-overflow: ellipsis; overflow: hidden; white-space: nowrap;" title="${agg.schemeName}">${cleanT}</div>
                            <div style="display: flex; justify-content: space-between; font-size: 0.72rem; margin-top: 2px;">
                                <span class="text-muted-v2">${agg.units.toFixed(2)} Units • ${pType} - ${pOption}</span>
                                <span class="${returns >= 0 ? 'text-success' : 'text-danger'}">${returns >= 0 ? '+' : ''}${returnsPct.toFixed(2)}%</span>
                            </div>
                        </div>`;
                } catch (e) { return `<div class="group-fund-mini text-muted-v2" style="font-size: 0.8rem;">Data unavailable</div>`; }
            }));

            const pctReturns = stats.totalInvestment > 0 ? (stats.totalReturns / stats.totalInvestment * 100) : 0;
            return `
                <div class="playing-card ${stats.totalReturns >= 0 ? 'card-positive' : 'card-negative'}">
                    <div class="card-content">
                        <h5 class="card-title-v2" title="${displayName}">${displayName}</h5>
                        <div class="card-meta-v2 text-muted-v2">
                            ${Object.keys(aggregatedFunds).length} Funds • ${group.isAutomated ? 'Auto' : 'Custom'}
                        </div>
                        
                        <div class="card-stats-grid">
                            <div class="stat-box">
                                <span class="stat-label">Invested</span>
                                <span class="stat-value">₹${stats.totalInvestment.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                            </div>
                            <div class="stat-box">
                                <span class="stat-label">Value</span>
                                <span class="stat-value text-primary">₹${stats.currentValue.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                            </div>
                        </div>
                        
                        <div class="card-main-stat">
                            <div class="profit-amount ${stats.totalReturns >= 0 ? 'text-success' : 'text-danger'}">
                                ${stats.totalReturns >= 0 ? '+' : '-'}₹${Math.abs(stats.totalReturns).toLocaleString(undefined, { maximumFractionDigits: 0 })}
                            </div>
                            <div class="profit-badges">
                                <span class="modern-badge-v2 ${stats.totalReturns >= 0 ? 'success' : 'danger'}">${stats.totalReturns >= 0 ? '+' : ''}${pctReturns.toFixed(2)}%</span>
                                <span class="modern-badge-v2 info">XIRR ${stats.cagr.toFixed(2)}%</span>
                            </div>
                        </div>
                        
                        <div class="card-periodic-list">
                            ${Object.values(stats.periodicReturns).map(p => {
                let fLabel = p.label;
                if (p.label === 'Yesterday') {
                    const monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                    const dateSrc = p.endDate || stats.latestNAVDate;
                    if (dateSrc) {
                        const eParts = dateSrc.split('-');
                        fLabel = `Last change(${eParts[0]} ${monthsShort[parseInt(eParts[1], 10) - 1]})`;
                    }
                }
                return `
                                <div class="periodic-row-v2">
                                    <span class="period-lbl">${fLabel}</span>
                                    <span class="period-val ${p.percentage >= 0 ? 'pos' : 'neg'}">${p.percentage > 0 ? '+' : ''}${p.percentage.toFixed(2)}%</span>
                                </div>`;
            }).join('')}
                        </div>
                        
                        <div class="card-actions-v2">
                            ${!group.isAutomated ? `
                                <button class="btn-action-v2" onclick="editGroupModal('${group.id}')"><i class="bi bi-pencil"></i></button>
                                <button class="btn-action-v2 delete" onclick="deleteGroup('${group.id}')"><i class="bi bi-trash"></i></button>
                            ` : ''}
                            <button class="btn-action-v2 view" onclick="togglePerformanceGrid('funds-${group.id}')"><i class="bi bi-collection"></i> Funds</button>
                        </div>
                        
                        <div class="group-funds collapsed mt-3" id="funds-${group.id}" style="text-align: left; background: rgba(0,0,0,0.2); border-radius: 8px; padding: 10px; max-height: 180px; overflow-y: auto;">
                            ${groupFundsHTML.join('')}
                        </div>
                    </div>
                </div>`;
        }));
        container.innerHTML = groupsHTML.join('');
    } finally {
        hideLoading();
    }
}

/**
 * Dynamically generate group filter buttons
 */
function updateGroupFilterUI() {
    const filterRow = document.querySelector('.group-filter-row');
    if (!filterRow) return;

    const filters = [
        { id: 'all', label: 'All' },
        { id: 'asset', label: 'Asset Class' },
        { id: 'cap', label: 'Market Cap' },
        { id: 'sector', label: 'Sectoral' },
        { id: 'strategy', label: 'Mandate / Strategy' },
        { id: 'house', label: 'AMC House' },
        { id: 'direct', label: 'Direct' },
        { id: 'regular', label: 'Regular' },
        { id: 'custom', label: 'Custom' }
    ];

    let html = '';
    filters.forEach(f => {
        const hasMatch = f.id === 'all' || fundGroups.some(g => g.autoType === f.id || (f.id === 'custom' && !g.isAutomated));
        if (hasMatch) {
            html += `
                <button class="group-filter-btn ${currentGroupFilter === f.id ? 'active' : ''}" 
                        onclick="switchGroupFilter('${f.id}')">
                    ${f.label}
                </button>
            `;
        }
    });

    // Add Group button
    html += `
        <button class="group-filter-btn btn-add-group" onclick="openCreateGroupModal()">
            <i class="bi bi-plus-circle"></i> Add Group
        </button>
    `;

    filterRow.innerHTML = html;
}
/**
 * Render research view with best/worst performers
 */
async function displayResearch() {
    const container = document.getElementById('researchContainer');
    if (!container) return;

    if (userInvestments.length === 0) {
        container.innerHTML = `<div class="empty-state" style="width: 100%; text-align: center; padding: 40px; opacity: 0.6;">
            <i class="bi bi-search" style="font-size: 3rem; margin-bottom: 16px; display: block;"></i>
            <h4>No Data for Research</h4>
            <p>Add some funds first to see performance insights.</p>
        </div>`;
        return;
    }

    showLoading();
    try {
        // Aggregate multi-SIP investments into unique funds for research
        const uniqueFundsMap = {};
        userInvestments.forEach(inv => {
            if (!uniqueFundsMap[inv.schemeCode]) {
                uniqueFundsMap[inv.schemeCode] = {
                    schemeCode: inv.schemeCode,
                    schemeName: inv.schemeName,
                    totalInv: 0,
                    totalUnits: 0,
                    ids: []
                };
            }
            uniqueFundsMap[inv.schemeCode].totalInv += inv.investmentAmount;
            uniqueFundsMap[inv.schemeCode].totalUnits += inv.units;
            uniqueFundsMap[inv.schemeCode].ids.push(inv.id);
        });

        const fundStats = await Promise.all(Object.values(uniqueFundsMap).map(async f => {
            const navRes = await getCurrentNAV(f.schemeCode);
            const stats = await calculateGroupStats(f.ids);
            return {
                ...f,
                currentNav: navRes.nav,
                absoluteReturns: stats.totalReturns,
                returnsPct: stats.totalInvestment > 0 ? (stats.totalReturns / stats.totalInvestment * 100) : 0,
                perf6M: stats.periodicReturns.halfYearly?.percentage ?? null,
                stats: stats
            };
        }));

        // 4. Advanced Analytics (Last 1 Year)
        const oneYearAgo = new Date();
        oneYearAgo.setFullYear(oneYearAgo.getFullYear() - 1);

        const advancedStats = await Promise.all(fundStats.map(async f => {
            let histData = [];
            try {
                const historyRes = await NAVManager.getNAV(f.schemeCode);
                histData = historyRes?.data || [];
            } catch (e) { console.error('History fetch failed', e); }

            if (histData.length < 2) return { ...f, maxDrawdown: 0, maxSwing: 0 };

            // Filter history for last 1 year
            const recentHist = histData.filter(h => {
                const [d, m, y] = h.date.split('-');
                return new Date(y, m - 1, d) >= oneYearAgo;
            }).sort((a, b) => {
                const [d1, m1, y1] = a.date.split('-');
                const [d2, m2, y2] = b.date.split('-');
                return new Date(y1, m1 - 1, d1) - new Date(y2, m2 - 1, d2);
            });

            if (recentHist.length === 0) return { ...f, maxDrawdown: 0, maxSwing: 0 };

            let peak = -Infinity;
            let trough = Infinity;
            let maxDD = 0;
            let maxUp = 0;

            recentHist.forEach(h => {
                const val = parseFloat(h.nav);
                if (isNaN(val)) return;

                if (val > peak) {
                    peak = val;
                } else {
                    const dd = ((peak - val) / peak) * 100;
                    if (dd > maxDD) maxDD = dd;
                }

                if (val < trough) {
                    trough = val;
                } else {
                    const up = ((val - trough) / trough) * 100;
                    if (up > maxUp) maxUp = up;
                }
            });

            return { ...f, maxDrawdown: maxDD, maxSwing: maxUp };
        }));

        // Best Defender (Lowest Drawdown in bear phase)
        // We pick the fund with the absolute lowest drawdown, even if it's 0 (best possible resilience)
        const bestDefender = [...advancedStats].sort((a, b) => a.maxDrawdown - b.maxDrawdown)[0];

        // Best Climber (Highest Up-swing in bull phase)
        const bestClimber = [...advancedStats].sort((a, b) => b.maxSwing - a.maxSwing)[0];

        // Top Performer (Highest XIRR/CAGR)
        const bestOverall = [...advancedStats].sort((a, b) => (b.stats.cagr || 0) - (a.stats.cagr || 0))[0];

        // Underperformer (Lowest XIRR/CAGR)
        const worstOverall = [...advancedStats].sort((a, b) => (a.stats.cagr || 0) - (b.stats.cagr || 0))[0];

        // Worst in last 6 months (Filter out nulls, then pick lowest)
        const worst6M = advancedStats
            .filter(f => f.perf6M !== null)
            .sort((a, b) => (a.perf6M || 0) - (b.perf6M || 0))[0];

        let html = `<div style="width: 100%; margin-bottom: 20px; padding: 0 10px;">
            <h3 style="margin-bottom: 4px;">Portfolio Insights</h3>
            <p style="color: var(--text-secondary); font-size: 0.9rem;">Advanced performance analysis based on historical cycles</p>
        </div>`;

        const createInsightCard = (fund, title, sub, variant, extraVal = null) => {
            if (!fund) return '';

            // Default to overall stats
            let mainAmount = (fund.absoluteReturns) || 0;
            let mainPct = (fund.returnsPct) || 0;
            let maxXirr = (fund.stats?.cagr) || 0;

            // Context Logic: For 6-month warnings, show the 6-month delta specifically
            if (variant === 'worst6M') {
                const p6M = fund.stats.periodicReturns?.halfYearly;
                if (p6M) {
                    mainAmount = p6M.absolute || 0;
                    mainPct = p6M.percentage || 0;
                    // Annualize the 6-month return for the XIRR badge: ((1 + r)^2 - 1)
                    maxXirr = (Math.pow(1 + (mainPct / 100), 2) - 1) * 100;
                }
            }

            const isPos = mainPct >= 0;
            const cleanTitle = fund.schemeName.replace(/([-\s]+(Direct|Regular|Growth|IDCW|Dividend|Payout|Plan|Option))+.*/gi, '').trim();
            const badgeClass = variant === 'best' ? 'success' : (variant === 'worst' || variant === 'worst6M' || variant === 'under' ? 'danger' : 'info');
            const icon = variant === 'best' ? 'bi-trophy-fill' : (variant === 'bestDefender' ? 'bi-shield-check' : (variant === 'bestClimber' ? 'bi-graph-up-arrow' : 'bi-exclamation-triangle-fill'));

            // High-precision currency: Show decimals if the amount is less than 1 or 2, to avoid "0"
            const formattedAmount = Math.abs(mainAmount) < 2 && Math.abs(mainAmount) > 0
                ? Math.abs(mainAmount).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })
                : Math.abs(mainAmount).toLocaleString(undefined, { maximumFractionDigits: 0 });

            return `
                <div class="playing-card ${variant === 'best' ? 'card-positive' : (variant === 'worst6M' || variant === 'under' ? 'card-negative' : 'card-info')}">
                    <div class="card-content">
                        <div style="margin-bottom: 15px;">
                            <span class="modern-badge-v2 ${badgeClass}" style="font-size: 0.7rem; letter-spacing: 1px;">
                                <i class="bi ${icon}"></i> ${title}
                            </span>
                        </div>
                        <h4 class="card-title-v2" style="font-size: 1.1rem; min-height: 2.4em;">${cleanTitle}</h4>
                        <p style="font-size: 0.8rem; color: var(--text-secondary); margin-bottom: 20px;">${sub}</p>
                        
                        <div class="card-main-stat">
                            <div class="profit-amount ${isPos ? 'text-success' : 'text-danger'}" style="font-size: 2rem;">
                                ${isPos ? '+' : '-'}₹${formattedAmount}
                            </div>
                            <div class="profit-badges">
                                <span class="modern-badge-v2 ${isPos ? 'success' : 'danger'}">${isPos ? '+' : ''}${Number(mainPct || 0).toFixed(2)}%</span>
                                <span class="modern-badge-v2 ${maxXirr >= 0 ? 'success' : 'danger'}">XIRR ${Number(maxXirr || 0).toFixed(2)}%</span>
                            </div>
                        </div>

                        </div>
                    </div>
                </div>
            `;
        };

        html += createInsightCard(bestOverall, 'TOP PERFORMER', 'Demonstrated the highest compounded growth efficiency (XIRR), making it the strongest wealth generator in your portfolio.', 'best');
        html += createInsightCard(worstOverall, 'UNDERPERFORMER', 'Identified as having the lowest annualized returns (XIRR) across your entire asset list since the investment date.', 'under');

        if (worst6M && worst6M.perf6M < 0) {
            html += createInsightCard(worst6M, '6-MONTH WARNING', 'Recorded the most significant relative decline in value within your portfolio over the last 180-day tracking window.', 'worst6M', { label: 'DROPPED BY', value: Math.abs(worst6M.perf6M).toFixed(2) });
        } else if (worst6M) {
            // If even the "worst" is positive, show it as Moderate growth or hide
            html += createInsightCard(worst6M, 'STABLE ASSET', 'Maintained the most resilient and conservative performance profile in your portfolio during the last 6-month period.', 'info', { label: '6M YIELD', value: worst6M.perf6M.toFixed(2) });
        }

        container.innerHTML = html;
    } finally {
        hideLoading();
    }
}

/**
 * Market Discovery Logic - Sector Scanning
 */
/**
 * Market Discovery Logic - Sector Scanning
 */
async function runDiscovery() {
    const sector = document.getElementById('discoverySector').value;
    const resultsContainer = document.getElementById('discoveryResults');
    const progressBlock = document.getElementById('scanProgress');
    const progressBar = document.getElementById('scanProgressBar');
    const scanStatus = document.getElementById('scanStatus');
    const scanPercentage = document.getElementById('scanPercentage');

    if (!allFundsCache) {
        showError('Fund database not loaded. Please wait or refresh.');
        return;
    }

    // 1. Filter candidates (Direct + Growth + Sector) and Deduplicate
    const rawCandidates = allFundsCache.filter(f =>
        f.schemeName.includes('Direct') &&
        f.schemeName.includes('Growth') &&
        f.schemeName.toLowerCase().includes(sector.toLowerCase())
    );

    // Deduplicate by normalized name
    const seenNames = new Set();
    const candidates = [];
    for (const f of rawCandidates) {
        const clean = f.schemeName.replace(/([-\s]+(Direct|Regular|Growth|IDCW|Dividend|Payout|Plan|Option))+.*/gi, '').trim();
        if (!seenNames.has(clean)) {
            seenNames.add(clean);
            candidates.push(f);
        }
        if (candidates.length >= 40) break; // Keep safety limit
    }

    if (candidates.length === 0) {
        resultsContainer.innerHTML = `<div style="text-align: center; width: 100%; opacity: 0.6;">No direct growth funds found for "${sector}"</div>`;
        return;
    }
    resultsContainer.innerHTML = '';
    progressBlock.style.display = 'block';

    let processed = 0;
    const discoveryStats = [];

    for (let i = 0; i < candidates.length; i++) {
        const fund = candidates[i];
        processed++;
        const pct = Math.round((processed / candidates.length) * 100);
        scanPercentage.textContent = `${pct}%`;
        progressBar.style.width = `${pct}%`;
        scanStatus.textContent = `Analyzing ${fund.schemeName.split(' - ')[0]}...`;

        try {
            const history = await NAVManager.getNAV(fund.schemeCode);
            if (!history || !history.data || history.data.length < 10) continue;

            const sorted = history.data.sort((a, b) => {
                const [d1, m1, y1] = a.date.split('-');
                const [d2, m2, y2] = b.date.split('-');
                return new Date(y1, m1 - 1, d1) - new Date(y2, m2 - 1, d2);
            });

            const scanHorizons = [
                { key: '1Y', months: 12 },
                { key: '6M', months: 6 },
                { key: '3M', months: 3 },
                { key: '1M', months: 1 }
            ];

            const fundMetrics = {};

            scanHorizons.forEach(h => {
                const cutoff = new Date();
                cutoff.setMonth(cutoff.getMonth() - h.months);

                const recent = sorted.filter(row => {
                    const [rd, rm, ry] = row.date.split('-');
                    return new Date(ry, rm - 1, rd) >= cutoff;
                });

                if (recent.length >= 5) {
                    let rises = 0, falls = 0;
                    for (let n = 1; n < recent.length; n++) {
                        const prevVal = parseFloat(recent[n - 1].nav);
                        const currVal = parseFloat(recent[n].nav);
                        if (currVal > prevVal) rises++;
                        else if (currVal < prevVal) falls++;
                    }
                    const strikeRate = (rises / (rises + falls)) * 100;
                    const cVal = parseFloat(recent[recent.length - 1].nav);
                    const sVal = parseFloat(recent[0].nav);
                    const growth = ((cVal - sVal) / sVal) * 100;

                    fundMetrics[h.key] = { rises, falls, strikeRate, growth, currentNAV: cVal };
                }
            });

            if (Object.keys(fundMetrics).length > 0) {
                discoveryStats.push({ ...fund, metrics: fundMetrics });
            }
        } catch (e) { console.error('Scan failed for', fund.schemeCode); }
    }

    progressBlock.style.display = 'none';

    if (discoveryStats.length === 0) {
        resultsContainer.innerHTML = `<div style="text-align: center; width: 100%; opacity: 0.6;">Insufficient data found for funds in this sector.</div>`;
        return;
    }

    // 3. Find Winners & Generate HTML
    let finalHtml = '';
    const displayHorizons = ['1Y', '6M', '3M', '1M'];
    const timeLabels = { '1Y': '1 Year', '6M': '6 Months', '3M': '3 Months', '1M': '1 Month' };

    const categories = [
        { key: 'stability', title: 'Consistency King', sub: 'Best strike rate (Rises vs Falls)' },
        { key: 'growth', title: 'Sector Alpha', sub: 'Highest absolute growth' }
    ];

    categories.forEach(cat => {
        // Find Category Winner (Highest Average across all horizons)
        const catStats = discoveryStats.map(f => {
            const mValues = Object.values(f.metrics);
            const avg = mValues.reduce((acc, m) => acc + (cat.key === 'stability' ? m.strikeRate : m.growth), 0) / mValues.length;
            return { ...f, catAvg: avg };
        }).sort((a, b) => b.catAvg - a.catAvg);

        const catWinner = catStats[0];
        const cleanWinnerName = catWinner.schemeName.replace(/([-\s]+(Direct|Regular|Growth|IDCW|Dividend|Payout|Plan|Option))+.*/gi, '').trim();

        finalHtml += `
            <div style="width: 100%; margin-top: 30px; margin-bottom: 25px; padding: 0 10px;">
                <div style="display: flex; justify-content: space-between; align-items: flex-end; border-bottom: 2px solid rgba(255,255,255,0.05); padding-bottom: 12px; margin-bottom: 20px;">
                    <div>
                        <h4 style="margin: 0; display: flex; align-items: center; gap: 10px; color: ${cat.key === 'stability' ? 'var(--success-color)' : 'var(--brand-primary)'};">
                            <i class="bi ${cat.key === 'stability' ? 'bi-shield-check' : 'bi-rocket-takeoff'}"></i> ${cat.title}
                        </h4>
                        <p style="color: var(--text-secondary); margin: 4px 0 0; font-size: 0.85rem;">${cat.sub}</p>
                    </div>
                </div>

                <!-- Category Champion Banner -->
                <div style="background: linear-gradient(90deg, rgba(30, 41, 59, 0.6) 0%, rgba(15, 23, 42, 0.8) 100%); border-radius: 16px; border-left: 4px solid ${cat.key === 'stability' ? 'var(--success-color)' : 'var(--brand-primary)'}; padding: 15px 20px; display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px; gap: 20px; flex-wrap: wrap;">
                    <div style="display: flex; align-items: center; gap: 15px;">
                        <div style="width: 45px; height: 45px; background: ${cat.key === 'stability' ? 'var(--success-color)' : 'var(--brand-primary)'}; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 1.4rem; color: white;">
                            <i class="bi bi-award"></i>
                        </div>
                        <div>
                            <div style="font-size: 0.7rem; font-weight: 700; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 1px;">Category AI Pick</div>
                            <div style="font-size: 1.1rem; font-weight: 700; color: white;">${cleanWinnerName}</div>
                        </div>
                    </div>
                    <div style="display: flex; gap: 24px;">
                        <div style="text-align: right;">
                            <div style="font-size: 0.65rem; color: var(--text-secondary); text-transform: uppercase;">Overall Score</div>
                            <div style="font-size: 1.2rem; font-weight: 800; color: white;">${catWinner.catAvg.toFixed(1)}${cat.key === 'stability' ? '%' : '%'}</div>
                        </div>
                    </div>
                </div>

                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 20px; width: 100%;">
        `;

        displayHorizons.forEach(h => {
            const statsForPeriod = discoveryStats.filter(f => f.metrics[h]);
            if (statsForPeriod.length === 0) return;

            // Pick Top 10 for this category and horizon
            const ranked = [...statsForPeriod].sort((a, b) => {
                if (cat.key === 'stability') return b.metrics[h].strikeRate - a.metrics[h].strikeRate;
                return b.metrics[h].growth - a.metrics[h].growth;
            }).slice(0, 10);

            const winner = ranked[0];
            const runnersUp = ranked.slice(1);

            const m = winner.metrics[h];
            const cleanName = winner.schemeName.replace(/([-\s]+(Direct|Regular|Growth|IDCW|Dividend|Payout|Plan|Option))+.*/gi, '').trim();

            finalHtml += `
                <div class="playing-card ${m.growth >= 0 ? 'card-positive' : 'card-negative'}" style="width: 100%; height: auto; min-height: auto; flex: none; display: block; padding-bottom: 20px;">
                    <div class="card-content" style="text-align: left; padding: 16px;">
                        <div style="margin-bottom: 12px; display: flex; justify-content: space-between; align-items: center;">
                            <span class="modern-badge-v2" style="font-size: 0.65rem; background: rgba(255,255,255,0.08);">${timeLabels[h]} Leader</span>
                        </div>
                        <h4 class="card-title-v2" title="${winner.schemeName}" style="white-space: normal; height: auto; min-height: 2.4em; font-size: 1.05rem; margin-bottom: 15px; text-align: left;">${cleanName}</h4>
                        
                        <div class="card-stats-grid" style="margin-bottom: 15px;">
                            <div class="stat-box">
                                <span class="stat-label">Stability</span>
                                <span class="stat-value text-success"><i class="bi bi-arrow-up-short"></i>${m.rises} Rises</span>
                            </div>
                            <div class="stat-box">
                                <span class="stat-label">Volatility</span>
                                <span class="stat-value text-danger"><i class="bi bi-arrow-down-short"></i>${m.falls} Falls</span>
                            </div>
                        </div>

                        <div class="card-main-stat" style="margin-bottom: 20px; text-align: left;">
                            <div style="display: flex; align-items: baseline; gap: 8px; flex-wrap: nowrap; overflow: hidden;">
                                <span style="font-size: 0.8rem; font-weight: 800; color: var(--brand-primary); text-transform: uppercase; white-space: nowrap;">Rank #1</span>
                                <span class="profit-amount" style="font-size: 1.5rem; margin: 0; line-height: 1; white-space: nowrap; color: ${cat.key === 'stability' ? 'var(--success-color)' : (m.growth >= 0 ? 'var(--success-color)' : 'var(--danger-color)')};">
                                    ${cat.key === 'stability' ? `${m.strikeRate.toFixed(1)}% SR` : `${m.growth >= 0 ? '+' : ''}${m.growth.toFixed(2)}% Growth`}
                                </span>
                            </div>
                        </div>

                        <div class="card-periodic-list" style="margin-top: 10px; max-height: none; overflow: visible; background: rgba(0,0,0,0.15); padding: 12px; height: auto;">
                            <div style="font-size: 0.65rem; color: var(--text-secondary); margin-bottom: 8px; text-transform: uppercase; letter-spacing: 0.5px; font-weight: 700; border-bottom: 1px solid rgba(255,255,255,0.05); padding-bottom: 5px;">Top 10 Rankings</div>
                            ${runnersUp.map((r, i) => {
                const rm = r.metrics[h];
                const rName = r.schemeName.replace(/([-\s]+(Direct|Regular|Growth|IDCW|Dividend|Payout|Plan|Option))+.*/gi, '').trim();
                const rVal = cat.key === 'stability' ? `${rm.strikeRate.toFixed(1)}% SR` : `${rm.growth >= 0 ? '+' : ''}${rm.growth.toFixed(2)}%`;
                return `
                                    <div class="periodic-row-v2" style="font-size: 0.68rem; padding: 6px 0; border-color: rgba(255,255,255,0.03);">
                                        <div style="display: flex; gap: 8px; align-items: center; overflow: hidden; flex: 1;">
                                            <span style="font-weight: 800; color: var(--text-secondary); min-width: 20px;">#${i + 2}</span>
                                            <span style="white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: rgba(255,255,255,0.8);">${rName}</span>
                                        </div>
                                        <span class="period-val ${cat.key === 'stability' ? 'pos' : (rm.growth >= 0 ? 'pos' : 'neg')}" style="margin-left: 10px; font-weight: 700;">${rVal}</span>
                                    </div>
                                `;
            }).join('')}
                        </div>
                    </div>
                </div>
            `;
        }); // End of displayHorizons loop

        finalHtml += `</div>`; // Close grid container for this category
    }); // End of categories loop

    resultsContainer.innerHTML = finalHtml;
}


