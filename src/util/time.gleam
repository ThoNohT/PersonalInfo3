import gleam/option.{type Option, Some, None}
import gleam/string
import gleam/int
import gleam/order.{type Order, Eq}

import util/prim
import util/numbers as num

/// A fixed time in the day.
pub type Time {
  Time(hours: Int, minutes: Int)
}

pub fn zero() { Time(0, 0) }

/// Converts a Time to a string in the format hh:mm.
pub fn to_string(time: Time) -> String {
  string.pad_start(int.to_string(time.hours), 2, "0") <>
  ":" <>
  string.pad_start(int.to_string(time.minutes), 2, "0")
}

/// Compares two Time values.
pub fn compare(a: Time, b: Time) -> Order {
  case int.compare(a.hours, b.hours) {
    Eq -> int.compare(a.minutes, b.minutes)
    other -> other
  }
}

pub fn parse_split_time(hour: String, minute: String, limit_hours: Bool) {
  use int_hr <- option.then(num.parse_pos_int(hour))
  use int_min <- option.then(num.parse_pos_int(minute))

  use _ <- prim.check(None, int_hr < 24 || !limit_hours)
  use _ <- prim.check(None, int_min < 60)

  Time(int_hr, int_min) |> Some
}

fn parse_unsplit_time(time: String) {
  use int_val <- option.then(num.parse_pos_int(time))

  case string.length(time) {
    0 -> None
    1 -> Time(int_val, 0) |> Some
    2 if int_val < 24 -> Time(int_val, 0) |> Some
    3 if int_val % 100 < 60 -> Time(int_val / 100, int_val % 100) |> Some
    4 if int_val % 100 < 60 && int_val / 100 < 24 -> Time(int_val / 100, int_val % 100) |> Some
    _ -> None
  }
}

/// Parses a time of the day from a string.
///
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
pub fn parse(time: String) -> Option(Time) {
  case string.split(time, ":") {
    [ hr, min ] -> parse_split_time(hr, min, True)
    [ time ] -> parse_unsplit_time(time)
    _ -> None
  }
}

