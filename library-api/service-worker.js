// Library API Sandbox Service Worker Simulation
const DB_NAME = 'LibrarySandboxDB';
const DB_VERSION = 1;
const STORE_NAME = 'books';

function openDB() {
    return new Promise((resolve, reject) => {
        const request = indexedDB.open(DB_NAME, DB_VERSION);
        request.onupgradeneeded = (event) => {
            const db = event.target.result;
            if (!db.objectStoreNames.contains(STORE_NAME)) {
                db.createObjectStore(STORE_NAME, { keyPath: 'id' });
            }
        };
        request.onsuccess = (event) => resolve(event.target.result);
        request.onerror = (event) => reject(event.target.error);
    });
}

function getAllBooks(db) {
    return new Promise((resolve, reject) => {
        const transaction = db.transaction(STORE_NAME, 'readonly');
        const store = transaction.objectStore(STORE_NAME);
        const request = store.getAll();
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
    });
}

function saveBook(db, book) {
    return new Promise((resolve, reject) => {
        const transaction = db.transaction(STORE_NAME, 'readwrite');
        const store = transaction.objectStore(STORE_NAME);
        const request = store.put(book);
        request.onsuccess = () => resolve();
        request.onerror = () => reject(request.error);
    });
}

function deleteBook(db, id) {
    return new Promise((resolve, reject) => {
        const transaction = db.transaction(STORE_NAME, 'readwrite');
        const store = transaction.objectStore(STORE_NAME);
        const request = store.delete(id);
        request.onsuccess = () => resolve();
        request.onerror = () => reject(request.error);
    });
}

self.addEventListener('install', (event) => {
    self.skipWaiting();
});

self.addEventListener('activate', (event) => {
    event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (event) => {
    const url = new URL(event.request.url);
    
    // Check if the request is targeting the books.json API and has no seed query parameter
    if (url.pathname.endsWith('/api/v1/books.json') && !url.searchParams.has('seed')) {
        event.respondWith(handleApiRequest(event.request, url));
    }
});

async function handleApiRequest(request, url) {
    const db = await openDB();
    const method = request.method;

    // Check if db is empty, if so, seed it once from the real static JSON file
    let books = await getAllBooks(db);
    if (books.length === 0) {
        try {
            // Append seed=true to bypass intercept recursion
            const response = await fetch('./api/v1/books.json?seed=true');
            const initialBooks = await response.json();
            for (const book of initialBooks) {
                await saveBook(db, book);
            }
            books = initialBooks;
        } catch (err) {
            console.error('Failed to seed books from static JSON:', err);
        }
    }

    if (method === 'GET') {
        const queryParams = url.searchParams;
        const subject = queryParams.get('subject');
        const author = queryParams.get('author');
        const minPages = queryParams.get('minPages');
        const maxPages = queryParams.get('maxPages');
        const minPrice = queryParams.get('minPrice');
        const maxPrice = queryParams.get('maxPrice');
        const minYear = queryParams.get('minYear');
        const maxYear = queryParams.get('maxYear');

        let filteredBooks = books;
        if (subject) filteredBooks = filteredBooks.filter(b => b.subject === subject);
        if (author) filteredBooks = filteredBooks.filter(b => b.author === author);
        if (minPages) filteredBooks = filteredBooks.filter(b => b.pages >= parseInt(minPages));
        if (maxPages) filteredBooks = filteredBooks.filter(b => b.pages <= parseInt(maxPages));
        if (minPrice) filteredBooks = filteredBooks.filter(b => b.price >= parseFloat(minPrice));
        if (maxPrice) filteredBooks = filteredBooks.filter(b => b.price <= parseFloat(maxPrice));
        if (minYear) filteredBooks = filteredBooks.filter(b => b.published_year >= parseInt(minYear));
        if (maxYear) filteredBooks = filteredBooks.filter(b => b.published_year <= parseInt(maxYear));

        return new Response(JSON.stringify(filteredBooks), {
            status: 200,
            headers: { 'Content-Type': 'application/json' }
        });
    }

    if (method === 'POST') {
        const bodyText = await request.text();
        let newBook;
        try {
            newBook = JSON.parse(bodyText);
        } catch (e) {
            return new Response(JSON.stringify({ error: 'Bad Request', message: 'Invalid JSON request body.' }), {
                status: 400,
                headers: { 'Content-Type': 'application/json' }
            });
        }

        // Generate high auto-increment ID
        const maxId = books.length > 0 ? Math.max(...books.map(b => b.id)) : 0;
        newBook.id = maxId + 1;

        await saveBook(db, newBook);

        return new Response(JSON.stringify(newBook), {
            status: 201,
            headers: { 'Content-Type': 'application/json' }
        });
    }

    if (method === 'PUT') {
        const queryParams = url.searchParams;
        const idStr = queryParams.get('id');
        if (!idStr) {
            return new Response(JSON.stringify({ error: 'Bad Request', message: 'Book ID is required.' }), {
                status: 400,
                headers: { 'Content-Type': 'application/json' }
            });
        }
        const id = parseInt(idStr);
        const bodyText = await request.text();
        let updatedFields;
        try {
            updatedFields = JSON.parse(bodyText);
        } catch (e) {
            return new Response(JSON.stringify({ error: 'Bad Request', message: 'Invalid JSON request body.' }), {
                status: 400,
                headers: { 'Content-Type': 'application/json' }
            });
        }

        const originalBook = books.find(b => b.id === id);
        if (!originalBook) {
            return new Response(JSON.stringify({ error: 'Not Found', message: `Book ID ${id} not found.` }), {
                status: 404,
                headers: { 'Content-Type': 'application/json' }
            });
        }

        const updatedBook = {
            id: id,
            title: updatedFields.title || originalBook.title,
            author: updatedFields.author || originalBook.author,
            subject: updatedFields.subject || originalBook.subject,
            pages: updatedFields.pages !== undefined && updatedFields.pages !== null && !isNaN(parseInt(updatedFields.pages)) ? parseInt(updatedFields.pages) : originalBook.pages,
            price: updatedFields.price !== undefined && updatedFields.price !== null && !isNaN(parseFloat(updatedFields.price)) ? parseFloat(updatedFields.price) : originalBook.price,
            published_year: updatedFields.published_year !== undefined && updatedFields.published_year !== null && !isNaN(parseInt(updatedFields.published_year)) ? parseInt(updatedFields.published_year) : originalBook.published_year
        };

        await saveBook(db, updatedBook);

        return new Response(JSON.stringify(updatedBook), {
            status: 200,
            headers: { 'Content-Type': 'application/json' }
        });
    }

    if (method === 'DELETE') {
        const queryParams = url.searchParams;
        const idStr = queryParams.get('id');
        if (!idStr) {
            return new Response(JSON.stringify({ error: 'Bad Request', message: 'Book ID is required.' }), {
                status: 400,
                headers: { 'Content-Type': 'application/json' }
            });
        }
        const id = parseInt(idStr);
        const bookToDelete = books.find(b => b.id === id);
        if (!bookToDelete) {
            return new Response(JSON.stringify({ error: 'Not Found', message: `Book ID ${id} not found.` }), {
                status: 404,
                headers: { 'Content-Type': 'application/json' }
            });
        }

        await deleteBook(db, id);

        return new Response(JSON.stringify({ message: `Book ID ${id} deleted successfully.`, deleted_book: bookToDelete }), {
            status: 200,
            headers: { 'Content-Type': 'application/json' }
        });
    }

    return fetch(request);
}
