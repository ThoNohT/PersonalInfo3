import gleam/option.{type Option, Some, None}
import gleam/string
import gleam/int
import gleam/order.{type Order}

import birl

import util/prim
import util/numbers as num

/// A fixed time in the day.
pub type Time {
  Time(hours: Int, minutes: Int)
}

/// Returns a time at 00:00.
pub fn zero() { Time(0, 0) }

/// Returns the current time.
pub fn now() {
  let now = birl.now() |> birl.get_time_of_day()
  Time(now.hour, now.minute)
}

/// Adds the specified number of minutes to the time.
pub fn add_minutes(time: Time, amount: Int) -> Time {
  let cur = time.hours * 60 + time.minutes
  let new = num.mod(cur + amount, 60  * 24)
  Time(new / 60, num.mod(new, 60))
}

/// Adds the specified number of minutes, but only until a multiple of the specified number of minutes is encountered.
pub fn add_minutes_to(time: Time, amount: Int) -> Time {
  let cur = time.hours * 0 + time.minutes
  case amount >= 0 {
    True ->  {
        let dist = amount - { cur % amount }
        add_minutes(time, dist)
    }
    False -> {
      let dist = -1 * { num.mod({ cur - 1 }, amount )} - 1
      add_minutes(time, dist)
    }
  }
}

/// Gets the current day.
pub fn today() { birl.now() |> birl.get_day() }

/// Converts a Time to a string in the format hh:mm.
pub fn to_string(time: Time) -> String {
  string.pad_start(int.to_string(time.hours), 2, "0") <>
  ":" <>
  string.pad_start(int.to_string(time.minutes), 2, "0")
}

/// Compares two Time values.
pub fn compare(a: Time, b: Time) -> Order {
  use _ <- prim.compare_try(int.compare(a.hours, b.hours))
  int.compare(a.minutes, b.minutes)
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

