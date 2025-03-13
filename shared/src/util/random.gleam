import gleam/int
import gleam/string

/// Returns a random int between 0 (incl) and the specified maximum (excl).
pub fn int(max: Int) -> Int { int.random(max) }

/// Generates a random array with characters between ascii value 48 and 122 of the specified length.
fn char_array(acc: List(UtfCodepoint), length: Int) -> List(UtfCodepoint) {
  case length <= 0 {
    True -> acc
    False -> {
      let assert Ok(next) = 48 + int(122 - 48) |> string.utf_codepoint
      char_array([next, ..acc], length - 1)
    }
  }
}

/// Generates a random string with characters between ascii value 48 and 122 of the specified length.
pub fn ascii_string(length: Int) -> String {
  string.from_utf_codepoints(char_array([], length))
}
