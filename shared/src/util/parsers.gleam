import gleam/int
import gleam/option.{None, Some}

import util/numbers
import util/parser.{type Parser} as p

/// A parser for a positive integer.
pub fn pos_int() -> Parser(Int) {
  use int_str <- p.then(p.string_pred(p.char_is_digit))
  int_str |> int.parse() |> p.from_result
}

/// A parser for an integer that can have a negative sign before it.
pub fn int() -> Parser(Int) {
  use minus <- p.then(p.optional(p.char("-")))
  use pos_int <- p.then(pos_int())

  case minus {
    Some(_) -> -1 * pos_int
    None -> pos_int
  }
  |> p.success
}

/// A parser for a float, where the decimal separator is either a ".", or a ",".
pub fn pos_float() -> Parser(Float) {
  use int_part <- p.then(pos_int() |> p.map(int.to_float))

  let decimal_parser = {
    use <- p.do(p.alt(p.char("."), p.char(",")))
    use dec_part <- p.then(pos_int() |> p.map(numbers.decimalify))
    p.success(int_part +. dec_part)
  }

  p.alt(decimal_parser, p.success(int_part))
}

/// A parser for a float that can have a negative sign before it.
pub fn float() -> Parser(Float) {
  use minus <- p.then(p.optional(p.char("-")))
  use pos_float <- p.then(pos_float())

  case minus {
    Some(_) -> -1.0 *. pos_float
    None -> pos_float
  }
  |> p.success
}
