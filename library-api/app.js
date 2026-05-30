// Library API Playground Script
const fetchBtn = document.getElementById('fetch-btn');
const booksList = document.getElementById('books-list');
const resultsCount = document.getElementById('results-count');

// GET Filter Inputs
const filterSubject = document.getElementById('filter-subject');
const filterAuthor = document.getElementById('filter-author');
const filterMinPages = document.getElementById('filter-min-pages');
const filterMaxPages = document.getElementById('filter-max-pages');
const filterMinPrice = document.getElementById('filter-min-price');
const filterMaxPrice = document.getElementById('filter-max-price');
const filterMinYear = document.getElementById('filter-min-year');
const filterMaxYear = document.getElementById('filter-max-year');

// POST Book Inputs
const postTitle = document.getElementById('post-title');
const postAuthor = document.getElementById('post-author');
const postSubject = document.getElementById('post-subject');
const postPages = document.getElementById('post-pages');
const postPrice = document.getElementById('post-price');
const postYear = document.getElementById('post-year');

// PUT Book Inputs
const putId = document.getElementById('put-id');
const putTitle = document.getElementById('put-title');
const putAuthor = document.getElementById('put-author');
const putSubject = document.getElementById('put-subject');
const putPages = document.getElementById('put-pages');
const putPrice = document.getElementById('put-price');
const putYear = document.getElementById('put-year');

// DELETE Book Inputs
const deleteId = document.getElementById('delete-id');

// Authentication & Custom Headers DOM Elements
const btnAuthBasic = document.getElementById('btn-auth-basic');
const btnAuthOauth = document.getElementById('btn-auth-oauth');
const fieldsBasic = document.getElementById('auth-fields-basic');
const fieldsOauth = document.getElementById('auth-fields-oauth');

const inputUsername = document.getElementById('auth-username');
const inputPassword = document.getElementById('auth-password');
const inputToken = document.getElementById('auth-token');

const customHeaderKey = document.getElementById('custom-header-key');
const customHeaderValue = document.getElementById('custom-header-value');
const customRequestBody = document.getElementById('custom-request-body');

// HTTP Method DOM Elements
const btnMethodGet = document.getElementById('btn-method-get');
const btnMethodPost = document.getElementById('btn-method-post');
const btnMethodPut = document.getElementById('btn-method-put');
const btnMethodDelete = document.getElementById('btn-method-delete');
const sectionGetFilters = document.getElementById('section-get-filters');
const sectionPostFields = document.getElementById('section-post-fields');
const sectionPutFields = document.getElementById('section-put-fields');
const sectionDeleteFields = document.getElementById('section-delete-fields');

let activeAuthMode = 'basic'; // 'basic' or 'oauth'
let activeMethodMode = 'get'; // 'get', 'post', 'put', 'delete'

const isLocal = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';

// Global session book database cache
let sessionBooks = [];

// Load the initial database at startup
async function loadInitialDatabase() {
    try {
        if (!isLocal) {
            const localData = localStorage.getItem('library_books');
            if (localData) {
                sessionBooks = JSON.parse(localData);
                resultsCount.textContent = sessionBooks.length;
                renderBooks(sessionBooks);
                return;
            }
        }
        
        const response = await fetch('./api/v1/books.json');
        if (response.ok) {
            sessionBooks = await response.json();
            if (!isLocal) {
                localStorage.setItem('library_books', JSON.stringify(sessionBooks));
            }
            resultsCount.textContent = sessionBooks.length;
            renderBooks(sessionBooks);
        }
    } catch (err) {
        console.error('Failed to load startup database:', err);
    }
}

// Method toggle logic
function resetMethodUI() {
    btnMethodGet.classList.remove('active');
    btnMethodPost.classList.remove('active');
    btnMethodPut.classList.remove('active');
    btnMethodDelete.classList.remove('active');

    sectionGetFilters.classList.add('hidden');
    sectionPostFields.classList.add('hidden');
    sectionPutFields.classList.add('hidden');
    sectionDeleteFields.classList.add('hidden');
    
    // Reset any custom button backgrounds
    fetchBtn.style.background = '';
    fetchBtn.style.color = '';
}

