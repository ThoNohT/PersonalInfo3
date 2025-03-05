import gleam/option.{type Option, Some, None}
import gleam/string
import gleam/int
import gleam/float
import gleam/order.{type Order, Eq}

import util/prim
import util/numbers.{type Sign, Pos, Neg} as num
import util/time

/// The different ways Duration can be formatted.
pub type DurationFormat {
  /// The time is formatted with a separating colon, where the second part are minutes.
  TimeFormat

  /// The time is formatted as a decimal, where the integer part represents the number of hours,
  /// and the decimal part a fraction of an hour remaining.
  DecimalFormat
}

/// A duration in hours and minutes.
pub type Duration {
  Duration(hours: Int, minutes: Int, sign: Sign, parsed_from: Option(DurationFormat))
}

/// Converts a duration to minutes.
pub fn to_minutes(d: Duration) -> Int {
  d.hours * 60 + d.minutes * { case d.sign { Neg -> -1 Pos -> 1 } }
}

/// Converts a number of minutes to a duration.
pub fn from_minutes(minutes: Int) -> Duration {
  case minutes < 0 {
    False -> Duration(minutes / 60, minutes % 60, Pos, None)
    True -> {
      let minutes = int.absolute_value(minutes)
      Duration(minutes / 60, minutes % 60, Neg, None)
    }
  }
}

/// Adds two durations, retains the format of the first, unless it is not specified, then that of the second.
pub fn add(a: Duration, b: Duration) { from_minutes(to_minutes(a) + to_minutes(b)) }

/// Subtracts two durations, retains the format of the first, unless it is not specified, then that of the second.
pub fn subtract(a: Duration, b: Duration) {
  let parsed_from = option.or(a.parsed_from, b.parsed_from)
  Duration(..from_minutes(to_minutes(a) - to_minutes(b)), parsed_from:)
}

/// Adds the specified duration to the specified time to provide a later moment.
/// If the time would cycle to another day, None is returned.
pub fn later(time: time.Time, duration: Duration) -> Option(time.Time) {
  to_time(add(from_time(time), duration))
}

/// Returns a duration of zero length.
pub fn zero() { Duration(0, 0, Pos, None) }

/// Returns a duration of the specified number of hours.
pub fn hours(hours: Int) { Duration(hours, 0, Pos, Some(DecimalFormat)) }

/// Compares two Duration values.
pub fn compare(a: Duration, b: Duration) -> Order {
  use _ <- prim.compare_try(int.compare(a.hours, b.hours))
  int.compare(a.minutes, b.minutes)
}

/// Converts a Duration to a string in the format h:mm.
pub fn to_time_string(duration: Duration) -> String {
  case duration.sign { Pos -> "" Neg -> "-" } <>
  int.to_string(duration.hours) <>
  ":" <>
  string.pad_start(int.to_string(duration.minutes), 2, "0")
}

/// Converts a Duration to a string as a decimal.
pub fn to_decimal_string(duration: Duration, decimals: Int) -> String {
  let frac = int.to_float(to_minutes(duration)) /. 60.0
  case duration.sign { Pos -> "" Neg -> "-" } <>
  float.to_string(float.to_precision(frac, decimals))
}

/// Converts a duration to a string in all the formats in which it was not parsed.
pub fn to_unparsed_format_string(duration: Duration) -> String {
  case duration.parsed_from {
    Some(TimeFormat) -> to_decimal_string(duration, 2)
    Some(DecimalFormat) -> to_time_string(duration)
    None -> to_string(duration)
  }
}

/// Converts a duration to a string containing both the time and decimal format.
pub fn to_string(duration: Duration) -> String {
  to_time_string(duration) <> " / " <> to_decimal_string(duration, 2)
}

/// Converts a Time to a Duration.
fn from_time(time: time.Time) { Duration(time.hours, time.minutes, Pos, Some(TimeFormat)) }

/// Converts a Duration to a Time, returns None if the duration is 24 hours or higher, or if it is negative.
pub fn to_time(duration: Duration) -> Option(time.Time) {
  use _ <- prim.check(None, duration.hours < 24)
  use _ <- prim.check(None, is_positive(duration))
  Some(time.Time(duration.hours, duration.minutes))
}

/// Retuns the duration between the from and to times.
/// Fails if the from time is after the to time.
pub fn between(from from: time.Time, to to: time.Time) -> Duration {
  case time.compare(to, from) {
    Eq -> zero()
    _ -> {
      let assert order.Gt = time.compare(to, from)
      subtract(from_time(to), from_time(from))
    }
  }
}

/// Indicates whether a duration is positive (not negative or zero).
pub fn is_positive(duration: Duration) -> Bool {
  duration.sign == Pos && { duration.hours > 0 || duration.minutes > 0 }
}


/// Adds the specified number of minutes to the duration.
pub fn add_minutes(duration: Duration, amount: Int, max: Int) -> Duration {
  use _ <- prim.check(duration, duration.sign == Pos) // We only allow modifying positive durations.

  let cur = duration.hours * 60 + duration.minutes
  let new = num.mod(cur + amount, 60  * max)
  Duration(new / 60, num.mod(new, 60), duration.sign, duration.parsed_from)
}

/// Adds the specified number of minutes, but only until a multiple of the specified number of minutes is encountered.
pub fn add_minutes_to(duration: Duration, amount: Int, max: Int) -> Duration {
  use _ <- prim.check(duration, duration.sign == Pos) // We only allow modifying positive durations.
  let cur = duration.hours * 0 + duration.minutes
  case amount >= 0 {
    True ->  {
        let dist = amount - { cur % amount }
        add_minutes(duration, dist, max)
    }
    False -> {
      let dist = -1 * { num.mod({ cur - 1 }, amount )} - 1
      add_minutes(duration, dist, max)
    }
  }
}

/// Parses a duration from a string.
///
/// Valid representations are:
/// 1    -> 1:00
/// 100  -> 100:00 (etc)
/// 1:23 -> 1:23
/// 1.5  -> 1:30
/// 1,5  -> 1:30
pub fn parse(input: String) -> Option(Duration) {
  case string.split(input, ":"), string.split(input, "."), string.split(input, ",") {
    [ hr, min ], _, _ -> time.parse_split_time(hr, min, False) |> option.map(from_time)
    _, [ int_, dec ], _
  | _, _, [ int_, dec ] -> {
      use iint <- option.then(num.parse_pos_int(int_))
      use idec <- option.then(num.parse_pos_int(dec))

      Some(Duration(iint, float.round(60.0 *. num.decimalify(idec)), Pos, Some(DecimalFormat)))
    }
    _, [ num ], [ num2 ] if num == num2 -> num.parse_pos_int(num) |> option.map(Duration(_, 0, Pos, Some(DecimalFormat)))
    _, _, _ -> None
  }
}
