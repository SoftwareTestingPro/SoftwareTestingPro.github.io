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
 * Standardized Summary Card Template
 */
function getSummaryCardHTML(title, subLabel, percentage, amount, options = {}) {
    const { isDynamic = false, isNeutral = false } = options;
    const effectivePct = options.percentage !== undefined ? options.percentage : percentage;
    const isPositive = effectivePct >= 0 || (effectivePct === undefined && (amount >= 0 || amount === undefined));
    const colorClass = isNeutral ? '' : (isPositive ? 'positive' : 'negative');
    const borderClass = isPositive ? 'border-positive' : 'border-negative';
    
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

    return `
        <div class="summary-card ${isDynamic ? 'dynamic-yearly-card' : ''} ${borderClass}">
            <div class="summary-value ${colorClass}">${valueHTML}</div>
            <div class="summary-label">
                <div class="summary-label-main">${title}</div>
            </div>
        </div>
    `;
}

/**
 * Standardized Mini-Card Template (for Fund Details)
 */
function getMiniCardHTML(title, amount, options = {}) {
    const { percentage, themePercentage, isNeutral = false } = options;
    const statePct = themePercentage !== undefined ? themePercentage : (percentage !== undefined ? percentage : 0);
    const isPositive = statePct >= 0;
    const stateClass = isPositive ? 'positive' : 'negative';
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

    return `
        <div class="minicard ${stateClass}">
            <span class="minicard-value">${valueHTML}</span>
            <span class="minicard-label">${title}</span>
        </div>
    `;
}

