/**
 * Financial Calculations Module
 * Handles XIRR, CAGR, Periodic Returns, and Group Analytics
 */

/**
 * XIRR calculation using Newton-Raphson method
 */
function calculatePortfolioXIRR(cashFlows, currentValue) {
    if (!cashFlows || cashFlows.length === 0) return 0;

    // Add current value as a positive cash flow at today's date
    const allCashFlows = [
        ...cashFlows,
        { date: new Date(), amount: currentValue }
    ];

    // Sort cash flows by date
    allCashFlows.sort((a, b) => a.date - b.date);

    // Filter out zero amount cash flows
    const filteredFlows = allCashFlows.filter(cf => Math.abs(cf.amount) > 0.01);
    if (filteredFlows.length < 2) return 0;

    // Check if all investments are from the same date
    const uniqueDates = new Set(filteredFlows.map(cf => cf.date.toISOString().split('T')[0]));
    if (uniqueDates.size <= 1) return 0;

    let rate = 0.1; // Initial guess: 10%
    const maxIterations = 100;
    const tolerance = 0.0001;

    for (let iteration = 0; iteration < maxIterations; iteration++) {
        let npv = 0;
        let derivativeNPV = 0;

        for (const cf of filteredFlows) {
            const daysDiff = (cf.date - filteredFlows[0].date) / (1000 * 60 * 60 * 24);
            const years = daysDiff / 365.25;
            const discountFactor = Math.pow(1 + rate, -years);

            npv += cf.amount * discountFactor;
            derivativeNPV += cf.amount * (-years) * discountFactor / (1 + rate);
        }

        if (Math.abs(npv) < tolerance) return rate * 100;
        if (Math.abs(derivativeNPV) < 1e-10) break;

        rate = rate - npv / derivativeNPV;
        if (rate > 1000.0) rate = 1000.0;
        if (rate < -0.99) rate = -0.99;
    }

    return rate * 100;
}

/**
 * Calculate performance for different time periods
 */
async function calculatePerformance(investment, currentNAV) {
    const periods = {
        daily: 1, weekly: 7, fifteenDays: 15, monthly: 30,
        quarterly: 90, halfYearly: 180, yearly: 365
    };

    const performance = { periodic: {}, yearlyBreakdown: {} };
    const investmentDate = new Date(investment.investmentDate);
    investmentDate.setHours(0, 0, 0, 0);

    try {
        const result = await NAVManager.getNAV(investment.schemeCode);
        const navData = result.data.sort((a, b) => {
            const [d1, m1, y1] = a.date.split('-');
            const [d2, m2, y2] = b.date.split('-');
            return new Date(y1, m1 - 1, d1) - new Date(y2, m2 - 1, d2);
        });

        const [fd, fm, fy] = navData[0].date.split('-');
        const firstNavDate = new Date(fy, fm - 1, fd);
        firstNavDate.setHours(0, 0, 0, 0);

        let effectiveInvestmentDate = investmentDate;
        let effectiveInvestmentNav = investment.nav;

        // Auto-fix for dates before fund inception
        if (investmentDate < firstNavDate) {
            effectiveInvestmentDate = firstNavDate;
            effectiveInvestmentNav = parseFloat(navData[0].nav);
        }

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const latestRecord = navData[navData.length - 1];
        const [ld, lm, ly] = latestRecord.date.split('-');
        const latestDataDate = new Date(ly, lm - 1, ld);

        const getNAVForDaysAgo = (days, forceStrictlyBeforeLatest = false) => {
            const target = new Date();
            target.setHours(0, 0, 0, 0);
            target.setDate(target.getDate() - days);

            if (target < effectiveInvestmentDate) return null;

            for (let i = navData.length - 1; i >= 0; i--) {
                if (forceStrictlyBeforeLatest && i === navData.length - 1) continue;
                const [d, m, y] = navData[i].date.split('-');
                const dDate = new Date(y, m - 1, d);
                if (dDate <= target) return { nav: parseFloat(navData[i].nav), date: navData[i].date };
            }
            return null;
        };

        if (effectiveInvestmentDate <= latestDataDate) {
            for (const [key, days] of Object.entries(periods)) {
                const pastData = (key === 'daily') ? getNAVForDaysAgo(1, true) : getNAVForDaysAgo(days);
                if (pastData) {
                    const [pd, pm, py] = pastData.date.split('-').map(Number);
                    const pastDate = new Date(py, pm - 1, pd);
                    
                    if (pastDate < effectiveInvestmentDate) continue;

                    performance.periodic[key] = {
                        value: ((currentNAV - pastData.nav) / pastData.nav) * 100,
                        startNAV: pastData.nav, endNAV: currentNAV, startDate: pastData.date, endDate: latestRecord.date
                    };
                }
            }
        }

        const startYear = effectiveInvestmentDate.getFullYear();
        const curYear = today.getFullYear();
        for (let year = startYear; year <= curYear; year++) {
            const yearStart = new Date(year, 0, 1);
            const yearEnd = (year === curYear) ? today : new Date(year, 11, 31);
            if (yearEnd < effectiveInvestmentDate) continue;

            const effectiveYearStart = effectiveInvestmentDate > yearStart ? effectiveInvestmentDate : yearStart;
            let sNAV = null, eNAV = null;

            for (let i = 0; i < navData.length; i++) {
                const [d, m, y] = navData[i].date.split('-');
                const dDate = new Date(y, m - 1, d);
                if (!sNAV && dDate >= effectiveYearStart) sNAV = parseFloat(navData[i].nav);
                if (dDate <= yearEnd) eNAV = parseFloat(navData[i].nav);
            }

            if (sNAV && eNAV) {
                performance.yearlyBreakdown[year] = {
                    value: ((eNAV - sNAV) / sNAV) * 100,
                    startNAV: sNAV, endNAV: eNAV, startDate: effectiveYearStart, endDate: yearEnd
                };
            }
        }
    } catch (err) {
        console.warn('Calculation error:', err);
    }
    return performance;
}

