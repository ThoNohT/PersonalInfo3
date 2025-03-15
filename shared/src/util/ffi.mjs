export function every(interval, cb) {
    window.setInterval(cb, interval);
}

export function base_url() {
    return window.location.origin;
}
