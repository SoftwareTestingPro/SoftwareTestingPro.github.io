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
 * Device detection helper
 */
const isMobile = () => window.innerWidth < 768;

/**
 * Render all individual fund cards
 */
async function displayFunds() {
    const container = document.getElementById('fundsContainer');
    const header = document.getElementById('historyHeader');
    
    if (userInvestments.length === 0) {
        if (header) header.style.display = 'none';
        container.innerHTML = `
            <div class="empty-state" style="width: 100%; text-align: center; padding: 40px; opacity: 0.6;">
                <i class="bi bi-inbox" style="font-size: 3rem; margin-bottom: 16px; display: block;"></i>
                <h4>No Funds Added Yet</h4>
                <p>Add your first investment above to start tracking performance.</p>
            </div>`;
        return;
    }
    
    // Ensure header is shown if there's data (assuming we are in a view that wants it)
    if (header && (document.getElementById('fundsContainer').style.display !== 'none')) {
        header.style.display = 'block';
    }

    showLoading();
    try {
        const sorted = [...userInvestments].sort((a, b) => {
            const dateDiff = new Date(b.investmentDate) - new Date(a.investmentDate);
            if (dateDiff !== 0) return dateDiff;
            return (b.id || 0) - (a.id || 0); // Recent ID first if dates are equal
        });
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

                const isMob = isMobile();

                return `
                    <div class="playing-card ${returns >= 0 ? 'card-positive' : 'card-negative'} ${isMob ? 'mobile-compact' : ''}">
                        <div class="card-content">
                            <h5 class="card-title-v2" title="${investment.schemeName}">${cleanTitle}</h5>
                            <div class="card-meta-v2 text-muted-v2">
                                ${isMob ? formatDate(investment.investmentDate) : formatDate(investment.investmentDate) + ' • ' + investment.units.toFixed(2) + ' Units • ' + planInfo}
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
                return `
                    <div class="playing-card card-negative mobile-compact">
                        <div class="card-content">
                            <h5 class="card-title-v2">${investment.schemeName}</h5>
                            <div class="alert alert-danger" style="font-size: 0.8rem; background: rgba(220, 38, 38, 0.1); border: 1px solid rgba(220, 38, 38, 0.2); color: #ef4444;">
                                <i class="bi bi-exclamation-triangle"></i> Data Error: ${err.message}
                            </div>
                            <div class="card-actions-v2">
                                <button class="btn-action-v2 delete" onclick="removeFund('${investment.id}')">Remove</button>
                            </div>
                        </div>
                    </div>`;
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

        const isMob = isMobile();
        const summaryHTML = `
            <div class="playing-card ${profit >= 0 ? 'card-positive' : 'card-negative'} ${isMob ? 'mobile-compact' : ''}" style="margin: 0;">
                <div class="card-content">
                    <h5 class="card-title-v2" title="Portfolio Summary">Portfolio Summary</h5>
                    <div class="card-meta-v2 text-muted-v2" style="white-space: normal; height: auto;">
                        ${isMob ? uniqueFundCount + ' Funds' : 'Investment Since: ' + oldestDateStr + ' • ' + uniqueFundCount + ' Funds'}
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
    const amcContainer = document.getElementById('amcGroupsContainer');
    const catContainer = document.getElementById('catGroupsContainer');
    const customContainer = document.getElementById('customGroupsContainer');

    if (!amcContainer || !catContainer || !customContainer) return;

    // Reset containers
    amcContainer.innerHTML = '';
    catContainer.innerHTML = '';
    customContainer.innerHTML = '';

    try {
        showLoading();
        const isMob = isMobile();

        const renderGroup = async (group) => {
            const stats = await calculateGroupStats(group.fundIds);
            const rawName = group.name;
            const displayName = rawName.charAt(0).toUpperCase() + rawName.slice(1);
            const subLabel = group.subName || (group.isAutomated ? 'Auto Intelligence' : 'Personal Group');
            
            const groupIcon = group.id.includes('amc') ? 'bi-bank' : (group.id.includes('cat') ? 'bi-tags' : 'bi-folder2-open');

            const uniqueCodes = new Set(group.fundIds.map(fid => userInvestments.find(inv => String(inv.id) === String(fid))?.schemeCode).filter(Boolean));
            const fundCount = uniqueCodes.size;

            const pctReturns = stats.totalInvestment > 0 ? (stats.totalReturns / stats.totalInvestment * 100) : 0;
            return `
                <div class="playing-card ${stats.totalReturns >= 0 ? 'card-positive' : 'card-negative'} ${isMob ? 'mobile-compact' : ''}">
                    <div class="card-content">
                        <h5 class="card-title-v2" title="${displayName}"><i class="bi ${groupIcon} me-2" style="opacity:0.7"></i>${displayName}</h5>
                        <div class="card-meta-v2 text-muted-v2">${subLabel} • ${fundCount} Unique Fund${fundCount !== 1 ? 's' : ''}</div>
                        
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
                                        fLabel = `Last change(${parseInt(eParts[0], 10)} ${monthsShort[parseInt(eParts[1], 10) - 1]})`;
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
                        </div>
                    </div>
                </div>`;
        };

        const amcGroups = fundGroups.filter(g => g.id.includes('auto-amc')).sort((a,b) => a.name.localeCompare(b.name));
        const catGroups = fundGroups.filter(g => g.id.includes('auto-cat')).sort((a,b) => a.name.localeCompare(b.name));
        const customGroups = fundGroups.filter(g => !g.isAutomated).sort((a,b) => a.name.localeCompare(b.name));

        amcContainer.innerHTML = (await Promise.all(amcGroups.map(renderGroup))).join('');
        catContainer.innerHTML = (await Promise.all(catGroups.map(renderGroup))).join('');
        
        if (customGroups.length === 0) {
            customContainer.innerHTML = `
                <div class="empty-state-v2" style="width: 100%; grid-column: 1 / -1; padding: 40px; text-align: center; background: rgba(255,255,255,0.02); border-radius: 20px; border: 1px dashed rgba(255,255,255,0.1); margin-bottom: 30px;">
                    <i class="bi bi-folder-plus" style="font-size: 2.5rem; color: rgba(255,255,255,0.2); margin-bottom: 12px; display: block;"></i>
                    <p style="color: var(--text-secondary); margin: 0;">No custom collections created yet.</p>
                </div>
            `;
        } else {
            customContainer.innerHTML = (await Promise.all(customGroups.map(renderGroup))).join('');
        }

        // Always append the Add Group card at the end of custom collections
        const addCardTemplate = document.getElementById('addGroupTemplate');
        if (addCardTemplate && customContainer) {
            const tempDiv = document.createElement('div');
            tempDiv.innerHTML = addCardTemplate.innerHTML;
            const card = tempDiv.firstElementChild;
            if (isMob) card.classList.add('mobile-compact');
            customContainer.appendChild(card);
        }

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
    const header = document.getElementById('researchHeader');
    if (!container) return;

    if (userInvestments.length === 0) {
        if (header) header.style.display = 'none';
        container.innerHTML = `<div class="empty-state" style="width: 100%; text-align: center; padding: 40px; opacity: 0.6;">
            <i class="bi bi-search" style="font-size: 3rem; margin-bottom: 16px; display: block;"></i>
            <h4>No Data for Research</h4>
            <p>Add some funds first to see performance insights.</p>
        </div>`;
        return;
    }

    if (header && (container.style.display !== 'none')) {
        header.style.display = 'block';
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
                perf1M: stats.periodicReturns.monthly?.percentage ?? null,
                perf3M: stats.periodicReturns.quarterly?.percentage ?? null,
                perf6M: stats.periodicReturns.halfYearly?.percentage ?? null,
                perf9M: stats.periodicReturns.nineMonths?.percentage ?? null,
                perf1Y: stats.periodicReturns.yearly?.percentage ?? null,
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

        // 5. Periodic Worst Performers Logic
        const getWorstForPeriod = (periodKey) => {
            return advancedStats
                .filter(f => f[periodKey] !== null)
                .sort((a,b) => (a[periodKey] || 0) - (b[periodKey] || 0))[0];
        };

        const worst1M = getWorstForPeriod('perf1M');
        const worst3M = getWorstForPeriod('perf3M');
        const worst6M = getWorstForPeriod('perf6M');
        const worst9M = getWorstForPeriod('perf9M');
        const worst1Y = getWorstForPeriod('perf1Y');

        let html = '';

        const createInsightCard = (fund, title, sub, variant, extraVal = null) => {
            if (!fund) return '';

            // Default to overall stats
            let mainAmount = (fund.absoluteReturns) || 0;
            let mainPct = (fund.returnsPct) || 0;
            let maxXirr = (fund.stats?.cagr) || 0;

            // Context Logic: Adapt main display to the specific insight window
            if (variant.startsWith('worst')) {
                 const periodMap = { worst1M: 'monthly', worst3M: 'quarterly', worst6M: 'halfYearly', worst9M: 'nineMonths', worst1Y: 'yearly' };
                 const pData = fund.stats.periodicReturns?.[periodMap[variant]];
                 if (pData) {
                     mainAmount = pData.absolute || 0;
                     mainPct = pData.percentage || 0;
                     
                     // Annualize the period-specific return for a relevant XIRR badge
                     const daysMap = { worst1M: 30, worst3M: 90, worst6M: 180, worst9M: 270, worst1Y: 365 };
                     maxXirr = (Math.pow(1 + (mainPct / 100), 365.25 / daysMap[variant]) - 1) * 100;
                 }
            }

            const isPos = mainPct >= 0;
            const cleanTitle = fund.schemeName.replace(/([-\s]+(Direct|Regular|Growth|IDCW|Dividend|Payout|Plan|Option))+.*/gi, '').trim();
            const badgeClass = variant === 'best' ? 'success' : (variant.startsWith('worst') || variant === 'under' ? 'danger' : 'info');
            const icon = variant === 'best' ? 'bi-trophy-fill' : (variant === 'bestDefender' ? 'bi-shield-check' : (variant === 'bestClimber' ? 'bi-graph-up-arrow' : 'bi-exclamation-triangle-fill'));

            // High-precision currency: Show decimals if the amount is less than 1 or 2, to avoid "0"
            const formattedAmount = Math.abs(mainAmount) < 2 && Math.abs(mainAmount) > 0
                ? Math.abs(mainAmount).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })
                : Math.abs(mainAmount).toLocaleString(undefined, { maximumFractionDigits: 0 });

            return `
                <div class="playing-card ${variant === 'best' ? 'card-positive' : (variant.startsWith('worst') || variant === 'under' ? 'card-negative' : 'card-info')}">
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
        
        const renderWarning = (fund, title, sub, variant) => {
            if (fund && fund[variant.replace('worst', 'perf')] < 0) {
                return createInsightCard(fund, title, sub, variant);
            }
            return '';
        };

        html += renderWarning(worst1M, '1-MONTH DIP', 'Recorded the sharpest decline in value over the last 30 days of market activity.', 'worst1M');
        html += renderWarning(worst3M, 'QUARTERLY WARNING', 'This holding has shown the highest relative drop during the last 90-day tracking window.', 'worst3M');
        html += renderWarning(worst6M, '6-MONTH WARNING', 'Recorded the most significant relative decline in value within your portfolio over the last 180-day tracking window.', 'worst6M');
        html += renderWarning(worst9M, '9-MONTH DECLINE', 'Persistent underperformance identified over the last three quarters (270 days).', 'worst9M');
        html += renderWarning(worst1Y, '1-YEAR TREND', 'This fund has been your weakest performer over the last full year of tracking.', 'worst1Y');
        
        // Final fallback: If everything is positive, show the "STABLE ASSET" in the last slot
        if (worst6M && worst6M.perf6M >= 0) {
            html += createInsightCard(worst6M, 'STABLE ASSET', 'Maintained the most resilient and conservative performance profile in your portfolio during the last 6-month period.', 'info');
        }

        container.innerHTML = html;
    } finally {
        hideLoading();
    }
}

/**
 * Market Discovery Logic - Sector Scanning
 */
const discoveryPerfCache = {}; // Local session cache for discovery performance

async function runDiscovery() {
    const category = document.getElementById('discoveryCategory')?.value;
    const sector = document.getElementById('discoverySector')?.value;
    const plan = document.getElementById('discoveryPlan')?.value;
    const durationChecks = document.querySelectorAll('.duration-check:checked');

    if (!category || !sector || !plan) {
        showInfo('Please select a Category, Sector, and Plan to begin scanning.');
        return;
    }

    if (durationChecks.length === 0) {
        showInfo('Please select at least one performance horizon (Matrix).');
        return;
    }
    const selectedDurations = Array.from(durationChecks).map(cb => cb.value);
    
    const resultsContainer = document.getElementById('discoveryResults');
    const progressBlock = document.getElementById('scanProgress');
    const progressBar = document.getElementById('scanProgressBar');
    const scanStatus = document.getElementById('scanStatus');

    if (!allFundsCache) {
        showError('Fund database not loaded. Please wait or refresh.');
        return;
    }

    if (selectedDurations.length === 0) {
        showError('Please select at least one performance horizon.');
        return;
    }

    // 1. Filter candidates based on Category, Sector, and Plan
    const rawCandidates = allFundsCache.filter(f => {
        const name = f.schemeName;
        // Check Plan (Direct/Regular)
        if (plan === 'Direct' && !name.includes('Direct')) return false;
        if (plan === 'Regular' && name.includes('Direct')) return false;

        // Check Category Heuristics
        const lowerName = name.toLowerCase();
        if (category === 'Debt' && !(lowerName.includes('debt') || lowerName.includes('bond') || lowerName.includes('gilt') || lowerName.includes('corporate') || lowerName.includes('short term'))) return false;
        if (category === 'Hybrid' && !(lowerName.includes('hybrid') || lowerName.includes('balanced') || lowerName.includes('arbitrage'))) return false;
        if (category === 'Index' && !(lowerName.includes('index') || lowerName.includes('nifty') || lowerName.includes('sensex') || lowerName.includes('etf'))) return false;
        if (category === 'Liquid' && !(lowerName.includes('liquid') || lowerName.includes('money market') || lowerName.includes('overnight'))) return false;
        if (category === 'Equity' && (lowerName.includes('debt') || lowerName.includes('hybrid') || lowerName.includes('index') || lowerName.includes('etf') || lowerName.includes('liquid'))) return false;

        // Check Sector/Sub-Category
        if (sector && !lowerName.includes(sector.toLowerCase())) return false;
        
        return true;
    });

    if (rawCandidates.length === 0) {
        resultsContainer.innerHTML = '<p style="text-align: center; width: 100%; opacity: 0.5; padding: 40px;">No funds match your specific criteria. Try loosening your sector filters.</p>';
        return;
    }

    // For better performance, pick top matches by relevance
    const candidates = rawCandidates.slice(0, 20);
    
    // Efficiency: Check if we even need to show the progress bar
    const allCached = candidates.every(f => discoveryPerfCache[f.schemeCode]);
    if (!allCached) {
        progressBlock.style.display = 'block';
    }
    
    resultsContainer.innerHTML = '';
    
    const processedResults = [];
    for (let i = 0; i < candidates.length; i++) {
        const f = candidates[i];
        try {
            const percent = Math.round(((i + 1) / candidates.length) * 100);
            
            let perf;
        
            // Check session discovery cache first
            if (discoveryPerfCache[f.schemeCode]) {
                perf = discoveryPerfCache[f.schemeCode];
            } 
            // Check portfolio data (reusing 1Y/6M calculations already performed)
            else if (typeof allFundsData !== 'undefined') {
                const existing = allFundsData.find(own => own.schemeCode == f.schemeCode);
                if (existing && existing.performance && existing.performance.periodic) {
                    perf = existing.performance.periodic;
                    discoveryPerfCache[f.schemeCode] = perf; 
                }
            }

            if (!perf) {
                progressBar.style.width = `${percent}%`;
                if (scanStatus) scanStatus.innerText = `Analyzing ${f.schemeName.split(' - ')[0]}...`;
                
                const navRes = await getCurrentNAV(f.schemeCode);
                const dummyInv = { 
                    schemeCode: f.schemeCode, 
                    schemeName: f.schemeName, 
                    units: 1, 
                    investmentAmount: 1, 
                    nav: 1, 
                    investmentDate: '2010-01-01' 
                };
                const perfRes = await calculatePerformance(dummyInv, navRes.nav);
                perf = perfRes.periodic;
                discoveryPerfCache[f.schemeCode] = perf;
            }
            
            processedResults.push({
                schemeName: f.schemeName,
                schemeCode: f.schemeCode,
                performance: perf
            });
        } catch (e) { 
            console.error(`Failed to scan ${f.schemeName}`, e); 
        }
    }

    progressBlock.style.display = 'none';

    if (processedResults.length === 0) {
        resultsContainer.innerHTML = '<p style="text-align: center; width: 100%;">Scanner could not reach the data server. Please try again.</p>';
        return;
    }

    // Render exactly one champion for each selected duration
    const labelMap = { weekly: '7 Days', fifteenDays: '15 Days', monthly: '1 Month', quarterly: '3 Months', halfYearly: '6 Months', nineMonths: '9 Months', yearly: '1 Year' };
    const daysMap = { weekly: 7, fifteenDays: 15, monthly: 30, quarterly: 90, halfYearly: 180, nineMonths: 270, yearly: 365.25 };
    let finalHtml = '';
    
    selectedDurations.forEach(durKey => {
        const topFund = [...processedResults]
            .filter(r => r.performance[durKey])
            .sort((a,b) => b.performance[durKey].value - a.performance[durKey].value)[0];

        if (topFund) {
            const val = topFund.performance[durKey].value;
            const cleanTitle = topFund.schemeName.replace(/([-\s]+(Direct|Regular|Growth|IDCW|Dividend|Payout|Plan|Option))+.*/gi, '').trim();
            const annYield = (Math.pow(1 + (val / 100), 365.25 / daysMap[durKey]) - 1) * 100;
            
            finalHtml += `
                <div class="playing-card" style="flex: 0 0 320px; border-top: 3px solid var(--brand-primary);">
                    <div class="card-content" style="padding: 18px;">
                        <div style="margin-bottom: 12px; display: flex; justify-content: space-between; align-items: center;">
                            <span class="modern-badge-v2 success" style="font-size: 0.65rem; letter-spacing: 1px;"><i class="bi bi-award-fill"></i> ${labelMap[durKey]} CHAMPION</span>
                        </div>
                        <h4 class="card-title-v2" style="font-size: 1.05rem; height: 2.4em; overflow: hidden; margin-bottom: 20px;">${cleanTitle}</h4>
                        
                        <div class="card-main-stat" style="margin-bottom: 20px;">
                            <div class="profit-amount text-success" style="font-size: 1.8rem;">
                                +${val.toFixed(2)}%
                            </div>
                            <div class="profit-badges">
                                <span class="modern-badge-v2 success">MOMENTUM</span>
                                <span class="modern-badge-v2 info">XIRR ${annYield.toFixed(2)}%</span>
                            </div>
                        </div>

                        <div class="card-periodic-list" style="margin-bottom: 15px; background: rgba(0,0,0,0.2); padding: 12px; border-radius: 8px;">
                            <div style="font-size: 0.65rem; color: var(--text-secondary); text-transform: uppercase; margin-bottom: 5px; font-weight: 700;">Performance Details</div>
                            <div style="display: flex; justify-content: space-between; font-size: 0.8rem; margin-bottom: 4px;">
                                <span style="color: rgba(255,255,255,0.6);">Growth in ${labelMap[durKey]}</span>
                                <span class="text-success" style="font-weight: 700;">+${val.toFixed(2)}%</span>
                            </div>
                            <div style="display: flex; justify-content: space-between; font-size: 0.8rem;">
                                <span style="color: rgba(255,255,255,0.6);">Ann. Projected Yield</span>
                                <span style="color: white; font-weight: 700;">${annYield.toFixed(2)}%</span>
                            </div>
                        </div>

                        <button class="btn-action-v2 view" onclick="quickAddFund('${topFund.schemeCode}', '${topFund.schemeName}')" style="width: 100%; justify-content: center; height: 38px;">
                            <i class="bi bi-plus-circle"></i> Quick Add to Tracker
                        </button>
                    </div>
                </div>
            `;
        }
    });

    resultsContainer.innerHTML = finalHtml || '<p style="text-align: center; width: 100%; opacity: 0.5; padding: 40px;">No performance leaders identified. Select more check-boxes to expand the search.</p>';
}

function displayExplore() {
    const container = document.getElementById('exploreContainer');
    if (!container) return;

    // Persist results: only render the filter UI if it's empty
    if (container.innerHTML.trim() !== "") return;

    // Filter bar + Progress placeholder + Results grid
    container.innerHTML = `
        <div id="explorerFilters" style="width: 100%; margin-top: 40px; padding: 30px; background: rgba(30, 41, 59, 0.4); border-radius: 20px; border: 1px solid rgba(255, 255, 255, 0.05); margin-bottom: 30px;">
            <div style="display: flex; justify-content: space-between; align-items: flex-end; margin-bottom: 24px; flex-wrap: wrap; gap: 20px;">
                <div>
                    <h3 style="margin: 0; display: flex; align-items: center; gap: 10px;">
                        <i class="bi bi-globe" style="color: var(--brand-primary);"></i> Market Explorer
                    </h3>
                    <p style="color: var(--text-secondary); margin: 5px 0 0; font-size: 0.95rem;">Scan & Discover the most consistent funds</p>
                </div>
                <div style="display: flex; gap: 12px; flex-wrap: wrap; width: 100%; margin-top: 15px;">
                    <div class="filter-group">
                        <label style="font-size: 0.7rem; color: var(--text-secondary); margin-bottom: 5px; display: block; text-transform: uppercase;">Category</label>
                        <select id="discoveryCategory" class="form-control-modern" style="width: 140px; background: rgba(0,0,0,0.3); border-color: rgba(255,255,255,0.1); color: white;">
                            <option value="">Select</option>
                            <option value="Equity">Equity</option>
                            <option value="Debt">Debt</option>
                            <option value="Hybrid">Hybrid</option>
                            <option value="Index">Index/ETF</option>
                            <option value="Liquid">Liquid</option>
                        </select>
                    </div>
                    <div class="filter-group">
                        <label style="font-size: 0.7rem; color: var(--text-secondary); margin-bottom: 5px; display: block; text-transform: uppercase;">Sector/Theme</label>
                        <select id="discoverySector" class="form-control-modern" style="width: 160px; background: rgba(0,0,0,0.3); border-color: rgba(255,255,255,0.1); color: white;">
                            <option value="">Select</option>
                            <option value="Small Cap">Small Cap</option>
                            <option value="Mid Cap">Mid Cap</option>
                            <option value="Large Cap">Large Cap</option>
                            <option value="Flexi Cap">Flexi Cap</option>
                        </select>
                    </div>
                    <div class="filter-group">
                        <label style="font-size: 0.7rem; color: var(--text-secondary); margin-bottom: 5px; display: block; text-transform: uppercase;">Matrix</label>
                        <div class="btn-group" style="width: 200px;">
                            <button type="button" class="form-control-modern dropdown-toggle" data-bs-toggle="dropdown" onclick="event.stopPropagation()">Horizons</button>
                            <ul class="dropdown-menu dropdown-menu-dark" style="padding: 10px; min-width: 250px;" onclick="event.stopPropagation()">
                                <li><label class="dropdown-item"><input type="checkbox" class="duration-check" value="weekly"> 7 Days</label></li>
                                <li><label class="dropdown-item"><input type="checkbox" class="duration-check" value="fifteenDays"> 15 Days</label></li>
                                <li><label class="dropdown-item"><input type="checkbox" class="duration-check" value="monthly"> 1 Month</label></li>
                                <li><label class="dropdown-item"><input type="checkbox" class="duration-check" value="quarterly"> 3 Months</label></li>
                                <li><label class="dropdown-item"><input type="checkbox" class="duration-check" value="halfYearly"> 6 Months</label></li>
                                <li><label class="dropdown-item"><input type="checkbox" class="duration-check" value="nineMonths"> 9 Months</label></li>
                                <li><label class="dropdown-item"><input type="checkbox" class="duration-check" value="yearly"> 1 Year</label></li>
                            </ul>
                        </div>
                    </div>
                    <div class="filter-group">
                        <label style="font-size: 0.7rem; color: var(--text-secondary); margin-bottom: 5px; display: block; text-transform: uppercase;">Plan</label>
                        <select id="discoveryPlan" class="form-control-modern" style="width: 100px; background: rgba(0,0,0,0.3); border-color: rgba(255,255,255,0.1); color: white;">
                            <option value="">Select</option>
                            <option value="Direct">Direct</option>
                            <option value="Regular">Regular</option>
                        </select>
                    </div>
                    <div style="margin-left: auto; align-self: flex-end;">
                        <button onclick="runDiscovery()" class="btn-action-v2 view" style="padding: 10px 24px;">
                            <i class="bi bi-radar"></i> Start Discovery
                        </button>
                    </div>
                </div>
            </div>
            <div id="scanProgress" style="display: none; margin-bottom: 20px;">
                <div style="display: flex; justify-content: space-between; font-size: 0.85rem; margin-bottom: 8px;">
                    <span id="scanStatus">Analyzing sector...</span>
                    <span id="scanPercentage">0%</span>
                </div>
                <div style="height: 6px; background: rgba(255,255,255,0.05); border-radius: 10px; overflow: hidden;">
                    <div id="scanProgressBar" style="width: 0%; height: 100%; background: var(--brand-primary);"></div>
                </div>
            </div>
        </div>
        <div id="discoveryResults" style="display: contents;">
            <div style="opacity: 0.4; text-align: center; width: 100%; padding: 40px;">
                <p>Select your criteria and click Start Discovery</p>
            </div>
        </div>
    `;
}

async function displayUniqueFunds() {
    const container = document.getElementById('uniqueFundsContainer');
    const header = document.getElementById('uniqueFundsHeader');
    if (!container) return;

    if (userInvestments.length === 0) {
        if (header) header.style.display = 'none';
        container.innerHTML = '';
        return;
    }

    if (header) header.style.display = 'block';

    showLoading();
    try {
        // Group by schemeCode
        const groups = {};
        userInvestments.forEach(inv => {
            if (!groups[inv.schemeCode]) {
                groups[inv.schemeCode] = {
                    schemeCode: inv.schemeCode,
                    schemeName: inv.schemeName,
                    totalInvestment: 0,
                    totalUnits: 0,
                    earliestDate: inv.investmentDate,
                    txCount: 0
                };
            }
            groups[inv.schemeCode].totalInvestment += inv.investmentAmount;
            groups[inv.schemeCode].totalUnits += inv.units;
            groups[inv.schemeCode].txCount++;
            if (new Date(inv.investmentDate) < new Date(groups[inv.schemeCode].earliestDate)) {
                groups[inv.schemeCode].earliestDate = inv.investmentDate;
            }
        });

        const sortedGroups = Object.values(groups).sort((a, b) => b.totalInvestment - a.totalInvestment);

        const cardsHTML = await Promise.all(sortedGroups.map(async (group) => {
            try {
                const navDataRes = await getCurrentNAV(group.schemeCode);
                const currentNAV = navDataRes.nav;
                
                const currentValue = group.totalUnits * currentNAV;
                const returns = currentValue - group.totalInvestment;
                const returnsPct = group.totalInvestment > 0 ? (returns / group.totalInvestment) * 100 : 0;
                
                // Synthetic investment for calculations
                const synth = {
                    schemeCode: group.schemeCode,
                    schemeName: group.schemeName,
                    investmentAmount: group.totalInvestment,
                    units: group.totalUnits,
                    investmentDate: group.earliestDate,
                    nav: group.totalInvestment / group.totalUnits
                };

                const cagr = await calculateFundCAGR(synth, currentNAV);
                const perf = await calculatePerformance(synth, currentNAV);

                const perfItems = [];
                if (perf?.periodic) {
                    const monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                    
                    const p = perf.periodic;
                    if (p.daily) {
                        const eParts = p.daily.endDate.split('-'); // dd-mm-yyyy
                        const dateLabel = `${parseInt(eParts[0], 10)} ${monthsShort[parseInt(eParts[1], 10) - 1]}`;
                        perfItems.push({ label: `Last change(${dateLabel})`, value: p.daily.value });
                    }
                    if (p.weekly) perfItems.push({ label: 'Last 7 Days', value: p.weekly.value });
                    if (p.monthly) perfItems.push({ label: 'Last 1 Month', value: p.monthly.value });
                    if (p.yearly) perfItems.push({ label: 'Last 1 Year', value: p.yearly.value });
                }

                const nameLower = group.schemeName.toLowerCase();
                const planType = nameLower.includes('direct') ? 'Direct' : 'Regular';
                const cleanTitle = group.schemeName.replace(/([-\s]+(Direct|Regular|Growth|IDCW|Dividend|Payout|Plan|Option))+.*/gi, '').trim();

                const isMob = isMobile();

                return `
                    <div class="playing-card ${returns >= 0 ? 'card-positive' : 'card-negative'} ${isMob ? 'mobile-compact' : ''}">
                        <div class="card-content">
                            <h5 class="card-title-v2" title="${group.schemeName}">${cleanTitle}</h5>
                            <div class="card-meta-v2 text-muted-v2">
                                ${planType} • ${group.totalUnits.toFixed(2)} Units • ${group.txCount} Purchase${group.txCount > 1 ? 's' : ''}
                            </div>
                            
                            <div class="card-stats-grid">
                                <div class="stat-box">
                                    <span class="stat-label">Total Invested</span>
                                    <span class="stat-value">₹${group.totalInvestment.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                                </div>
                                <div class="stat-box">
                                    <span class="stat-label">Current Value</span>
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
                                ${perfItems.map(item => `
                                    <div class="periodic-row-v2">
                                        <span class="period-lbl">${item.label}</span>
                                        <span class="period-val ${item.value >= 0 ? 'pos' : 'neg'}">${item.value > 0 ? '+' : ''}${item.value.toFixed(2)}%</span>
                                    </div>
                                `).join('')}
                            </div>
                            
                            <div class="card-actions-v2">
                                <button class="btn-action-v2 view" onclick="switchMainView('history')">View Details</button>
                            </div>
                        </div>
                    </div>`;
            } catch (e) {
                return `<div class="playing-card card-negative"><div class="card-content"><h5>${group.schemeName}</h5><p class="text-muted small">Loading error...</p></div></div>`;
            }
        }));

        container.innerHTML = cardsHTML.join('');
    } finally {
        hideLoading();
    }
}

function quickAddFund(code, name) {
    switchMainView('individual');
    window.scrollTo({ top: 0, behavior: 'smooth' });
    alert(`To add "${name}", use the search box on the left!`);
    setTimeout(() => { document.getElementById('fundHouseInput')?.focus(); }, 500);
}