/**
 * Aggregate stats for a group of funds
 */
async function calculateGroupStats(fundIds) {
    let totalInvestment = 0;
    let totalCurrentValue = 0;
    let investmentDetails = [];
    let oldestDateObj = null;
    let newestDateObj = null;

    const navResults = await Promise.all(fundIds.map(async (fundId) => {
        const investment = userInvestments.find(inv => String(inv.id) === String(fundId));
        if (!investment) return { fundId, nav: 0 };
        try {
            const navData = await getCurrentNAV(investment.schemeCode);
            return { fundId, nav: navData.nav };
        } catch (err) {
            return { fundId, nav: 0 };
        }
    }));

    for (const fundId of fundIds) {
        const investment = userInvestments.find(inv => String(inv.id) === String(fundId));
        if (!investment) continue;

        const navResult = navResults.find(r => String(r.fundId) === String(fundId));
        const currentNAV = navResult ? navResult.nav : 0;
        
        const [y, m, d] = investment.investmentDate.split('-');
        let invDateObj = new Date(y, m - 1, d);
        invDateObj.setHours(0, 0, 0, 0);
        let effectiveUnits = investment.units;

        // Fetch full history to find first NAV date for inception-fix
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
                firstNavDate.setHours(0, 0, 0, 0);
                
                if (invDateObj < firstNavDate) {
                    invDateObj = firstNavDate;
                    const inceptionNav = parseFloat(sortedHistory[0].nav);
                    effectiveUnits = (investment.investmentAmount || 0) / inceptionNav;
                }
            }
        } catch (e) {}

        totalInvestment += (investment.investmentAmount || 0);
        const currentValue = effectiveUnits * currentNAV;
        totalCurrentValue += currentValue;

        if (!oldestDateObj || invDateObj < oldestDateObj) oldestDateObj = invDateObj;
        if (!newestDateObj || invDateObj > newestDateObj) newestDateObj = invDateObj;
        
        investmentDetails.push({ date: invDateObj, amount: -(investment.investmentAmount || 0) });
    }

    const cagr = calculatePortfolioXIRR(investmentDetails, totalCurrentValue);
    const periods = {
        daily: 'Yesterday', weekly: '1 Week', fifteenDays: '15 Days',
        monthly: '1 Month', quarterly: '3 Months', halfYearly: '6 Months', yearly: '1 Year'
    };

    const perfResults = await Promise.all(fundIds.map(async (fundId) => {
        const inv = userInvestments.find(i => String(i.id) === String(fundId));
        const navResult = navResults.find(r => String(r.fundId) === String(fundId));
        if (!inv || !navResult) return null;
        const perf = await calculatePerformance(inv, navResult.nav);
        return { units: inv.units, perf };
    }));

    const periodicReturns = {};
    Object.keys(periods).forEach(key => {
        let totalDiffAmount = 0, totalPastValue = 0, sDate = '', eDate = '', hasData = false;
        perfResults.forEach(res => {
            if (res?.perf?.periodic?.[key]) {
                const p = res.perf.periodic[key];
                totalDiffAmount += (p.endNAV - p.startNAV) * res.units;
                totalPastValue += p.startNAV * res.units;
                hasData = true;
                if (!sDate) sDate = p.startDate;
                if (!eDate) eDate = p.endDate;
            }
        });
        if (hasData && totalPastValue > 0) {
            periodicReturns[key] = {
                label: periods[key], percentage: (totalDiffAmount / totalPastValue) * 100,
                amount: totalDiffAmount, startDate: sDate, endDate: eDate
            };
        }
    });

    // Yearly breakdown aggregation
    const yearlyReturns = {};
    perfResults.forEach(res => {
        if (res?.perf?.yearlyBreakdown) {
            Object.entries(res.perf.yearlyBreakdown).forEach(([year, data]) => {
                if (!yearlyReturns[year]) {
                    const fmt = (d) => `${String(d.getDate()).padStart(2, '0')}-${String(d.getMonth() + 1).padStart(2, '0')}-${d.getFullYear()}`;
                    yearlyReturns[year] = { label: year, totalDiff: 0, totalPast: 0, s: fmt(data.startDate), e: fmt(data.endDate) };
                }
                yearlyReturns[year].totalDiff += (data.endNAV - data.startNAV) * res.units;
                yearlyReturns[year].totalPast += data.startNAV * res.units;
            });
        }
    });

    const curYearStr = String(new Date().getFullYear());
    Object.keys(yearlyReturns).sort((a, b) => b - a).forEach(year => {
        const p = yearlyReturns[year];
        if (p.totalPast > 0) {
            periodicReturns['year_' + year] = {
                label: year === curYearStr ? 'Current Year' : p.label, 
                percentage: (p.totalDiff / p.totalPast) * 100,
                amount: p.totalDiff, startDate: p.s, endDate: p.e
            };
        }
    });

    // Deduplicate identical periodic returns (usually when multiple periods fallback to purchase date)
    const finalPeriodicReturns = {};
    const seenCombos = new Set();
    
    // Sort keys to process shorter periods first (daily, weekly, etc.)
    const sortedPeriodKeys = Object.keys(periodicReturns).sort((a, b) => {
        const order = { daily: 1, weekly: 2, fifteenDays: 3, monthly: 4, quarterly: 5, halfYearly: 6, yearly: 7 };
        const aOrder = order[a] || 99;
        const bOrder = order[b] || 99;
        return aOrder - bOrder;
    });

    sortedPeriodKeys.forEach(key => {
        const p = periodicReturns[key];
        const combo = `${p.startDate}_${p.percentage.toFixed(4)}_${p.amount.toFixed(2)}`;
        if (!seenCombos.has(combo)) {
            finalPeriodicReturns[key] = p;
            if (!key.startsWith('year_')) seenCombos.add(combo);
        }
    });

    let latestNAVDate = 'N/A';
    Object.values(finalPeriodicReturns).forEach(p => {
        if (p.endDate && p.endDate !== 'N/A') {
            let pts = p.endDate.split('-');
            let iso = (pts.length === 3 && pts[0].length === 2) ? `${pts[2]}-${pts[1]}-${pts[0]}` : p.endDate;
            if (latestNAVDate === 'N/A' || iso > latestNAVDate) latestNAVDate = iso;
        }
    });

    const fmtISO = (d) => d ? `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}` : 'N/A';

    return {
        totalInvestment, currentValue: totalCurrentValue, totalReturns: totalCurrentValue - totalInvestment,
        cagr, periodicReturns: finalPeriodicReturns, oldestDate: fmtISO(oldestDateObj), latestNAVDate
    };
}

