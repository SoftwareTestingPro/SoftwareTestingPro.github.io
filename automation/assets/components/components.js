// Load header and footer components
document.addEventListener('DOMContentLoaded', function() {
    console.log('DOM loaded, starting component loading');
    loadHeader();
    loadFooter();
});

// Determine the correct path to header/footer based on current location
// Determine the correct path to header/footer based on current location
function getBasePath() {
    const pathname = window.location.pathname;
    const parts = pathname.split('/').filter(segment => segment);
    
    let depth = parts.length;
    if (parts.length > 0 && parts[parts.length - 1].includes('.')) {
        depth -= 1;
    }
    
    if (depth <= 0) return './';
    
    let path = '';
    for (let i = 0; i < depth; i++) {
        path += '../';
    }
    return path;
}

function loadHeader() {
    const headerPlaceholder = document.getElementById('header-placeholder');
    if (headerPlaceholder) {
        const basePath = getBasePath();
        
        fetch(basePath + 'header.html')
            .then(response => {
                if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
                return response.text();
            })
            .then(html => {
                if (html && html.includes('site-header')) {
                    headerPlaceholder.innerHTML = html;
                    
                    const links = headerPlaceholder.querySelectorAll('a');
                    links.forEach(link => {
                        const href = link.getAttribute('href');
                        if (href && !href.startsWith('http') && !href.startsWith('/')) {
                            link.href = basePath + href;
                        }
                    });
                }
                
                // Add mobile menu (links are relative to root directory, so prefix with automation/)
                const menuHtml = `
<style>
    .mobile-menu-overlay {
        display: none;
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(10, 10, 20, 0.7);
        backdrop-filter: blur(8px);
        z-index: 10000;
        transition: all 0.3s ease;
    }
    .mobile-menu-card {
        position: absolute;
        top: 70px;
        right: 20px;
        background: #0f0f23;
        border: 1px solid rgba(0, 255, 255, 0.4);
        box-shadow: 0 0 20px rgba(0, 255, 255, 0.15), inset 0 0 10px rgba(0, 255, 255, 0.05);
        border-radius: 12px;
        padding: 24px;
        width: 300px;
        font-family: 'Outfit', sans-serif;
        color: #ffffff;
        box-sizing: border-box;
        overflow: hidden;
    }
    .mobile-menu-card h4 {
        color: #ff00ff;
        font-size: 12px;
        text-transform: uppercase;
        letter-spacing: 1.5px;
        margin-top: 0;
        margin-bottom: 12px;
        border-bottom: 1px solid rgba(255, 0, 255, 0.2);
        padding-bottom: 6px;
        text-shadow: 0 0 10px rgba(255, 0, 255, 0.5);
    }
    .mobile-menu-list {
        list-style: none;
        padding: 0;
        margin: 0 0 20px 0;
    }
    .mobile-menu-list:last-child {
        margin-bottom: 0;
    }
    .mobile-menu-list li {
        margin-bottom: 8px;
    }
    .mobile-menu-item {
        color: #e2e8f0;
        text-decoration: none;
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 6px 0;
        font-size: 14px;
        font-weight: 500;
        transition: all 0.2s ease;
        cursor: pointer;
    }
    .mobile-menu-item:hover {
        color: #00ffff;
        text-shadow: 0 0 8px rgba(0, 255, 255, 0.8);
        transform: translateX(4px);
    }
    .mobile-dropdown-arrow {
        font-size: 10px;
        margin-left: auto;
        transition: transform 0.2s ease;
        color: rgba(0, 255, 255, 0.7);
    }
    .mobile-dropdown-menu {
        display: none;
        list-style: none;
        padding-left: 16px;
        margin-top: 4px;
        border-left: 1px solid rgba(0, 255, 255, 0.2);
    }
    .mobile-dropdown-menu li {
        margin-bottom: 6px;
    }
    .mobile-submenu-item {
        color: #94a3b8;
        text-decoration: none;
        display: block;
        padding: 4px 0;
        font-size: 13px;
        transition: all 0.2s ease;
    }
    .mobile-submenu-item:hover {
        color: #ff00ff;
        text-shadow: 0 0 8px rgba(255, 0, 255, 0.8);
        transform: translateX(4px);
    }
</style>
<div id="mobile-menu" class="mobile-menu-overlay">
    <div class="mobile-menu-card">
        <h4>Modules &amp; Apps</h4>
        <ul class="mobile-menu-list">
            <li>
                <div onclick="event.stopPropagation(); toggleAutomationDropdown()" class="mobile-menu-item">
                    <span>🤖 Automation Hub</span>
                    <span id="auto-arrow" class="mobile-dropdown-arrow">&#9654;</span>
                </div>
                <ul id="automation-dropdown" class="mobile-dropdown-menu">
                    <li><a href="${basePath}automation/index.html" class="mobile-submenu-item">Overview Dashboard</a></li>
                    <li><a href="${basePath}automation/practices/beginner/b-1.01-click.html" class="mobile-submenu-item">Beginner Tasks</a></li>
                    <li><a href="${basePath}automation/practices/intermediate/i-2.01-draganddroptext.html" class="mobile-submenu-item">Intermediate Tasks</a></li>
                    <li><a href="${basePath}automation/practices/advanced/a-3.01-hiddenelement.html" class="mobile-submenu-item">Advanced Tasks</a></li>
                </ul>
            </li>
            <li><a href="${basePath}compiler/index.html" class="mobile-menu-item">💻 DevCompiler IDE</a></li>
            <li><a href="${basePath}quiz/index.html" class="mobile-menu-item">📝 Quiz Master</a></li>
            <li>
                <div onclick="event.stopPropagation(); toggleHealthcareDropdown()" class="mobile-menu-item">
                    <span>💠 Shukla Healthcare</span>
                    <span id="health-arrow" class="mobile-dropdown-arrow">&#9654;</span>
                </div>
                <ul id="healthcare-dropdown" class="mobile-dropdown-menu">
                    <li><a href="${basePath}healthcare/index.html" class="mobile-submenu-item">Landing Portal</a></li>
                    <li><a href="${basePath}healthcare/app/index.html" class="mobile-submenu-item">SQL Practice Studio</a></li>
                </ul>
            </li>
            <li><a href="${basePath}library-api/index.html" class="mobile-menu-item">📚 Library API Sandbox</a></li>
        </ul>
        
        <h4>General Links</h4>
        <ul class="mobile-menu-list">
            <li><a href="${basePath}index.html" class="mobile-menu-item">🏠 Portfolio Home</a></li>
            <li><a href="${basePath}developer.html" class="mobile-menu-item">👨‍💻 About Developer</a></li>
            <li><a href="${basePath}automation/faq.html" class="mobile-menu-item">❓ FAQ Help</a></li>
        </ul>
    </div>
</div>`;
                document.body.insertAdjacentHTML('afterbegin', menuHtml);
            })
            .catch(error => {
                console.log('External header failed:', error.message);
            });
    }
}

