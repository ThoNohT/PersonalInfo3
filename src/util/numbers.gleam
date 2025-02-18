import gleam/option.{type Option}
import gleam/int

import util/option as opt

/// Parses a positive int.
pub fn parse_pos_int(str) -> Option(Int) {
    int.base_parse(str, 10)
    |> option.from_result
    |> opt.when(fn(x) { x >= 0})
}

fn magnitude_go(acc: Int, val: Int) {
  case val > 0 {
    True -> magnitude_go(acc * 10, val / 10)
    False -> acc
  }
}

/// Returns 10 to the power of the number of digits in a number.
fn magnitude(val: Int) -> Int { magnitude_go(1, val) }

/// Converts an integer to a float that is the 0.the original int.
pub fn decimalify(val: Int) -> Float {
  let float_val = int.to_float(val)
  let mag = int.to_float(magnitude(val))
  float_val /. mag
}
