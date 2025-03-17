import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/order.{type Order}
import gleam/string

import birl.{type Day, type Time, type Weekday, Day}
import birl/duration

import util/short_circuit.{do} as sc

/// Converts a Day to a Time.
fn to_time_midnight(day: Day) -> Time {
  // Note that we can assert it is parsed, since we provided the string ourselves.
  let assert Ok(parsed) = birl.parse(to_string(day) <> "t00:00:00z")
  parsed
}

/// Maps a function over Time over a Day.
fn map(fun: fn(Time) -> Time, day: Day) -> Day {
  day |> to_time_midnight |> fun |> birl.get_day
}

/// Returns the next day.
pub fn next(day: Day) -> Day {
  add_days(day, 1)
}

/// Returns the previous day.
pub fn prev(day: Day) -> Day {
  add_days(day, -1)
}

/// Adds the specified number of days.
pub fn add_days(day: Day, amount: Int) -> Day {
  birl.add(_, duration.days(amount)) |> map(day)
}

/// Ensures the specified day is not before min or after max.
pub fn clamp(day: Day, min: Day, max: Day) -> Day {
  case days_diff(day, min), days_diff(day, max) {
    before, _ if before < 0 -> min
    _, after if after > 0 -> max
    _, _ -> day
  }
}

/// Converts a Day to a string in the format yyyy-mm-dd.
pub fn to_string(day: Day) -> String {
  string.pad_start(int.to_string(day.year), 4, "0")
  <> "-"
  <> string.pad_start(int.to_string(day.month), 2, "0")
  <> "-"
  <> string.pad_start(int.to_string(day.date), 2, "0")
}

/// Converts a Day to a string inthe format yyyymmdd.
pub fn to_int_string(day: Day) -> String {
  string.pad_start(int.to_string(day.year), 4, "0")
  <> string.pad_start(int.to_string(day.month), 2, "0")
  <> string.pad_start(int.to_string(day.date), 2, "0")
}

/// Returns the difference in days between two Days.
fn days_diff(a: Day, b: Day) {
  let from_time = to_time_midnight(a)
  let to_time = to_time_midnight(b)
  birl.difference(from_time, to_time) |> duration.blur_to(duration.Day)
}

/// Converts a Day to a relative string, if it can be expressed as one.
/// Returns None otherwise.
pub fn to_relative_string(day: Day, today: Day) -> Option(String) {
  case days_diff(day, today) {
    0 -> Some("Today")
    1 -> Some("Tomorrow")
    -1 -> Some("Yesterday")
    _ -> None
  }
}

/// Compares two Days.
pub fn compare(a: Day, b: Day) -> Order {
  use <- do(sc.compare(int.compare(a.year, b.year)))
  use <- do(sc.compare(int.compare(a.month, b.month)))
  int.compare(a.date, b.date)
}

/// Returns the weekday of the specified Day.
pub fn weekday(day: Day) -> Weekday {
  day |> to_time_midnight |> birl.weekday
}

/// Converts a Weekday to an Int.
pub fn weekday_to_int(weekday: Weekday) -> Int {
  case weekday {
    birl.Mon -> 0
    birl.Tue -> 1
    birl.Wed -> 2
    birl.Thu -> 3
    birl.Fri -> 4
    birl.Sat -> 5
    birl.Sun -> 6
  }
}

/// Returns the day of the specified weekday, in the same week as the provided Day is in.
/// Weeks start at monday.
fn day_this_week(day: Day, wkday: Weekday) -> Day {
  let cur_weekday = weekday(day) |> weekday_to_int
  let desired_weekday = weekday_to_int(wkday)

  case desired_weekday - cur_weekday {
    0 -> day
    diff -> birl.add(_, duration.days(diff)) |> map(day)
  }
}

/// Returns the ISO 8601 week number of the specified day.
pub fn week_number(day: Day) -> Int {
  // Week 1 of the year is the week in which the first Thursday of the year is in.
  let thursday_this_week = day_this_week(day, birl.Thu)

  // Use the year of thursday_this_week, so if that moved into last year, we calculate the
  // week in that year as well.
  let first_day = Day(thursday_this_week.year, 1, 4)
  let thursday_first_week = day_this_week(first_day, birl.Thu)

  // Count the number of days between this and the first thursday, and divide by 7 to get weeks.
  let diff = days_diff(thursday_this_week, thursday_first_week) / 7
  diff + 1
}