btnMethodGet.addEventListener('click', () => {
    activeMethodMode = 'get';
    resetMethodUI();
    btnMethodGet.classList.add('active');
    sectionGetFilters.classList.remove('hidden');
    
    // Update fetch button
    fetchBtn.className = 'btn btn-run';
    fetchBtn.innerHTML = `<i class="fa-solid fa-cloud-arrow-down"></i> Fetch Books`;
});

btnMethodPost.addEventListener('click', () => {
    activeMethodMode = 'post';
    resetMethodUI();
    btnMethodPost.classList.add('active');
    sectionPostFields.classList.remove('hidden');
    
    // Update fetch button
    fetchBtn.className = 'btn btn-run btn-post';
    fetchBtn.innerHTML = `<i class="fa-solid fa-square-plus"></i> Add Book`;
});

btnMethodPut.addEventListener('click', () => {
    activeMethodMode = 'put';
    resetMethodUI();
    btnMethodPut.classList.add('active');
    sectionPutFields.classList.remove('hidden');
    
    // Update fetch button
    fetchBtn.className = 'btn btn-run';
    fetchBtn.style.background = 'linear-gradient(135deg, #a855f7, #7c3aed)';
    fetchBtn.style.color = '#ffffff';
    fetchBtn.innerHTML = `<i class="fa-solid fa-pen-to-square"></i> Update Book`;
});

btnMethodDelete.addEventListener('click', () => {
    activeMethodMode = 'delete';
    resetMethodUI();
    btnMethodDelete.classList.add('active');
    sectionDeleteFields.classList.remove('hidden');
    
    // Update fetch button
    fetchBtn.className = 'btn btn-run';
    fetchBtn.style.background = 'linear-gradient(135deg, #ef4444, #dc2626)';
    fetchBtn.style.color = '#ffffff';
    fetchBtn.innerHTML = `<i class="fa-solid fa-trash-can"></i> Delete Book`;
});

// Auth Toggle button logic
btnAuthBasic.addEventListener('click', () => {
    activeAuthMode = 'basic';
    btnAuthBasic.classList.add('active');
    btnAuthOauth.classList.remove('active');
    fieldsBasic.style.display = 'contents';
    fieldsOauth.style.display = 'none';
});

btnAuthOauth.addEventListener('click', () => {
    activeAuthMode = 'oauth';
    btnAuthOauth.classList.add('active');
    btnAuthBasic.classList.remove('active');
    fieldsOauth.style.display = 'contents';
    fieldsBasic.style.display = 'none';
});

// Main Action Trigger (Fetch / Add)
fetchBtn.addEventListener('click', async () => {
    // Perform Authentication Validation first!
    let authHeaderValue = '';
    if (activeAuthMode === 'basic') {
        const username = inputUsername.value.trim();
        const password = inputPassword.value.trim();
        
        if (username !== "library_admin" || password !== "admin_secure_123") {
            renderError("401 Unauthorized", "Basic Authentication Failed: Invalid Username or Password.", "Verify credentials match: Username 'library_admin' & Password 'admin_secure_123'.");
            return;
        }
        
        const encoded = btoa(`${username}:${password}`);
        authHeaderValue = `Basic ${encoded}`;
    } else {
        const token = inputToken.value.trim();
        
        if (token !== "lib_bearer_token_98765") {
            renderError("401 Unauthorized", "OAuth 2.0 Authentication Failed: Invalid Bearer Token.", "Verify token matches: 'lib_bearer_token_98765'.");
            return;
        }
        
        authHeaderValue = `Bearer ${token}`;
    }

    // Construct Headers
    const headers = {
        'Authorization': authHeaderValue,
        'Accept': 'application/json',
        'Content-Type': 'application/json'
    };

    // Append optional custom header
    const headerKey = customHeaderKey.value.trim();
    const headerValue = customHeaderValue.value.trim();
    if (headerKey && headerValue) {
        headers[headerKey] = headerValue;
    }

    if (activeMethodMode === 'get') {
        await handleGetRequest(headers);
    } else if (activeMethodMode === 'post') {
        await handlePostRequest(headers);
    } else if (activeMethodMode === 'put') {
        await handlePutRequest(headers);
    } else if (activeMethodMode === 'delete') {
        await handleDeleteRequest(headers);
    }
});

