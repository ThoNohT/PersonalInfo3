import gleam/http
import gleam/http/request

@target(javascript)
/// Retrieves the base url of the current website, when running in a browser.
@external(javascript, "./ffi.mjs", "base_url")
pub fn base_url() -> String

/// Creates a request with the specified authorization header and method.
/// Crashes if the request could not be created.
pub fn request_with_authorization(
  url: String,
  method: http.Method,
  auth: String,
) {
  let assert Ok(req) = request.to(url)
  req
  |> request.set_method(method)
  |> request.prepend_header("authorization", auth)
}
