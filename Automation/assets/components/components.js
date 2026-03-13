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
    
    // If we're in Automation/, go up two levels to root
    if (currentPath.includes('/Automation/')) {
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
        
        // Direct inline header to ensure visibility
        headerPlaceholder.innerHTML = `
            <header style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 12px 0; margin: 0; width: 100%; box-shadow: 0 2px 4px rgba(0,0,0,0.1); display: block !important; visibility: visible !important;">
                <div style="max-width: 1200px; margin: 0 auto; padding: 0 20px; display: flex; align-items: center; justify-content: space-between;">
                    <a href="../../index.html" class="home-link" style="color: white; text-decoration: none; display: flex; align-items: center; gap: 8px; padding: 6px 12px; border-radius: 6px; transition: opacity 0.3s ease;">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                            <path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"/>
                        </svg>
                        <span style="font-size: 14px; font-weight: 500;">Home</span>
                    </a>
                    <button class="hamburger" onclick="toggleMenu()" style="background: none; border: none; color: white; cursor: pointer; padding: 6px;">
                        <span style="display: block; width: 20px; height: 2px; background: white; margin: 3px 0; transition: 0.3s;"></span>
                        <span style="display: block; width: 20px; height: 2px; background: white; margin: 3px 0; transition: 0.3s;"></span>
                        <span style="display: block; width: 20px; height: 2px; background: white; margin: 3px 0; transition: 0.3s;"></span>
                    </button>
                </div>
            </header>
        `;
        
        console.log('Header set with inline content');
        
        // Update home link dynamically
        const homeLink = headerPlaceholder.querySelector('.home-link');
        if (homeLink) {
            const pathSegments = window.location.pathname.split('/').filter(segment => segment);
            const upLevels = pathSegments.length; // Go up to root
            homeLink.href = '../'.repeat(upLevels) + 'index.html';
        }
        
        // Try to load external header (but fallback to inline is already set)
        const basePath = getBasePath();
        console.log('Attempting to load external header from:', basePath + 'header.html');
        
        fetch(basePath + 'header.html')
            .then(response => {
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                return response.text();
            })
            .then(html => {
                console.log('External header loaded, replacing inline');
                headerPlaceholder.innerHTML = html;
                
                // Add mobile menu after header is loaded
                document.body.insertAdjacentHTML('afterbegin', '<div id="mobile-menu" class="mobile-menu" style="display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 1000;"><div class="menu-content" style="position: absolute; top: 60px; right: 20px; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); max-width: 300px;"><h4>Main Navigation</h4><ul style="list-style: none; padding: 0;"><li style="margin-bottom: 8px;"><a href="../Beginner/B-Intro.html" style="color: #333; text-decoration: none;">Beginner</a></li><li style="margin-bottom: 8px;"><a href="../Intermediate/I-Intro.html" style="color: #333; text-decoration: none;">Intermediate</a></li><li style="margin-bottom: 8px;"><a href="../Advanced/A-Intro.html" style="color: #333; text-decoration: none;">Advanced</a></li></ul><h4>Learning Resources</h4><ul style="list-style: none; padding: 0;"><li style="margin-bottom: 8px;"><a href="https://www.selenium.dev/documentation/" target="_blank" style="color: #333; text-decoration: none;">Selenium Documentation</a></li><li style="margin-bottom: 8px;"><a href="https://playwright.dev/docs/intro" target="_blank" style="color: #333; text-decoration: none;">Playwright Docs</a></li></ul><h4>Testing Tools</h4><ul style="list-style: none; padding: 0;"><li style="margin-bottom: 8px;"><a href="https://www.cypress.io/" target="_blank" style="color: #333; text-decoration: none;">Cypress</a></li><li style="margin-bottom: 8px;"><a href="https://testcafe.io/" target="_blank" style="color: #333; text-decoration: none;">TestCafe</a></li></ul></div></div>');
            })
            .catch(error => {
                console.log('External header failed, keeping inline header:', error.message);
                
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
