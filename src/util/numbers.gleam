import util/prim
import gleam/option.{type Option, Some, None}
import gleam/int

/// The possible signs for a number.
pub type Sign { Pos Neg }

/// Parses a positive int.
pub fn parse_pos_int(str) -> Option(Int) {
    use parsed <- option.then(int.base_parse(str, 10) |> option.from_result)
    use _ <- prim.check(None, parsed >= 0)
    Some(parsed)
}

fn magnitude_go(acc: Int, val: Int) {
  use _ <- prim.check(acc, val > 0)
  magnitude_go(acc * 10, val / 10)
}

/// Returns 10 to the power of the number of digits in a number.
fn magnitude(val: Int) -> Int { magnitude_go(1, val) }

/// Converts an integer to a float that is the 0.the original int.
pub fn decimalify(val: Int) -> Float {
  let float_val = int.to_float(val)
  let mag = int.to_float(magnitude(val))
  float_val /. mag
}
