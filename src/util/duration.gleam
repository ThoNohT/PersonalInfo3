import gleam/option.{type Option, Some, None}
import gleam/string
import gleam/int
import gleam/float
import gleam/order.{type Order, Eq}

import util/numbers as num
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
  Duration(hours: Int, minutes: Int, parsed_from: Option(DurationFormat))
}

pub fn zero() { Duration(0, 0, None) }

/// Compares two Duration values.
pub fn compare(a: Duration, b: Duration) -> Order {
  case int.compare(a.hours, b.hours) {
    Eq -> int.compare(a.minutes, b.minutes)
    other -> other
  }
}

/// Converts a Duration to a string in the format h:mm.
pub fn to_time_string(duration: Duration) -> String {
  int.to_string(duration.hours) <>
  ":" <>
  string.pad_start(int.to_string(duration.minutes), 2, "0")
}

/// Converts a Duration to a string as a decimal.
pub fn to_decimal_string(duration: Duration, decimals: Int) -> String {
  let frac = int.to_float(duration.hours) +. { int.to_float(duration.minutes) /. 60.0 }
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

pub fn to_string(duration: Duration) -> String {
  to_time_string(duration) <> " / " <> to_decimal_string(duration, 2)
}

/// Converts a Time to a Duration.
fn from_time(time: time.Time) { Duration(time.hours, time.minutes, Some(TimeFormat)) }

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

      Some(Duration(iint, float.round(60.0 *. num.decimalify(idec)), Some(DecimalFormat)))
    }
    _, [ num ], [ num2 ] if num == num2 -> num.parse_pos_int(num) |> option.map(Duration(_, 0, Some(DecimalFormat)))
    _, _, _ -> None
  }
}
