// Load header and footer components
document.addEventListener('DOMContentLoaded', function() {
    console.log('DOM loaded, starting component loading');
    loadHeader();
    loadFooter();
});

// Determine the correct path to header/footer based on current location
function getBasePath() {
    const currentPath = window.location.pathname;
    console.log('Current path:', currentPath);
    
    // Count the number of directory levels
    const pathSegments = currentPath.split('/').filter(segment => segment);
    console.log('Path segments:', pathSegments);
    
    // If we're in Automation/Beginner/, go up three levels to root
    if (currentPath.includes('/Automation/Beginner/')) {
        return '../../../';
    }
    // If we're in Automation/, go up two levels to root
    else if (currentPath.includes('/Automation/')) {
        return '../../';
    }
    // Default to root level
    else {
        return '';
    }
}

function loadHeader() {
    const headerPlaceholder = document.getElementById('header-placeholder');
    if (headerPlaceholder) {
        console.log('Header placeholder found');
        
        // Set minimal header immediately to prevent empty state
        const basePath = getBasePath();
        headerPlaceholder.innerHTML = `
            <header class="site-header">
                <div class="header-content">
                    <a href="${basePath}index.html" class="home-link" title="Home">
                        <svg class="home-icon" viewBox="0 0 24 24" fill="currentColor">
                            <path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"/>
                        </svg>
                        <span class="home-text">Home</span>
                    </a>
                    <button class="hamburger" onclick="toggleMenu()">
                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2">
                            <line x1="3" y1="6" x2="21" y2="6"></line>
                            <line x1="3" y1="12" x2="21" y2="12"></line>
                            <line x1="3" y1="18" x2="21" y2="18"></line>
                        </svg>
                    </button>
                </div>
            </header>
        `;
        
        console.log('Minimal header set immediately');
        
        // Try to load external header
        console.log('Attempting to load external header from:', basePath + 'header.html');
        
        fetch(basePath + 'header.html')
            .then(response => {
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                return response.text();
            })
            .then(html => {
                console.log('External header loaded successfully');
                // Only replace if external header is valid and has content
                if (html && html.includes('site-header')) {
                    console.log('Replacing with external header');
                    headerPlaceholder.innerHTML = html;
                    
                    // Update home link dynamically for external header
                    const homeLink = headerPlaceholder.querySelector('.home-link');
                    if (homeLink) {
                        homeLink.href = basePath + 'index.html';
                    }
                } else {
                    console.log('External header invalid, keeping minimal header');
                }
                
                // Add mobile menu after header is loaded
                document.body.insertAdjacentHTML('afterbegin', '<div id="mobile-menu" class="mobile-menu" style="display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 1000;"><div class="menu-content" style="position: absolute; top: 60px; right: 20px; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); max-width: 300px;"><h4>Main Navigation</h4><ul style="list-style: none; padding: 0;"><li style="margin-bottom: 8px;"><a href="../Beginner/B-Intro.html" style="color: #333; text-decoration: none;">Beginner</a></li><li style="margin-bottom: 8px;"><a href="../Intermediate/I-Intro.html" style="color: #333; text-decoration: none;">Intermediate</a></li><li style="margin-bottom: 8px;"><a href="../Advanced/A-Intro.html" style="color: #333; text-decoration: none;">Advanced</a></li></ul><h4>Learning Resources</h4><ul style="list-style: none; padding: 0;"><li style="margin-bottom: 8px;"><a href="https://www.selenium.dev/documentation/" target="_blank" style="color: #333; text-decoration: none;">Selenium Documentation</a></li><li style="margin-bottom: 8px;"><a href="https://playwright.dev/docs/intro" target="_blank" style="color: #333; text-decoration: none;">Playwright Docs</a></li></ul><h4>Testing Tools</h4><ul style="list-style: none; padding: 0;"><li style="margin-bottom: 8px;"><a href="https://www.cypress.io/" target="_blank" style="color: #333; text-decoration: none;">Cypress</a></li><li style="margin-bottom: 8px;"><a href="https://testcafe.io/" target="_blank" style="color: #333; text-decoration: none;">TestCafe</a></li></ul></div></div>');
            })
            .catch(error => {
                console.log('External header failed, keeping minimal header:', error.message);
                
                // Add mobile menu after header is loaded (fallback)
                document.body.insertAdjacentHTML('afterbegin', '<div id="mobile-menu" class="mobile-menu" style="display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 1000;"><div class="menu-content" style="position: absolute; top: 60px; right: 20px; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); max-width: 300px;"><h4>Main Navigation</h4><ul style="list-style: none; padding: 0;"><li style="margin-bottom: 8px;"><a href="../Beginner/B-Intro.html" style="color: #333; text-decoration: none;">Beginner</a></li><li style="margin-bottom: 8px;"><a href="../Intermediate/I-Intro.html" style="color: #333; text-decoration: none;">Intermediate</a></li><li style="margin-bottom: 8px;"><a href="../Advanced/A-Intro.html" style="color: #333; text-decoration: none;">Advanced</a></li></ul><h4>Learning Resources</h4><ul style="list-style: none; padding: 0;"><li style="margin-bottom: 8px;"><a href="https://www.selenium.dev/documentation/" target="_blank" style="color: #333; text-decoration: none;">Selenium Documentation</a></li><li style="margin-bottom: 8px;"><a href="https://playwright.dev/docs/intro" target="_blank" style="color: #333; text-decoration: none;">Playwright Docs</a></li></ul><h4>Testing Tools</h4><ul style="list-style: none; padding: 0;"><li style="margin-bottom: 8px;"><a href="https://www.cypress.io/" target="_blank" style="color: #333; text-decoration: none;">Cypress</a></li><li style="margin-bottom: 8px;"><a href="https://testcafe.io/" target="_blank" style="color: #333; text-decoration: none;">TestCafe</a></li></ul></div></div>');
            });
    } else {
        console.log('Header placeholder NOT found');
    }
}

