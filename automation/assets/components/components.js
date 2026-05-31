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
                const menuHtml = `<div id="mobile-menu" class="mobile-menu" style="display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 1000;"><div class="menu-content" style="position: absolute; top: 60px; right: 20px; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); max-width: 300px;"><h4>Main Navigation</h4><ul style="list-style: none; padding: 0;"><li style="margin-bottom: 8px;"><a href="${basePath}automation/practices/beginner/b-1.01-click.html" style="color: #333; text-decoration: none;">Beginner</a></li><li style="margin-bottom: 8px;"><a href="${basePath}automation/practices/intermediate/i-2.01-draganddroptext.html" style="color: #333; text-decoration: none;">Intermediate</a></li><li style="margin-bottom: 8px;"><a href="${basePath}automation/practices/advanced/a-3.01-hiddenelement.html" style="color: #333; text-decoration: none;">Advanced</a></li></ul><h4>Learning Resources</h4><ul style="list-style: none; padding: 0;"><li style="margin-bottom: 8px;"><a href="https://www.selenium.dev/documentation/" target="_blank" style="color: #333; text-decoration: none;">Selenium Documentation</a></li><li style="margin-bottom: 8px;"><a href="https://playwright.dev/docs/intro" target="_blank" style="color: #333; text-decoration: none;">Playwright Docs</a></li></ul><h4>Testing Tools</h4><ul style="list-style: none; padding: 0;"><li style="margin-bottom: 8px;"><a href="https://www.cypress.io/" target="_blank" style="color: #333; text-decoration: none;">Cypress</a></li><li style="margin-bottom: 8px;"><a href="https://testcafe.io/" target="_blank" style="color: #333; text-decoration: none;">TestCafe</a></li></ul></div></div>`;
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
    const menuContent = document.querySelector('.menu-content');
    if (!menuContent.contains(event.target)) {
        toggleMenu();
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
