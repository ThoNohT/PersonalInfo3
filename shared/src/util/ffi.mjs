export function every(interval, cb) {
    window.setInterval(cb, interval);
}

export function base_url() {
    return window.location.origin;
}

export function focus(id) {
    const elem = document.getElementById(id);
    if (elem) elem.focus();
}