// GET Request Handler
async function handleGetRequest(headers) {
    const subject = filterSubject.value;
    const author = filterAuthor.value;
    const minPages = filterMinPages.value;
    const maxPages = filterMaxPages.value;
    const minPrice = filterMinPrice.value;
    const maxPrice = filterMaxPrice.value;
    const minYear = filterMinYear.value;
    const maxYear = filterMaxYear.value;

    // Build URL Query String parameters to display in the Network Tab
    const queryParams = new URLSearchParams();
    if (subject) queryParams.append('subject', subject);
    if (author) queryParams.append('author', author);
    if (minPages) queryParams.append('minPages', minPages);
    if (maxPages) queryParams.append('maxPages', maxPages);
    if (minPrice) queryParams.append('minPrice', minPrice);
    if (maxPrice) queryParams.append('maxPrice', maxPrice);
    if (minYear) queryParams.append('minYear', minYear);
    if (maxYear) queryParams.append('maxYear', maxYear);

    const queryString = queryParams.toString();
    const fetchUrl = `./api/v1/books.json${queryString ? '?' + queryString : ''}`;

    fetchBtn.disabled = true;
    fetchBtn.innerHTML = `<i class="fa-solid fa-spinner fa-spin"></i> Querying Database...`;

    try {
        // Send actual fetch - auth, custom headers, and query params will show in Network Tab!
        const response = await fetch(fetchUrl, {
            method: 'GET',
            headers: headers
        });

        if (!response.ok) {
            throw new Error(`Server returned HTTP ${response.status}`);
        }

        if (isLocal) {
            sessionBooks = await response.json();
            renderBooks(sessionBooks);
        } else {
            // Apply dynamic client-side filtering on session catalog for static hosting
            const filteredBooks = sessionBooks.filter(book => {
                if (subject && book.subject !== subject) return false;
                if (author && book.author !== author) return false;
                
                if (minPages && book.pages < parseInt(minPages)) return false;
                if (maxPages && book.pages > parseInt(maxPages)) return false;
                
                if (minPrice && book.price < parseFloat(minPrice)) return false;
                if (maxPrice && book.price > parseFloat(maxPrice)) return false;
                
                if (minYear && book.published_year < parseInt(minYear)) return false;
                if (maxYear && book.published_year > parseInt(maxYear)) return false;
                
                return true;
            });

            renderBooks(filteredBooks);
        }

    } catch (err) {
        console.error('API query failure:', err);
        renderError("500 Internal Server Error", `Failed to fetch catalog: ${err.message}`, "Check network connections.");
    } finally {
        fetchBtn.disabled = false;
        fetchBtn.className = 'btn btn-run';
        fetchBtn.innerHTML = `<i class="fa-solid fa-cloud-arrow-down"></i> Fetch Books`;
    }
}

