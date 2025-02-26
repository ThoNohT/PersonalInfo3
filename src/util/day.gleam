import gleam/int
import gleam/string
import gleam/option.{type Option, Some, None}

import birl.{type Day, type Time}
import birl/duration

/// Converts a Day to a Time.
fn to_time_midnight(day: Day) -> Time {
    // Note that we can assert it is parsed, since we provided the string ourselves.
    let assert Ok(parsed) = birl.parse(to_string(day)<>"t00:00:00z")
    parsed
}

/// Maps a function over Time over a Day.
fn map(fun: fn(Time) -> Time, day: Day) -> Day {
  day |> to_time_midnight |> fun |> birl.get_day
}

/// Returns the next day.
pub fn next(day: Day) -> Day {
  birl.add(_, duration.days(1)) |> map(day)
}

/// Returns the previous day.
pub fn prev(day: Day) -> Day {
  birl.subtract(_, duration.days(1)) |> map(day)
}

/// Converts a Day to a string in the format yyyy-mm-dd.
pub fn to_string(day: Day) -> String {
  string.pad_start(int.to_string(day.year), 4, "0") <>
  "-" <>
  string.pad_start(int.to_string(day.month), 2, "0") <>
  "-" <>
  string.pad_start(int.to_string(day.date), 2, "0")
}

/// Converts a Day to a relative string, if it can be expressed as one.
/// Returns None otherwise.
pub fn to_relative_string(day: Day, today: Day) -> Option(String) {
    let from_time = to_time_midnight(day)
    let to_time = to_time_midnight(today)

    let diff = birl.difference(from_time, to_time)
    case duration.blur_to(diff, duration.Day) {
        0 -> Some("Today")
        1 -> Some("Tomorrow")
        -1 -> Some("Yesterday")
        _ -> None
    }
}
