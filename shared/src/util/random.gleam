import gleam/bit_array
import gleam/crypto
import gleam/int
import gleam/string

/// Returns a random int between 0 (incl) and the specified maximum (excl).
pub fn int(max: Int) -> Int {
  int.random(max)
}

/// Generates a random string with characters between ascii value 48 and 122 of the specified length.
pub fn ascii_string(length: Int) -> String {
  crypto.strong_random_bytes(length)
  |> bit_array.base64_url_encode(False)
  |> string.slice(0, length)
}
