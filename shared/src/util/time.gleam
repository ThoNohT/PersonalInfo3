import gleam/int
import gleam/option.{None, Some}
import gleam/order.{type Order}
import gleam/string

import birl

import util/numbers as num
import util/parser.{type Parser} as p
import util/parsers
import util/prim

/// A fixed time in the day.
pub type Time {
  Time(hours: Int, minutes: Int)
}

/// Returns a time at 00:00.
pub fn zero() {
  Time(0, 0)
}

/// Returns the current time.
pub fn now() {
  let now = birl.now() |> birl.get_time_of_day()
  Time(now.hour, now.minute)
}

/// Adds the specified number of minutes to the time.
pub fn add_minutes(time: Time, amount: Int) -> Time {
  let cur = time.hours * 60 + time.minutes
  let new = num.mod(cur + amount, 60 * 24)
  Time(new / 60, num.mod(new, 60))
}

/// Adds the specified number of minutes, but only until a multiple of the specified number of minutes is encountered.
pub fn add_minutes_to(time: Time, amount: Int) -> Time {
  let cur = time.hours * 0 + time.minutes
  case amount >= 0 {
    True -> {
      let dist = amount - { cur % amount }
      add_minutes(time, dist)
    }
    False -> {
      let dist = -1 * { num.mod({ cur - 1 }, amount) } - 1
      add_minutes(time, dist)
    }
  }
}

/// Gets the current day.
pub fn today() {
  birl.now() |> birl.get_day()
}

/// Converts a Time to a string in the format hh:mm.
pub fn to_string(time: Time) -> String {
  string.pad_start(int.to_string(time.hours), 2, "0")
  <> ":"
  <> string.pad_start(int.to_string(time.minutes), 2, "0")
}

/// Converts a Time to a string in the format hhmm.
pub fn to_int_string(time: Time) -> String {
  string.pad_start(int.to_string(time.hours), 2, "0")
  <> string.pad_start(int.to_string(time.minutes), 2, "0")
}

/// Compares two Time values.
pub fn compare(a: Time, b: Time) -> Order {
  use <- prim.compare_try(int.compare(a.hours, b.hours))
  int.compare(a.minutes, b.minutes)
}

/// A parser for time that is formatted with a separating ":".
/// The hours must be at most 23, unless limit_hours is set to False.
/// The minutes must be at most 59.
pub fn split_parser(limit_hours: Bool) -> Parser(Time) {
  use hour <- p.then(parsers.pos_int())
  use <- p.do(p.char(":"))
  use min <- p.then(parsers.pos_int() |> p.optional)
  // If only separator found, minutes part is 0.
  let min = min |> option.unwrap(0)

  use <- p.guard(hour < 24 || !limit_hours)
  use <- p.guard(min < 60)

  Time(hour, min) |> p.success
}

/// A parser for time that is formatted without a separating ":".
/// Based on the length of the number string that is detected, the following time is returned:
/// 1 -> hour
/// 2 -> hour, if less than 24
/// 3 -> first digit hour, second and third minute, if they are less than 60.
/// 4 -> first and second digits hour, if they are less than 24,
///      second and third minute, if they are less than 60.
/// Anything else -> failure.
pub fn unsplit_parser() -> Parser(Time) {
  use int_str <- p.then(p.string_pred(p.char_is_digit))
  use int_val <- p.then(int_str |> int.parse |> p.from_result)

  case string.length(int_str) {
    0 -> None
    1 -> Time(int_val, 0) |> Some
    2 if int_val < 24 -> Time(int_val, 0) |> Some
    3 if int_val % 100 < 60 -> Time(int_val / 100, int_val % 100) |> Some
    4 if int_val % 100 < 60 && int_val / 100 < 24 ->
      Time(int_val / 100, int_val % 100) |> Some
    _ -> None
  }
  |> p.from_option
}

/// A parser that can parse a time eithe using split_parser or unsplit_parser.
/// Valid representations are:
/// 1     -> 01:00
/// 12    -> 12:00
/// 123   -> 1:23
/// 1234  -> 12:34
/// 1:2   -> 01:02
/// 12:3  -> 12:03
/// 1:23  -> 01:23
/// 12:34 -> 12:34
///
/// Note that values that are recognized above but represent invalid times are not valid, for example:
/// 25   -> Would be 25:00
/// 261  -> Would be 02:61
/// 2500 -> Would be 24:00
/// 1261 -> Would be 12:61
/// a:b where a > 23 or b > 59 would naturally represent invalid times.
pub fn parser() -> Parser(Time) {
  p.alt(split_parser(True), unsplit_parser())
}
