import gleam/option.{type Option, Some, None}
import gleam/string
import gleam/int
import gleam/float

import util/numbers as num

/// The different ways Duration can be formatted.
pub type TimeFormat {
  /// The time is formatted with a separating colon, where the second part are minutes.
  TimeFormat

  /// The time is formatted as a decimal, where the integer part represents the number of hours,
  /// and the decimal part a fraction of an hour remaining.
  DecimalFormat
}

/// A fixed time in the day.
pub type Time {
  Time(hours: Int, minutes: Int)
}

/// Converts a Time to a string in the format hh:mm.
pub fn time_to_time_string(time: Time) -> String {
  string.pad_start(int.to_string(time.hours), 2, "0") <>
  ":" <>
  string.pad_start(int.to_string(time.minutes), 2, "0")
}

/// A duration in hours and minutes.
pub type Duration {
  Duration(hours: Int, minutes: Int, parsed_from: Option(TimeFormat))
}

/// Converts a Duration to a string in the format h:mm.
pub fn duration_to_time_string(duration: Duration) -> String {
  int.to_string(duration.hours) <>
  ":" <>
  string.pad_start(int.to_string(duration.minutes), 2, "0")
}

/// Converts a Duration to a string as a decimal.
pub fn duration_to_decimal_string(duration: Duration, decimals: Int) -> String {
  let frac = int.to_float(duration.hours) +. { int.to_float(duration.minutes) /. 60.0 }
  float.to_string(float.to_precision(frac, decimals))
}

/// Converts a duration to a string in all the formats in which it was not parsed.
pub fn duration_to_unparsed_format_string(duration: Duration) -> String {
  case duration.parsed_from {
    Some(TimeFormat) -> duration_to_decimal_string(duration, 2)
    Some(DecimalFormat) -> duration_to_time_string(duration)
    None -> duration_to_time_string(duration) <> " / " <> duration_to_decimal_string(duration, 2)
  }
}

/// Converts a Time to a Duration.
fn duration_from_time(time: Time) { Duration(time.hours, time.minutes, Some(TimeFormat)) }

fn parse_split_time(hour: String, minute: String, limit_hours: Bool) {
  use int_hr <- option.then(num.parse_pos_int(hour))
  use int_min <- option.then(num.parse_pos_int(minute))

  case int_hr, int_min {
    h, m if { h < 24 || !limit_hours } && m < 60 -> Time(h, m) |> Some
    _, _ -> None
  }
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
pub fn parse_time(time: String) -> Option(Time) {
  case string.split(time, ":") {
    [hr, min] -> parse_split_time(hr, min, True)
    [time] -> parse_unsplit_time(time)
    _ -> None
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
pub fn parse_duration(input: String) -> Option(Duration) {
  case string.split(input, ":"), string.split(input, "."), string.split(input, ",") {
    [hr, min], _, _ -> parse_split_time(hr, min, False) |> option.map(duration_from_time)
    _, [int_, dec], _ 
  | _, _, [int_, dec] -> {
      use iint <- option.then(num.parse_pos_int(int_))
      use idec <- option.then(num.parse_pos_int(dec))

      Some(Duration(iint, float.round(60.0 *. num.decimalify(idec)), Some(DecimalFormat)))
    }
    _, [num], [num2] if num == num2 -> num.parse_pos_int(num) |> option.map(Duration(_, 0, Some(DecimalFormat)))
    _, _, _ -> None
  }
}