function loadFooter() {
    const footerPlaceholder = document.getElementById('footer-placeholder');
    if (footerPlaceholder) {
        const basePath = getBasePath();
        
        fetch(basePath + 'footer.html')
            .then(response => {
                if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
                return response.text();
            })
            .then(html => {
                footerPlaceholder.innerHTML = html;
                
                const links = footerPlaceholder.querySelectorAll('a');
                links.forEach(link => {
                    const href = link.getAttribute('href');
                    if (href && !href.startsWith('http') && !href.startsWith('/')) {
                        link.href = basePath + href;
                    }
                });
                
                // Fetch and update visitor count
                updateVisitorCounter();
            })
            .catch(error => {
                console.log('External footer failed:', error.message);
            });
    }
}

function updateVisitorCounter() {
    const visitorCountEl = document.getElementById('visitor-count');
    if (!visitorCountEl) return;
    
    const startingOffset = 14324; // Since the API starts at 1, setting offset to 14,324 results in starting at 14,325
    
    // We increment the count on every page view/load by hitting the 'up' API of counterapi.dev
    // Namespace: softwaretestingpro, Key: visits
    fetch('https://api.counterapi.dev/v1/softwaretestingpro/visits/up')
        .then(response => {
            if (!response.ok) throw new Error('Network response was not ok');
            return response.json();
        })
        .then(data => {
            if (data && typeof data.value === 'number') {
                const totalCount = data.value + startingOffset;
                visitorCountEl.textContent = totalCount.toLocaleString();
            } else {
                throw new Error('Invalid data structure');
            }
        })
        .catch(error => {
            console.error('Error fetching visitor count:', error);
            // Fallback: Display a dynamic mock/simulated count starting at 14,325
            const baseValue = 14325;
            const simulatedCount = baseValue + Math.floor((Date.now() - Date.parse("2026-05-31T00:00:00Z")) / 10000);
            visitorCountEl.textContent = simulatedCount.toLocaleString();
        });
}