// POST Request Handler
async function handlePostRequest(headers) {
    const title = postTitle.value.trim();
    const author = postAuthor.value.trim();
    const subject = postSubject.value;
    const pages = parseInt(postPages.value);
    const price = parseFloat(postPrice.value);
    const year = parseInt(postYear.value);

    // 1. Client-Side Input validations
    if (!title || !author || isNaN(pages) || isNaN(price) || isNaN(year)) {
        renderError("400 Bad Request", "Missing or invalid book parameters. All fields are required.", "Verify title, author, and ranges are filled with positive values.");
        return;
    }

    const newBook = {
        id: sessionBooks.length + 1,
        title: title,
        author: author,
        subject: subject,
        pages: pages,
        price: price,
        published_year: year
    };

    fetchBtn.disabled = true;
    fetchBtn.innerHTML = `<i class="fa-solid fa-spinner fa-spin"></i> Adding Book...`;

    try {
        const response = await fetch('./api/v1/books.json', {
            method: 'POST',
            headers: headers,
            body: JSON.stringify(newBook)
        });

        if (isLocal) {
            if (!response.ok) {
                throw new Error(`Server returned HTTP ${response.status}`);
            }
            const savedBook = await response.json();
            // sync our global session state
            sessionBooks.unshift(savedBook);
            newBook.id = savedBook.id; // ensure ID matches the database
        } else {
            // Hosted static site: prepend to sessionBooks & update localStorage
            newBook.id = sessionBooks.length > 0 ? Math.max(...sessionBooks.map(b => b.id)) + 1 : 1;
            sessionBooks.unshift(newBook);
            localStorage.setItem('library_books', JSON.stringify(sessionBooks));
        }

        // Render success feedback in UI table
        booksList.innerHTML = `
            <tr>
                <td colspan="7" class="placeholder-row" style="color: var(--tech-color); padding: 40px;">
                    <div style="font-size: 22px; font-weight: 800; margin-bottom: 8px;"><i class="fa-solid fa-square-check"></i> HTTP 201 Created</div>
                    <div style="font-size: 14px; margin-bottom: 12px;">Book successfully added to active catalog database session!</div>
                    <div style="max-width: 500px; margin: 0 auto; background-color: rgba(255,255,255,0.02); border: 1px solid var(--border-color); padding: 16px; border-radius: 8px; text-align: left; font-size: 13px; color: var(--text-primary);">
                        <p><strong>ID:</strong> <code>${newBook.id}</code></p>
                        <p><strong>Title:</strong> ${newBook.title}</p>
                        <p><strong>Author:</strong> ${newBook.author}</p>
                        <p><strong>Subject:</strong> <span class="subject-tag ${newBook.subject.toLowerCase()}" style="font-size: 10px;">${newBook.subject}</span></p>
                        <p><strong>Details:</strong> ${newBook.pages} pages | $${newBook.price.toFixed(2)} | Year ${newBook.published_year}</p>
                    </div>
                    <div style="font-size: 12px; color: var(--text-muted); font-style: italic; margin-top: 16px;">Switch back to "GET - Fetch Books" to search and view your new record!</div>
                </td>
            </tr>
        `;
        resultsCount.textContent = '1';

    } catch (err) {
        console.error('Add book failure:', err);
        renderError("500 Internal Server Error", `Failed to post new book: ${err.message}`, "Check connection.");
    } finally {
        fetchBtn.disabled = false;
        fetchBtn.className = 'btn btn-run btn-post';
        fetchBtn.innerHTML = `<i class="fa-solid fa-square-plus"></i> Add Book`;
    }
}

