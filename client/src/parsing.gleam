import gleam/int
import gleam/list
import gleam/option.{type Option, Some}
import gleam/string

import birl.{type Day, Day}

import model.{
  type DayEvent, type DayState, ClockEvent, DayState, Gain, HolidayBooking, Home,
  In, Office, Use,
}
import util/duration.{type Duration}
import util/numbers
import util/parser.{type Parser} as p
import util/prim

/// Parsed data for constructhing the state.
pub type StateInput {
  StateInput(
    week_target: Duration,
    travel_distance: Float,
    history: List(DayState),
  )
}

/// Parses a positive Int.
fn parse_pos_int() -> Parser(Int) {
  use int_str <- p.then(p.string_check(p.char_is_digit))
  int_str |> int.parse() |> p.from_result
}

/// Parses a Duration, where the last 2 digits are the minutes, and everything before the hours.
fn parse_duration() -> Parser(Duration) {
  parse_pos_int()
  |> p.map(fn(nr) {
    let hours = nr / 100
    let minutes = nr % 100
    duration.from_minutes(hours * 60 + minutes)
    |> duration.with_format(duration.DecimalFormat)
  })
}

/// Parses a Float, where the decimal separator is a ".".
fn parse_float() -> Parser(Float) {
  use int_part <- p.then(parse_pos_int() |> p.map(int.to_float))

  let decimal_parser = {
    use <- p.do(p.char("."))
    use dec_part <- p.then(parse_pos_int() |> p.map(numbers.decimalify))
    p.success(int_part +. dec_part)
  }

  p.alt(decimal_parser, p.success(int_part))
}

/// Parses a Day.
fn parse_date() -> Parser(Day) {
  use year <- p.then(
    p.repeat(p.check(p.char_is_digit), 4)
    |> p.map(string.concat)
    |> p.bind(fn(x) { int.parse(x) |> p.from_result }),
  )
  use month <- p.then(
    p.repeat(p.check(p.char_is_digit), 2)
    |> p.map(string.concat)
    |> p.bind(fn(x) { int.parse(x) |> p.from_result }),
  )
  use day <- p.then(
    p.repeat(p.check(p.char_is_digit), 2)
    |> p.map(string.concat)
    |> p.bind(fn(x) { int.parse(x) |> p.from_result }),
  )

  p.success(Day(year, month, day))
}

/// Parses the letter that indicates whether lunch is enabled this day.
fn parse_lunch() -> Parser(Bool) {
  use ch <- p.then(p.alt(p.char("L"), p.char("N")))

  case ch {
    "L" -> True
    "N" -> False
    _ -> panic as "Should always be L or N"
  }
  |> p.success
}

fn parse_day_event() -> Parser(DayEvent) {
  use dur <- p.then(parse_duration())
  use typ <- p.then(p.pchar())

  // Return the right type of day event. Note that clock events need a time,
  // so they can only be returned if the duration is not longer than a time can be.
  case typ {
    "O" -> {
      use time <- p.then(duration.to_time(dur) |> p.from_option)
      p.success(ClockEvent(0, time, Office, In))
    }
    "H" -> {
      use time <- p.then(duration.to_time(dur) |> p.from_option)
      p.success(ClockEvent(0, time, Home, In))
    }
    "v" -> p.success(HolidayBooking(0, dur, Gain))
    "V" -> p.success(HolidayBooking(0, dur, Use))
    _ -> p.failure()
  }
}

/// Parses a DayState.
fn parse_day_state() -> Parser(DayState) {
  use date <- p.then(parse_date())
  use target <- p.then(parse_duration())
  use lunch <- p.then(parse_lunch())
  use events <- p.then(p.star(parse_day_event()))
  p.success(DayState(date: date, target: target, lunch: lunch, events: events))
}

fn parse_line(acc: Option(StateInput), line: String) -> Option(StateInput) {
  use <- prim.check(acc, !{ string.is_empty(line) })
  // Skip empty lines.
  use si <- option.then(acc)

  let parser = {
    use checkpoint <- p.save_state()
    use ch <- p.then(p.pchar())
    case ch {
      // Try to parse the week target.
      "W" -> {
        use dur <- p.then(parse_duration())
        use <- p.do(p.end())
        p.success(StateInput(..si, week_target: dur))
      }

      // Try to parse the travel distance.
      "T" -> {
        use d <- p.then(parse_float())
        use <- p.do(p.end())
        p.success(StateInput(..si, travel_distance: d))
      }

      // Otherwise try to parse a day state.
      _ -> {
        use <- p.restore(checkpoint)
        use st <- p.then(parse_day_state())
        use <- p.do(p.end())
        p.success(StateInput(..si, history: [st, ..si.history]))
      }
    }
  }

  p.run(parser, line)
}

pub fn parse_state_input(input: String) -> Option(StateInput) {
  input
  // Split in lines.
  |> string.replace("\r", "")
  |> string.split("\n")
  // Parse input (history will be reversed).
  |> list.fold(Some(StateInput(duration.zero(), 0.0, [])), parse_line)
}