function toggleMenu() {
    const menu = document.getElementById('mobile-menu');
    if (menu.style.display === 'none' || menu.style.display === '') {
        menu.style.display = 'block';
        // Add event listener to close on outside click
        menu.addEventListener('click', closeMenuOnOutsideClick);
    } else {
        menu.style.display = 'none';
        // Remove event listener
        menu.removeEventListener('click', closeMenuOnOutsideClick);
    }
}

function closeMenuOnOutsideClick(event) {
    const menuContent = document.querySelector('.mobile-menu-card');
    if (menuContent && !menuContent.contains(event.target)) {
        toggleMenu();
    }
}

function toggleAutomationDropdown() {
    const dropdown = document.getElementById('automation-dropdown');
    const arrow = document.getElementById('auto-arrow');
    if (dropdown.style.display === 'none' || dropdown.style.display === '') {
        dropdown.style.display = 'block';
        arrow.style.transform = 'rotate(90deg)';
    } else {
        dropdown.style.display = 'none';
        arrow.style.transform = 'rotate(0deg)';
    }
}

function toggleHealthcareDropdown() {
    const dropdown = document.getElementById('healthcare-dropdown');
    const arrow = document.getElementById('health-arrow');
    if (dropdown.style.display === 'none' || dropdown.style.display === '') {
        dropdown.style.display = 'block';
        arrow.style.transform = 'rotate(90deg)';
    } else {
        dropdown.style.display = 'none';
        arrow.style.transform = 'rotate(0deg)';
    }
}

// Back to Top functionality
function createBackToTopButton() {
    // Check if button already exists
    if (document.getElementById('backToTop')) {
        return;
    }

    // Create back to top button
    const backToTopButton = document.createElement('button');
    backToTopButton.id = 'backToTop';
    backToTopButton.className = 'back-to-top';
    backToTopButton.title = 'Back to top';
    backToTopButton.innerHTML = '<span class="back-to-top-icon">↑</span>';
    backToTopButton.onclick = scrollToTop;

    // Add to body
    document.body.appendChild(backToTopButton);

    // Initialize state
    backToTopButton.style.display = 'none';
    backToTopButton.style.opacity = '0';
}

function scrollToTop() {
    window.scrollTo({
        top: 0,
        behavior: 'smooth'
    });
}

// Show/hide back to top button based on scroll position
function handleBackToTopScroll() {
    const backToTopButton = document.getElementById('backToTop');
    if (backToTopButton) {
        if (window.pageYOffset > 300) {
            backToTopButton.style.display = 'block';
            setTimeout(() => {
                backToTopButton.style.opacity = '1';
            }, 10);
        } else {
            backToTopButton.style.opacity = '0';
            setTimeout(() => {
                if (window.pageYOffset <= 300) {
                    backToTopButton.style.display = 'none';
                }
            }, 300);
        }
    }
}

// Initialize back to top when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    createBackToTopButton();
    
    // Add scroll listener
    window.addEventListener('scroll', handleBackToTopScroll);
});
