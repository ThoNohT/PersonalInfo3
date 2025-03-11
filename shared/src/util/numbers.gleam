import gleam/int
import gleam/option.{type Option, None, Some}
import util/prim

/// The possible signs for a number.
pub type Sign {
  Pos
  Neg
}

/// Parses a positive int.
pub fn parse_pos_int(str) -> Option(Int) {
  use parsed <- option.then(int.base_parse(str, 10) |> option.from_result)
  use <- prim.check(None, parsed >= 0)
  Some(parsed)
}

fn magnitude_go(acc: Int, val: Int) {
  use <- prim.check(acc, val > 0)
  magnitude_go(acc * 10, val / 10)
}

/// Returns 10 to the power of the number of digits in a number.
fn magnitude(val: Int) -> Int {
  magnitude_go(1, val)
}

/// Converts an integer to a float that is the 0.the original int.
pub fn decimalify(val: Int) -> Float {
  let float_val = int.to_float(val)
  let mag = int.to_float(magnitude(val))
  float_val /. mag
}

/// A helper for modulo that does not return negative values.
pub fn mod(val: Int, by: Int) -> Int {
  let by = int.absolute_value(by)
  { { val % by } + by } % by
}