/**
 * Calculate individual fund CAGR
 */
async function calculateFundCAGR(investment, currentNAV) {
    const [y, m, d] = investment.investmentDate.split('-');
    let invDateObj = new Date(y, m - 1, d);
    invDateObj.setHours(0, 0, 0, 0);

    // Fetch full history to find first NAV date for inception-fix
    try {
        const history = await NAVManager.getNAV(investment.schemeCode);
        if (history && history.data && history.data.length > 0) {
            const sortedHistory = history.data.sort((a, b) => {
                const [d1, m1, y1] = a.date.split('-');
                const [d2, m2, y2] = b.date.split('-');
                return new Date(y1, m1 - 1, d1) - new Date(y2, m2 - 1, d2);
            });
            const [fd, fm, fy] = sortedHistory[0].date.split('-');
            const firstNavDate = new Date(fy, fm - 1, fd);
            firstNavDate.setHours(0, 0, 0, 0);
            
            if (invDateObj < firstNavDate) {
                invDateObj = firstNavDate;
            }
        }
    } catch (e) { /* Fallback to entered date if history fails */ }

    const now = new Date();
    now.setHours(0, 0, 0, 0);
    const years = (now - invDateObj) / (1000 * 60 * 60 * 24 * 365.25);

    if (years <= 0 || investment.investmentAmount <= 0) return 0;
    const val = investment.units * currentNAV;
    let cagr = (Math.pow(val / investment.investmentAmount, 1 / years) - 1) * 100;
    if (cagr > 100000) cagr = 100000;
    return cagr;
}
