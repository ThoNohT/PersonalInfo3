export function every(interval, cb) {
    window.setInterval(cb, interval);
}

export function base_url() {
    return window.location.origin;
}

export function localstorage_get(key) {
    return localStorage.getItem(key) ?? "";
}

export function localstorage_set(key, value) {
    localStorage.setItem(key, value)
}

export function localstorage_remove(key) {
    localStorage.removeItem(key)
}

export function localstorage_clear() {
    localStorage.clear();
}

export function focus(id) {
    const elem = document.getElementById(id);
    if (elem) elem.focus();
}