function loadFooter() {
    const footerPlaceholder = document.getElementById('footer-placeholder');
    if (footerPlaceholder) {
        console.log('Footer placeholder found');
        
        // Direct inline footer to ensure visibility
        footerPlaceholder.innerHTML = `
            <footer style="background: linear-gradient(135deg, #2c3e50 0%, #34495e 100%); color: #ecf0f1; padding: 40px 0 20px; margin-top: 40px; width: 100%; display: block !important; visibility: visible !important;">
                <div style="max-width: 1200px; margin: 0 auto; padding: 0 20px; display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 30px;">
                    <div>
                        <h4 style="color: #3498db; margin-bottom: 15px; font-size: 16px; font-weight: 600; border-bottom: 2px solid #3498db; padding-bottom: 5px;">Learning Resources</h4>
                        <ul style="list-style: none; padding: 0; margin: 0;">
                            <li style="margin-bottom: 8px;"><a href="https://www.selenium.dev/documentation/" target="_blank" style="color: #bdc3c7; text-decoration: none; font-size: 14px;">Selenium Documentation</a></li>
                            <li style="margin-bottom: 8px;"><a href="https://playwright.dev/docs/intro" target="_blank" style="color: #bdc3c7; text-decoration: none; font-size: 14px;">Playwright Docs</a></li>
                        </ul>
                    </div>
                    <div>
                        <h4 style="color: #3498db; margin-bottom: 15px; font-size: 16px; font-weight: 600; border-bottom: 2px solid #3498db; padding-bottom: 5px;">Testing Tools</h4>
                        <ul style="list-style: none; padding: 0; margin: 0;">
                            <li style="margin-bottom: 8px;"><a href="https://www.cypress.io/" target="_blank" style="color: #bdc3c7; text-decoration: none; font-size: 14px;">Cypress</a></li>
                            <li style="margin-bottom: 8px;"><a href="https://testcafe.io/" target="_blank" style="color: #bdc3c7; text-decoration: none; font-size: 14px;">TestCafe</a></li>
                        </ul>
                    </div>
                </div>
                <div style="max-width: 1200px; margin: 30px auto 0; padding: 20px; border-top: 1px solid #34495e; text-align: center;">
                    <p style="margin: 0; font-size: 13px; color: #95a5a6;">&copy; 2024 Software Testing Pro. Educational content for automation testing.</p>
                </div>
            </footer>
        `;
        
        console.log('Footer set with inline content');
        
        // Try to load external footer
        const basePath = getBasePath();
        console.log('Attempting to load external footer from:', basePath + 'footer.html');
        
        fetch(basePath + 'footer.html')
            .then(response => {
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                return response.text();
            })
            .then(html => {
                console.log('External footer loaded, replacing inline');
                footerPlaceholder.innerHTML = html;
            })
            .catch(error => {
                console.log('External footer failed, keeping inline footer:', error.message);
            });
    } else {
        console.log('Footer placeholder NOT found');
    }
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