// Global UI Helpers
function showLoading() { document.getElementById('loadingSpinner').style.display = 'block'; }
function hideLoading() { document.getElementById('loadingSpinner').style.display = 'none'; }

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
        container.innerHTML = `<div class="empty-state"><h4>No Funds Added Yet</h4></div>`;
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
                } catch (e) {}

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
                            performanceItems.push({ label, subLabel: key === 'daily' ? `(${endD})` : `(Since ${startD})`, value: data.value, startNAV: data.startNAV, endNAV: data.endNAV });
                        }
                    });
                }
                
                if (performance?.yearlyBreakdown) {
                    Object.entries(performance.yearlyBreakdown).sort((a, b) => b[0] - a[0]).forEach(([year, data]) => {
                        performanceItems.push({ label: year, subLabel: `(${formatDate(data.startDate)} - ${formatDate(data.endDate)})`, value: data.value, startNAV: data.startNAV, endNAV: data.endNAV });
                    });
                }

                return `
                    <div class="fund-card modern-added-fund ${returns >= 0 ? 'border-positive' : 'border-negative'}">
                        <div class="fund-header">
                            <div class="fund-info-main">
                                <h5 class="fund-title">${investment.schemeName}</h5>
                                <div class="fund-meta">
                                    <span><i class="bi bi-calendar"></i> ${formatDate(investment.investmentDate)}</span>
                                    <span><i class="bi bi-currency-rupee"></i> ${investment.investmentAmount.toLocaleString()}</span>
                                    <span><i class="bi bi-layers"></i> ${investment.units.toFixed(3)} Units</span>
                                </div>
                            </div>
                            <div class="fund-actions">
                                <button class="btn-icon" onclick="editFund('${investment.id}')"><i class="bi bi-pencil"></i></button>
                                <button class="btn-icon" onclick="removeFund('${investment.id}')"><i class="bi bi-trash"></i></button>
                                <button class="btn-icon expand-toggle-btn collapsed" onclick="togglePerformanceGrid('perf-${investment.id}')"><i class="bi bi-chevron-up"></i></button>
                            </div>
                        </div>
                        <div class="fund-badges">
                            <span class="modern-badge neutral">NAV: ₹${currentNAV.toFixed(2)}</span>
                            <span class="modern-badge ${returns >= 0 ? 'success' : 'danger'}">₹${Math.abs(returns).toFixed(2)} (${returnsPct.toFixed(2)}%)</span>
                            <span class="modern-badge info">XIRR: ${cagr.toFixed(2)}%</span>
                        </div>
                        <div class="minicard-scroller performance-grid collapsed" id="perf-${investment.id}">
                            ${getMiniCardHTML('Investment', investment.investmentAmount, { themePercentage: returnsPct })}
                            ${getMiniCardHTML('Value', currentValue, { themePercentage: returnsPct })}
                            ${getMiniCardHTML('Profit', returns, { percentage: returnsPct })}
                            ${getMiniCardHTML('XIRR', undefined, { percentage: cagr })}
                            ${performanceItems.map(item => getMiniCardHTML(item.label === 'Yesterday' ? `Last Change (As on ${navDataRes.date})` : item.label, (item.endNAV - item.startNAV) * investment.units, { percentage: item.value })).join('')}
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
        let totalInv = 0, totalVal = 0, flows = [];
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
            try {
                const history = await NAVManager.getNAV(inv.schemeCode);
                if (history?.data?.length > 0) {
                    const sorted = history.data.sort((a,b) => {
                        const [d1,m1,y1] = a.date.split('-');
                        const [d2,m2,y2] = b.date.split('-');
                        return new Date(y1,m1-1,d1) - new Date(y2,m2-1,d2);
                    });
                    const [fd,fm,fy] = sorted[0].date.split('-');
                    const firstDate = new Date(fy,fm-1,fd);
                    if (new Date(inv.investmentDate) < firstDate) {
                        effectiveUnits = inv.investmentAmount / parseFloat(sorted[0].nav);
                    }
                }
            } catch(e) {}

            totalInv += inv.investmentAmount;
            totalVal += effectiveUnits * cNav;

            const [y, m, d] = inv.investmentDate.split('-');
            flows.push({ date: new Date(y, m - 1, d), amount: -inv.investmentAmount });
        }

        const profit = totalVal - totalInv;
        const profitPct = totalInv > 0 ? (profit / totalInv) * 100 : 0;
        const xirr = calculatePortfolioXIRR(flows, totalVal);

        // Update Main Cards
        document.getElementById('totalInvestment').textContent = `₹${totalInv.toLocaleString(undefined, { maximumFractionDigits: 0 })}`;
        document.getElementById('currentValue').textContent = `₹${totalVal.toLocaleString(undefined, { maximumFractionDigits: 0 })}`;
        
        const sign = profit >= 0 ? '+' : '-';
        document.getElementById('totalReturnsPercentage').textContent = `${sign}${Math.abs(profitPct).toFixed(2)}% (₹${sign}${Math.abs(profit).toLocaleString(undefined, { maximumFractionDigits: 0 })})`;
        document.getElementById('cagrValue').textContent = `${xirr >= 0 ? '+' : ''}${xirr.toFixed(2)}%`;

        // Update Colors/Borders
        const stateClass = profit >= 0 ? 'positive' : 'negative';
        ['totalInvestment', 'currentValue', 'totalReturnsPercentage', 'cagrValue'].forEach(id => {
            const el = document.getElementById(id);
            if (el) {
                // Apply color class to the value itself
                if (id === 'totalInvestment') {
                    el.className = 'summary-value'; // Neutral for investment
                } else if (id === 'cagrValue') {
                    el.className = `summary-value ${xirr >= 0 ? 'positive' : 'negative'}`;
                } else {
                    el.className = `summary-value ${stateClass}`;
                }

                // Apply border and background class to the card
                const card = el.closest('.summary-card');
                if (card) {
                    card.classList.remove('border-positive', 'border-negative');
                    if (id === 'totalInvestment') {
                        card.classList.add('border-positive'); // Standard green tint for info
                    } else if (id === 'cagrValue') {
                        card.classList.add(xirr >= 0 ? 'border-positive' : 'border-negative');
                    } else {
                        card.classList.add(profit >= 0 ? 'border-positive' : 'border-negative');
                    }
                }
            }
        });

        // Contextual Dates
        const latestNAVDateRaw = navResults.reduce((latest, res) => {
            if (!res.date || res.date === 'N/A') return latest;
            const [d, m, y] = res.date.split('-');
            const current = `${y}-${m}-${d}`;
            return (latest === 'N/A' || current > latest) ? current : latest;
        }, 'N/A');
        const numDate = latestNAVDateRaw !== 'N/A' ? latestNAVDateRaw.split('-').reverse().join('-') : 'N/A';

        const labels = { 
            'totalInvestment': 'Total Investment',
            'currentValue': `Value (As on ${numDate})`, 
            'totalReturnsPercentage': `Profit (As on ${numDate})`, 
            'cagrValue': 'XIRR (Annual)' 
        };
        Object.entries(labels).forEach(([id, text]) => {
            const el = document.getElementById(id);
            if (!el) return;
            const card = el.closest('.summary-card');
            const label = card.querySelector('.summary-label');
            if (label) label.innerHTML = `<div class="summary-label-main">${text}</div>`;
        });

        // Periodic Portfolio Performance
        const results = await Promise.all(userInvestments.map(async (inv) => {
            const navRes = navResults.find(r => String(r.id) === String(inv.id));
            if (navRes && navRes.nav > 0) return { inv, val: inv.units * navRes.nav, data: await calculatePerformance(inv, navRes.nav) };
            return null;
        }));

        const periods = [{ key: 'daily', id: 'Daily' }, { key: 'weekly', id: 'Weekly' }, { key: 'fifteenDays', id: 'FifteenDays' }, { key: 'monthly', id: 'Monthly' }, { key: 'quarterly', id: 'Quarterly' }, { key: 'halfYearly', id: 'HalfYearly' }, { key: 'yearly', id: 'Yearly' }];
        
        const summaryContainer = document.getElementById('summaryStats');
        summaryContainer.querySelectorAll('.dynamic-yearly-card').forEach(c => c.remove());

        const seenDashCombos = new Set();
        periods.forEach(p => {
            let weightedSum = 0, totalValForPeriod = 0, totalAmt = 0, sDate = '', eDate = '';
            results.forEach(res => {
                if (res?.data?.periodic?.[p.key]) {
                    const item = res.data.periodic[p.key];
                    weightedSum += item.value * res.val;
                    totalValForPeriod += res.val;
                    totalAmt += (item.endNAV - item.startNAV) * res.inv.units;
                    sDate = item.startDate; eDate = item.endDate;
                }
            });

            const card = document.getElementById(`card${p.id}`);
            if (card && totalValForPeriod > 0) {
                const weightedPct = weightedSum / totalValForPeriod;
                
                // Deduplicate logic
                const combo = `${sDate}_${weightedPct.toFixed(4)}`;
                if (seenDashCombos.has(combo)) {
                    card.style.display = 'none';
                    return;
                }
                seenDashCombos.add(combo);

                const pSign = weightedPct >= 0 ? '+' : '-';
                document.getElementById(`portfolio${p.id}Percentage`).textContent = `${pSign}${Math.abs(weightedPct).toFixed(2)}% (₹${pSign}${Math.abs(totalAmt).toLocaleString(undefined, { maximumFractionDigits: 0 })})`;
                document.getElementById(`portfolio${p.id}Percentage`).className = `summary-value ${weightedPct >= 0 ? 'positive' : 'negative'}`;
                
                const label = document.getElementById(`label${p.id}`);
                const original = label.getAttribute('data-original-label') || label.textContent;
                if (!label.getAttribute('data-original-label')) label.setAttribute('data-original-label', original);
                label.innerHTML = `<div class="summary-label-main">${p.key === 'daily' ? `Last Change (As on ${eDate})` : `${original} (Since ${sDate})`}</div>`;
                
                card.classList.remove('border-positive', 'border-negative');
                card.classList.add(weightedPct >= 0 ? 'border-positive' : 'border-negative');
                card.style.display = 'flex';
            } else if (card) {
                card.style.display = 'none';
            }
        });

        // Dynamic Yearly Breakdown Cards
        const yearlyData = {};
        results.forEach(res => {
            if (res?.data?.yearlyBreakdown) {
                Object.entries(res.data.yearlyBreakdown).forEach(([year, data]) => {
                    if (!yearlyData[year]) yearlyData[year] = { weightedSum: 0, totalVal: 0, totalAmt: 0, sDate: '', eDate: '' };
                    yearlyData[year].weightedSum += data.value * res.val;
                    yearlyData[year].totalVal += res.val;
                    yearlyData[year].totalAmt += (data.endNAV - data.startNAV) * res.inv.units;
                    const fmt = (d) => `${String(d.getDate()).padStart(2, '0')}-${String(d.getMonth() + 1).padStart(2, '0')}-${d.getFullYear()}`;
                    if (!yearlyData[year].sDate) yearlyData[year].sDate = fmt(data.startDate);
                    if (!yearlyData[year].eDate) yearlyData[year].eDate = fmt(data.endDate);
                });
            }
        });

        const curYearStr = String(new Date().getFullYear());
        Object.keys(yearlyData).sort((a,b) => b - a).forEach(year => {
            const data = yearlyData[year];
            if (data.totalVal > 0) {
                const weightedPct = data.weightedSum / data.totalVal;
                const pSign = weightedPct >= 0 ? '+' : '-';
                const card = document.createElement('div');
                card.className = `summary-card dynamic-yearly-card ${weightedPct >= 0 ? 'border-positive' : 'border-negative'}`;
                card.innerHTML = `
                    <div class="summary-value ${weightedPct >= 0 ? 'positive' : 'negative'}">
                        ${pSign}${Math.abs(weightedPct).toFixed(2)}% (₹${pSign}${Math.abs(data.totalAmt).toLocaleString(undefined, { maximumFractionDigits: 0 })})
                    </div>
                    <div class="summary-label">
                        <div class="summary-label-main">${year === curYearStr ? 'Current Year' : year} (Since ${data.sDate})</div>
                    </div>
                `;
                summaryContainer.appendChild(card);
            }
        });
    } finally {
        isSummaryUpdating = false;
    }
}

/**
 * Render groups view
 */
async function displayGroups() {
    const container = document.getElementById('fundsContainer');
    if (fundGroups.length === 0) {
        container.innerHTML = '<div class="empty-state">No Groups Found</div>';
        return;
    }

    try {
        showLoading();
        let filteredGroups = currentGroupFilter === 'all' ? [...fundGroups] : fundGroups.filter(g => g.autoType === currentGroupFilter || (currentGroupFilter === 'custom' && !g.isAutomated));
        
        if (currentGroupFilter === 'all') {
            const custom = filteredGroups.filter(g => !g.isAutomated).sort((a, b) => a.name.localeCompare(b.name));
            const automated = filteredGroups.filter(g => g.isAutomated).sort((a, b) => a.name.localeCompare(b.name));
            filteredGroups = [...custom, ...automated];
        } else {
            filteredGroups.sort((a, b) => a.name.localeCompare(b.name));
        }
        
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

                    return `
                        <div class="group-fund-item ${returns >= 0 ? 'positive' : 'negative'}">
                            <div class="group-fund-name-row d-flex align-items-center justify-content-between mb-2">
                                <div class="d-flex align-items-center flex-grow-1">
                                    <span style="font-weight: 500; color: #000; font-size: 0.95rem;">${agg.schemeName}</span>
                                    ${agg.count >= 1 ? `<span class="modern-badge neutral small ms-2" style="white-space: nowrap;">${agg.count} Purchase Transaction${agg.count > 1 ? 's' : ''}</span>` : ''}
                                </div>
                                ${fundStats.cagr !== 0 ? `<span class="modern-badge ${fundStats.cagr >= 0 ? 'success' : 'danger'} small py-1" style="font-weight: 700; font-size: 0.8rem;">XIRR: ${fundStats.cagr.toFixed(2)}%</span>` : ''}
                            </div>
                            <div class="minicard-scroller">
                                ${getMiniCardHTML('Investment', fundStats.totalInvestment, { themePercentage: returnsPct })}
                                ${getMiniCardHTML('Value', fundStats.currentValue, { themePercentage: returnsPct })}
                                ${getMiniCardHTML('Profit', returns, { percentage: returnsPct })}
                                ${Object.values(fundStats.periodicReturns).map(p => getMiniCardHTML(p.label === 'Yesterday' ? `Last Change (As on ${p.endDate})` : `${p.label}`, p.amount, { percentage: p.percentage })).join('')}
                            </div>
                        </div>`;
                } catch (e) { return `<div class="group-fund-item text-muted">Data unavailable</div>`; }
            }));

            return `
                <div class="fund-card group-container-card">
                    <div class="group-header d-flex align-items-center justify-content-between flex-wrap">
                        <div class="group-title-area d-flex align-items-center gap-2 flex-grow-1">
                            <h4 class="group-title mb-0">${displayName}</h4>
                            ${group.isAutomated ? '<span class="modern-badge neutral small"><i class="bi bi-robot"></i> Default</span>' : '<span class="modern-badge neutral small"><i class="bi bi-person"></i> Custom</span>'}
                            <span class="modern-badge info small">${Object.keys(aggregatedFunds).length} Funds</span>
                        </div>
                        <div class="group-stats-badges d-flex align-items-center gap-2 mt-sm-0 mt-2">
                            ${stats.cagr !== 0 ? `<span class="modern-badge ${stats.cagr >= 0 ? 'success' : 'danger'} group-xirr-badge">XIRR: ${stats.cagr.toFixed(2)}%</span>` : ''}
                            <div class="group-actions ms-2">
                                ${!group.isAutomated ? `
                                    <button class="btn-icon" onclick="editGroupModal('${group.id}')"><i class="bi bi-pencil"></i></button>
                                    <button class="btn-icon" onclick="deleteGroup('${group.id}')"><i class="bi bi-trash"></i></button>
                                ` : ''}
                            </div>
                        </div>
                    </div>
                    
                    <div class="group-stats">
                        ${getSummaryCardHTML('Total Investment', '', undefined, stats.totalInvestment, { isNeutral: true })}
                        ${getSummaryCardHTML(`Value (As on ${formatDate(stats.latestNAVDate)})`, '', undefined, stats.currentValue)}
                        ${getSummaryCardHTML(`Profit (As on ${formatDate(stats.latestNAVDate)})`, '', (stats.totalReturns / stats.totalInvestment * 100), stats.totalReturns)}
                        ${Object.values(stats.periodicReturns).map(p => getSummaryCardHTML(p.label === 'Yesterday' ? `Last Change (As on ${p.endDate})` : `${p.label} (Since ${p.startDate})`, '', p.percentage, p.amount)).join('')}
                    </div>
                    
                    <div class="group-funds-header" onclick="togglePerformanceGrid('funds-${group.id}')">
                        <div class="d-flex align-items-center justify-content-between">
                            <h6 class="group-funds-title">Funds in this group (${Object.keys(aggregatedFunds).length})</h6>
                            <i class="bi bi-chevron-up expand-toggle-btn collapsed"></i>
                        </div>
                    </div>
                    <div class="group-funds collapsed" id="funds-${group.id}">
                        ${groupFundsHTML.join('')}
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
