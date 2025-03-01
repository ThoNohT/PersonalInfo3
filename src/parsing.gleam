import gleam/int
import gleam/list
import gleam/option.{type Option, None}
import gleam/string

import birl.{type Day, Day}

import util/parser.{type ParseResult, ParseState, Success, Failed} as p
import util/numbers.{Pos}
import util/duration.{type Duration, Duration}
import model.{
  type DayState, DayState,
  type DayEvent, ClockEvent, HolidayBooking,
  In, Home, Office, Gain, Use}

/// Parsed data for constructhing the state.
pub type StateInput {
  StateInput(week_target: Duration, travel_distance: Float, history: List(DayState))
}

/// Parses a positive Int.
fn parse_pos_int(input: String) -> ParseResult(Int) {
  use int_str <- p.then(p.plus(input, p.pcheck(_, p.char_is_digit)) |> p.map(string.from_utf_codepoints))
  int.parse(int_str.result) |> p.from_result(int_str.remaining)
}

/// Parses a Duration, where the last 2 digits are the minutes, and everything before the hours.
fn parse_duration(input: String) -> ParseResult(Duration) {
  parse_pos_int(input)
  |> p.map(fn(nr) { Duration(nr / 100, nr % 100, Pos, None) })
}

/// Parses a Float, where the decimal separator is a ".".
fn parse_float(input: String) -> ParseResult(Float) {
  use int_part <- p.then(parse_pos_int(input) |> p.map(int.to_float))
  case p.pchar(int_part.remaining, ".") {
    Failed -> Success(int_part)
    Success(_) -> parse_pos_int(input) |> p.map(fn(d) { int_part.result +. numbers.decimalify(d) })
  }
}

/// Parses a Day.
fn parse_date(input: String) -> ParseResult(Day) {
  use year <- p.then(
    p.repeat(input, p.pcheck(_, p.char_is_digit), 4)
    |> p.map(string.from_utf_codepoints)
    |> p.bind(fn(x) { int.parse(x) |> option.from_result })
  )
  use month <- p.then(
    p.repeat(year.remaining, p.pcheck(_, p.char_is_digit), 2)
    |> p.map(string.from_utf_codepoints)
    |> p.bind(fn(x) { int.parse(x) |> option.from_result })
  )
  use day <- p.then(
    p.repeat(month.remaining, p.pcheck(_, p.char_is_digit), 2)
    |> p.map(string.from_utf_codepoints)
    |> p.bind(fn(x) { int.parse(x) |> option.from_result })
    )

  let res = Success(ParseState(..day, result: Day(year.result, month.result, day.result)))
  res
}

/// Parses the letter that indicates whether lunch is enabled this day.
fn parse_lunch(input: String) -> ParseResult(Bool) {
  p.alt(input, p.pchar(_, "L"), p.pchar(_, "N"))
  |> p.map(fn(l) {
    case string.from_utf_codepoints([ l ]) {
      "L" -> True
      "N" -> False
      _ -> panic as "Should always be L or N"
    }
  })
}

fn parse_day_event(input: String) -> ParseResult(DayEvent) {
  use dur <- p.then(parse_duration(input))
  use typ <- p.then(p.pcheck(dur.remaining, fn(_) { True }))

  // Return the right type of day event. Note that clock events need a time,
  // so they can only be returned if the duration is not longer than a time can be.
  case string.from_utf_codepoints([ typ.result ]) {
    "O" -> {
      use time <- p.then(duration.to_time(dur.result) |> p.from_option(typ.remaining))
      Success(ParseState(..typ, result: ClockEvent(0, time.result, Office, In)))
    }
    "H" -> {
      use time <- p.then(duration.to_time(dur.result) |> p.from_option(typ.remaining))
      Success(ParseState(..typ, result: ClockEvent(0, time.result, Home, In)))
    }
    "v" -> Success(ParseState(..typ, result: HolidayBooking(0, dur.result, Gain)))
    "V" -> Success(ParseState(..typ, result: HolidayBooking(0, dur.result, Use)))
    _ -> Failed
  }
}

/// Parses a DayState.
fn parse_day_state(input: String) -> ParseResult(DayState) {
  use date <- p.then(parse_date(input))
  use target <- p.then(parse_duration(date.remaining))
  use lunch <- p.then (parse_lunch(target.remaining))
  use events <- p.then(p.star(lunch.remaining, parse_day_event))
  Success(ParseState(..events, result: DayState(date: date.result, target: target.result, lunch: lunch.result, events: events.result)))
}

fn parse_line(acc: ParseResult(StateInput), line: String) -> ParseResult(StateInput) {
  use si <- p.then(acc)

  case string.pop_grapheme(line) {
    // Try to parse the week target.
    Ok(#("W", rest)) ->
      parse_duration(rest) |> p.end
      |> p.map(fn(t) { StateInput(..si.result, week_target: t) })

    // Try to parse the travel distance.
    Ok(#("T", rest)) ->
      parse_float(rest) |> p.end
      |> p.map(fn(d) { StateInput(..si.result, travel_distance: d) })

    Error(_) -> Success(si) // Empty line, let's ignore it.

    // Otherwise try to parse a day state.
    _ ->
      parse_day_state(line) |> p.end
      |> p.map(fn(d) { StateInput(..si.result, history: [ d, ..si.result.history ]) })
  }
}

pub fn parse_state_input(input: String) -> Option(StateInput) {
  let init = ParseState(StateInput(duration.zero(), 0.0, []), "")
  input
    |> string.replace("\r", "") |> string.split("\n") // Split in lines.
    |> list.fold(Success(init), parse_line) // Parse input (history will be reversed).
    |> p.map(fn(st) { StateInput(..st, history: list.reverse(st.history)) }) // Reverse history.
    |> p.to_option
}
