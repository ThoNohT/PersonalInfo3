/// Retrieves the base url of the current website, when running in a browser.
@target(javascript)
@external(javascript, "./ffi.mjs", "base_url")
pub fn base_url() -> String