// PUT Request Handler
async function handlePutRequest(headers) {
    const id = parseInt(putId.value);
    const title = putTitle.value.trim();
    const author = putAuthor.value.trim();
    const subject = putSubject.value;
    const pages = parseInt(putPages.value);
    const price = parseFloat(putPrice.value);
    const year = parseInt(putYear.value);

    // 1. Client-Side validations
    if (isNaN(id)) {
        renderError("400 Bad Request", "Book ID is required for PUT (Update) requests.", "Please enter a valid numeric Book ID.");
        return;
    }

    // Find the book in sessionBooks
    const bookIndex = sessionBooks.findIndex(b => b.id === id);
    if (bookIndex === -1) {
        renderError("404 Not Found", `Book with ID ${id} was not found in the catalog.`, "Verify the ID is correct and exists in the current session.");
        return;
    }

    const originalBook = sessionBooks[bookIndex];
    const updatedBook = {
        id: id,
        title: title || originalBook.title,
        author: author || originalBook.author,
        subject: subject || originalBook.subject,
        pages: !isNaN(pages) ? pages : originalBook.pages,
        price: !isNaN(price) ? price : originalBook.price,
        published_year: !isNaN(year) ? year : originalBook.published_year
    };

    fetchBtn.disabled = true;
    fetchBtn.innerHTML = `<i class="fa-solid fa-spinner fa-spin"></i> Updating Book...`;

    try {
        const response = await fetch(`./api/v1/books.json?id=${id}`, {
            method: 'PUT',
            headers: headers,
            body: JSON.stringify(updatedBook)
        });

        if (isLocal) {
            if (!response.ok) {
                throw new Error(`Server returned HTTP ${response.status}`);
            }
            const savedBook = await response.json();
            sessionBooks[bookIndex] = savedBook;
        } else {
            // Update in sessionBooks and localStorage
            sessionBooks[bookIndex] = updatedBook;
            localStorage.setItem('library_books', JSON.stringify(sessionBooks));
        }

        // Render success feedback in UI table
        booksList.innerHTML = `
            <tr>
                <td colspan="7" class="placeholder-row" style="color: #a855f7; padding: 40px;">
                    <div style="font-size: 22px; font-weight: 800; margin-bottom: 8px;"><i class="fa-solid fa-square-check"></i> HTTP 200 OK</div>
                    <div style="font-size: 14px; margin-bottom: 12px;">Book ID ${id} successfully updated in session catalog!</div>
                    <div style="max-width: 500px; margin: 0 auto; background-color: rgba(255,255,255,0.02); border: 1px solid var(--border-color); padding: 16px; border-radius: 8px; text-align: left; font-size: 13px; color: var(--text-primary);">
                        <p><strong>ID:</strong> <code>${updatedBook.id}</code></p>
                        <p><strong>Title:</strong> ${updatedBook.title} ${title ? '<span style="color:var(--tech-color);font-size:11px;">(Updated)</span>' : ''}</p>
                        <p><strong>Author:</strong> ${updatedBook.author} ${author ? '<span style="color:var(--tech-color);font-size:11px;">(Updated)</span>' : ''}</p>
                        <p><strong>Subject:</strong> <span class="subject-tag ${updatedBook.subject.toLowerCase()}" style="font-size: 10px;">${updatedBook.subject}</span> ${subject ? '<span style="color:var(--tech-color);font-size:11px;">(Updated)</span>' : ''}</p>
                        <p><strong>Details:</strong> ${updatedBook.pages} pages | $${updatedBook.price.toFixed(2)} | Year ${updatedBook.published_year}</p>
                    </div>
                    <div style="font-size: 12px; color: var(--text-muted); font-style: italic; margin-top: 16px;">Switch back to "GET - Fetch Books" to search and view the updated record!</div>
                </td>
            </tr>
        `;
        resultsCount.textContent = '1';

    } catch (err) {
        console.error('Update book failure:', err);
        renderError("500 Internal Server Error", `Failed to update book: ${err.message}`, "Check connection.");
    } finally {
        fetchBtn.disabled = false;
        fetchBtn.className = 'btn btn-run';
        fetchBtn.style.background = 'linear-gradient(135deg, #a855f7, #7c3aed)';
        fetchBtn.style.color = '#ffffff';
        fetchBtn.innerHTML = `<i class="fa-solid fa-pen-to-square"></i> Update Book`;
    }
}

// DELETE Request Handler
async function handleDeleteRequest(headers) {
    const id = parseInt(deleteId.value);

    // 1. Client-Side validations
    if (isNaN(id)) {
        renderError("400 Bad Request", "Book ID is required for DELETE requests.", "Please enter a valid numeric Book ID to delete.");
        return;
    }

    // Find the book in sessionBooks
    const bookIndex = sessionBooks.findIndex(b => b.id === id);
    if (bookIndex === -1) {
        renderError("404 Not Found", `Book with ID ${id} was not found in the catalog.`, "Verify the ID is correct and exists in the current session.");
        return;
    }

    const bookToDelete = sessionBooks[bookIndex];

    fetchBtn.disabled = true;
    fetchBtn.innerHTML = `<i class="fa-solid fa-spinner fa-spin"></i> Deleting Book...`;

    try {
        const response = await fetch(`./api/v1/books.json?id=${id}`, {
            method: 'DELETE',
            headers: headers
        });

        if (isLocal) {
            if (!response.ok) {
                throw new Error(`Server returned HTTP ${response.status}`);
            }
            sessionBooks.splice(bookIndex, 1);
        } else {
            // Delete from sessionBooks and localStorage
            sessionBooks.splice(bookIndex, 1);
            localStorage.setItem('library_books', JSON.stringify(sessionBooks));
        }

        // Render success feedback in UI table
        booksList.innerHTML = `
            <tr>
                <td colspan="7" class="placeholder-row" style="color: #ef4444; padding: 40px;">
                    <div style="font-size: 22px; font-weight: 800; margin-bottom: 8px;"><i class="fa-solid fa-trash-can"></i> HTTP 200 OK (Deleted)</div>
                    <div style="font-size: 14px; margin-bottom: 12px;">Book ID ${id} successfully deleted from session catalog!</div>
                    <div style="max-width: 500px; margin: 0 auto; background-color: rgba(255,255,255,0.02); border: 1px solid var(--border-color); padding: 16px; border-radius: 8px; text-align: left; font-size: 13px; color: var(--text-muted);">
                        <p><strong>ID:</strong> <code>${bookToDelete.id}</code></p>
                        <p><strong>Title:</strong> <del>${bookToDelete.title}</del></p>
                        <p><strong>Author:</strong> <del>${bookToDelete.author}</del></p>
                        <p><strong>Subject:</strong> <del>${bookToDelete.subject}</del></p>
                    </div>
                    <div style="font-size: 12px; color: var(--text-muted); font-style: italic; margin-top: 16px;">Switch back to "GET - Fetch Books" to confirm this record is gone.</div>
                </td>
            </tr>
        `;
        resultsCount.textContent = '1';

    } catch (err) {
        console.error('Delete book failure:', err);
        renderError("500 Internal Server Error", `Failed to delete book: ${err.message}`, "Check connection.");
    } finally {
        fetchBtn.disabled = false;
        fetchBtn.className = 'btn btn-run';
        fetchBtn.style.background = 'linear-gradient(135deg, #ef4444, #dc2626)';
        fetchBtn.style.color = '#ffffff';
        fetchBtn.innerHTML = `<i class="fa-solid fa-trash-can"></i> Delete Book`;
    }
}

function renderBooks(books) {
    booksList.innerHTML = '';
    resultsCount.textContent = books.length;

    if (books.length === 0) {
        booksList.innerHTML = `<tr><td colspan="7" class="placeholder-row">No matching book records found. Try modifying your filter options.</td></tr>`;
        return;
    }

    books.forEach(book => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td><code>${book.id}</code></td>
            <td class="book-title">${book.title}</td>
            <td><span class="subject-tag ${book.subject.toLowerCase()}">${book.subject}</span></td>
            <td class="book-author">${book.author}</td>
            <td>${book.pages} pages</td>
            <td class="book-price">$${book.price.toFixed(2)}</td>
            <td><strong>${book.published_year}</strong></td>
        `;
        booksList.appendChild(row);
    });
}

function renderError(status, message, suggestion) {
    booksList.innerHTML = `
        <tr>
            <td colspan="7" class="placeholder-row" style="color: var(--fiction-color); padding: 40px;">
                <div style="font-size: 20px; font-weight: 700; margin-bottom: 8px;"><i class="fa-solid fa-triangle-exclamation"></i> ${status}</div>
                <div style="font-size: 14px; margin-bottom: 6px;">${message}</div>
                <div style="font-size: 12px; color: var(--text-muted); font-style: italic;">${suggestion}</div>
            </td>
        </tr>
    `;
    resultsCount.textContent = '0';
}

// Initialize App
loadInitialDatabase();
